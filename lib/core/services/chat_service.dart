import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:tontetic/features/social/domain/chat_models.dart';

import 'package:tontetic/core/services/encryption_service.dart';

// Service de Chat Sécurisé (E2EE)
// Chiffrement de bout en bout avec libsodiumons dans Firestore
class ChatService {
  late final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Generate a unique ID for 1-on-1 chat
  static String getCanonicalId(String userA, String userB) {
    return userA.compareTo(userB) < 0 ? '${userA}_$userB' : '${userB}_$userA';
  }

  /// Écouter les messages d'une conversation (Auto-Decrypt)
  Stream<List<ChatMessage>> getMessages(String conversationId, String currentUserId) {
    return _db
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots()
        .asyncMap((snapshot) async {
           // Batch Decryption
           final tasks = snapshot.docs.map((doc) => _mapDocToMessage(doc, currentUserId));
           return await Future.wait(tasks);
        });
  }

  /// Envoyer un message (Auto-Encrypt)
  Future<void> sendMessage({
    required String conversationId,
    required String senderId,
    required String recipientId, // REQUIRED for E2EE and Direct Chat Participants
    required String text,
    String? senderName,
    String? recipientName,
    String? senderPhoto,
    String? recipientPhoto,
    bool isInvite = false,
    Map<String, dynamic>? circleData,
  }) async {
    try {
      final docRef = _db
          .collection('conversations')
          .doc(conversationId)
          .collection('messages')
          .doc();

      Map<String, dynamic> payload = {
        'id': docRef.id,
        'senderId': senderId,
        'timestamp': FieldValue.serverTimestamp(),
        'isInvite': isInvite,
        'circleData': circleData,
        'text': text, // Fallback
        'isEncrypted': false,
      };

      // 1. Try Encryption
      try {
        final recipientKey = await E2EEncryptionService.getPublicKey(recipientId);
        final senderKey = await E2EEncryptionService.getPublicKey(senderId);

        if (recipientKey != null && senderKey != null) {
           final encrypted = await E2EEncryptionService.encryptMessageDual(text, recipientKey, senderKey);
           payload['text'] = ''; // Clear plain text
           payload['isEncrypted'] = true;
           payload['encryptedContent'] = encrypted['content'];
           payload['encryptedKey'] = encrypted['key'];
           payload['encryptedKeySender'] = encrypted['keySender'];
           payload['iv'] = encrypted['iv'];
        } else if (recipientKey != null) {
           final encrypted = await E2EEncryptionService.encryptMessage(text, recipientKey);
           payload['text'] = ''; // Clear plain text
           payload['isEncrypted'] = true;
           payload['encryptedContent'] = encrypted['content'];
           payload['encryptedKey'] = encrypted['key'];
           payload['iv'] = encrypted['iv'];
        }
      } catch (e) {
        debugPrint('⚠️ Encryption failed, falling back to plain text: $e');
      }

      await docRef.set(payload);

      // Mettre à jour le timestamp de la conversation parente pour le tri et le query
      final updateData = {
        'lastMessageAt': FieldValue.serverTimestamp(),
        'lastMessageText': payload['isEncrypted'] ? '🔒 Message chiffré' : text,
        'participants': [senderId, recipientId], // Allow querying by arrayContains
        'updatedAt': FieldValue.serverTimestamp(),
      };
      
      if (senderName != null || recipientName != null) {
         updateData['participantsData'] = {
            if (senderName != null) senderId: {'name': senderName, 'photo': senderPhoto},
            if (recipientName != null) recipientId: {'name': recipientName, 'photo': recipientPhoto},
         };
      }

      await _db.collection('conversations').doc(conversationId).set(updateData, SetOptions(merge: true));

    } catch (e) {
      debugPrint('❌ Erreur envoi message: $e');
      rethrow;
    }
  }

