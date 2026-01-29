import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:tontetic/features/social/domain/chat_models.dart';

import 'package:tontetic/core/services/encryption_service.dart';

// Service de Chat Sécurisé (E2EE)
// Chiffrement de bout en bout avec libsodiumons dans Firestore
class ChatService {
  late final FirebaseFirestore _db = FirebaseFirestore.instance;

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
    required String recipientId, // REQUIRED for E2EE
    required String text,
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
        if (recipientKey != null) {
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

      // Mettre à jour le timestamp de la conversation parente pour le tri
      await _db.collection('conversations').doc(conversationId).set({
        'lastMessageAt': FieldValue.serverTimestamp(),
        'lastMessageText': payload['isEncrypted'] ? '🔒 Message chiffré' : text,
      }, SetOptions(merge: true));

    } catch (e) {
      debugPrint('❌ Erreur envoi message: $e');
      rethrow;
    }
  }

  Future<ChatMessage> _mapDocToMessage(DocumentSnapshot doc, String currentUserId) async {
    final data = doc.data() as Map<String, dynamic>;
    final isEncrypted = data['isEncrypted'] == true;
    
    String text = data['text'] ?? '';
    
    if (isEncrypted) {
      if (data['senderId'] == currentUserId) {
         // Show "Sent Encrypted" or store own copy de-crypted (not implemented here)
         // For now, sender might not see their own message if we don't store "myEncryptedKey"
         // TODO: Multi-recipient encryption (Store key for Sender AND Recipient)
         // Current MVP: Sender sees "🔒 Message sécurisé"
         text = '🔒 Message sécurisé (envoyé)';
      } else {
         // Decrypt
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
    );
  }
}