  /// Send a media message (voice, image, or file)
  Future<void> sendMediaMessage({
    required String conversationId,
    required String senderId,
    required String recipientId,
    required File file,
    required String mediaType, // 'audio', 'image', 'file'
    String? senderName,
    String? recipientName,
    String? fileName,
  }) async {
    try {
      // 1. Upload file to Firebase Storage
      final extension = file.path.split('.').last;
      final storagePath = 'conversations/$conversationId/${DateTime.now().millisecondsSinceEpoch}.$extension';
      final ref = _storage.ref().child(storagePath);

      final uploadTask = await ref.putFile(file);
      final downloadUrl = await uploadTask.ref.getDownloadURL();

      // 2. Create message document
      final docRef = _db
          .collection('conversations')
          .doc(conversationId)
          .collection('messages')
          .doc();

      final payload = {
        'id': docRef.id,
        'senderId': senderId,
        'timestamp': FieldValue.serverTimestamp(),
        'type': mediaType,
        'url': downloadUrl,
        'fileName': fileName ?? file.uri.pathSegments.last,
        'text': '', // No text for media messages
        'isEncrypted': false,
      };

      await docRef.set(payload);

      // 3. Update conversation metadata
      String lastMessagePreview;
      switch (mediaType) {
        case 'audio':
          lastMessagePreview = '🎤 Message vocal';
          break;
        case 'image':
          lastMessagePreview = '📷 Photo';
          break;
        default:
          lastMessagePreview = '📎 Fichier';
      }

      await _db.collection('conversations').doc(conversationId).set({
        'lastMessageAt': FieldValue.serverTimestamp(),
        'lastMessageText': lastMessagePreview,
        'participants': [senderId, recipientId],
        'updatedAt': FieldValue.serverTimestamp(),
        'participantsData': {
          if (senderName != null) senderId: {'name': senderName},
          if (recipientName != null) recipientId: {'name': recipientName},
        },
      }, SetOptions(merge: true));

      debugPrint('✅ Media message sent: $mediaType');
    } catch (e) {
      debugPrint('❌ Error sending media message: $e');
      rethrow;
    }
  }

  /// Send media from bytes (for web compatibility)
  Future<void> sendMediaFromBytes({
    required String conversationId,
    required String senderId,
    required String recipientId,
    required Uint8List bytes,
    required String mediaType,
    required String contentType,
    String? senderName,
    String? recipientName,
    String? fileName,
  }) async {
    try {
      final extension = contentType.split('/').last;
      final storagePath = 'conversations/$conversationId/${DateTime.now().millisecondsSinceEpoch}.$extension';
      final ref = _storage.ref().child(storagePath);

      final metadata = SettableMetadata(contentType: contentType);
      final uploadTask = await ref.putData(bytes, metadata);
      final downloadUrl = await uploadTask.ref.getDownloadURL();

      final docRef = _db
          .collection('conversations')
          .doc(conversationId)
          .collection('messages')
          .doc();

      final payload = {
        'id': docRef.id,
        'senderId': senderId,
        'timestamp': FieldValue.serverTimestamp(),
        'type': mediaType,
        'url': downloadUrl,
        'fileName': fileName,
        'text': '',
        'isEncrypted': false,
      };

      await docRef.set(payload);

      String lastMessagePreview;
      switch (mediaType) {
        case 'audio':
          lastMessagePreview = '🎤 Message vocal';
          break;
        case 'image':
          lastMessagePreview = '📷 Photo';
          break;
        default:
          lastMessagePreview = '📎 Fichier';
      }

      await _db.collection('conversations').doc(conversationId).set({
        'lastMessageAt': FieldValue.serverTimestamp(),
        'lastMessageText': lastMessagePreview,
        'participants': [senderId, recipientId],
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

    } catch (e) {
      debugPrint('❌ Error sending media from bytes: $e');
      rethrow;
    }
  }

  Future<ChatMessage> _mapDocToMessage(DocumentSnapshot doc, String currentUserId) async {
    final data = doc.data() as Map<String, dynamic>;
    final isEncrypted = data['isEncrypted'] == true;
    
    String text = data['text'] ?? '';
    
    if (isEncrypted) {
      if (data['senderId'] == currentUserId) {
         if (data['encryptedKeySender'] != null) {
             // Decrypt using may private key (which is the Sender key in this case)
             try {
                final myKey = await E2EEncryptionService.getPrivateKey(currentUserId);
                if (myKey != null) {
                  text = await E2EEncryptionService.decryptMessage({
                     'content': data['encryptedContent'],
                     'key': data['encryptedKeySender'],
                     'iv': data['iv']
                  }, myKey);
                } else {
                  text = '🔒 Clé manquante';
                }
             } catch (e) {
                text = '🔒 Erreur déchiffrement';
             }
         } else {
             text = '🔒 Message sécurisé (envoyé)';
         }
      } else {
         // Decrypt for Recipient
         try {
            final myKey = await E2EEncryptionService.getPrivateKey(currentUserId);
            if (myKey != null) {
              text = await E2EEncryptionService.decryptMessage({
                 'content': data['encryptedContent'],
                 'key': data['encryptedKey'],
                 'iv': data['iv']
              }, myKey);
            } else {
              text = '🔒 Clé manquante';
            }
         } catch (e) {
            text = '🔒 Erreur déchiffrement';
         }
      }
    }

    return ChatMessage(
      id: doc.id,
      senderId: data['senderId'] ?? '',
      text: text,
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isInvite: data['isInvite'] ?? false,
      circleData: data['circleData'],
      isEncrypted: isEncrypted,
      type: data['type'] ?? 'text',
      url: data['url'],
      fileName: data['fileName'],
    );
  }
}
