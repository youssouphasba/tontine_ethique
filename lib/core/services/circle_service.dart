import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:tontetic/core/providers/tontine_provider.dart';
import 'package:tontetic/core/services/security_service.dart';
import 'package:tontetic/core/services/notification_service.dart';

/// Service pour gérer les cercles de tontine dans Firestore
class CircleService {
  late final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Créer une tontine dans Firestore
  Future<String> createCircle(TontineCircle circle) async {
    try {
      final docRef = _db.collection('tontines').doc();
      final newCircle = circle.copyWith(id: docRef.id);
      
      await docRef.set({
        'id': docRef.id,
        'name': newCircle.name,
        'objective': newCircle.objective,
        'amount': newCircle.amount,
        'maxParticipants': newCircle.maxParticipants,
        'frequency': newCircle.frequency,
        'payoutDay': newCircle.payoutDay,
        'orderType': newCircle.orderType,
        'creatorId': newCircle.creatorId,
        'creatorName': newCircle.creatorName,
        'invitationCode': newCircle.invitationCode,
        'isPublic': newCircle.isPublic,
        'isSponsored': newCircle.isSponsored,
        'currency': newCircle.currency, // V15: Dynamic Currency
        'createdAt': Timestamp.fromDate(newCircle.createdAt),
        'memberIds': newCircle.memberIds,
        'currentCycle': newCircle.currentCycle,
      });

      // V1.5: Enregistrer l'activité sociale réelle
      await _db.collection('activities').add({
        'userName': newCircle.creatorName,
        'userAvatar': '',
        'description': 'a créé une nouvelle tontine : ${newCircle.name}',
        'actionLabel': 'REJOINDRE',
        'timestamp': FieldValue.serverTimestamp(),
        'circleId': docRef.id,
      });
      
      await _updateUserStats(newCircle.creatorId, increment: 1);
      
      return docRef.id;
    } catch (e) {
      debugPrint('❌ Erreur création cercle Firestore: $e');
      rethrow;
    }
  }

  /// Récupérer les cercles d'un utilisateur
  Stream<List<TontineCircle>> getMyCircles(String userId) {
    return _db
        .collection('tontines')
        .where('memberIds', arrayContains: userId)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => _mapDocToCircle(doc))
            .toList());
  }

  /// Récupérer un cercle spécifique par ID
  Stream<TontineCircle?> getCircleById(String circleId) {
    return _db
        .collection('tontines')
        .doc(circleId)
        .snapshots()
        .map((doc) => doc.exists ? _mapDocToCircle(doc) : null);
  }

  /// Récupérer les cercles publics (Explorer)
  Stream<List<TontineCircle>> getPublicCircles() {
    return _db
        .collection('tontines')
        .where('isPublic', isEqualTo: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => _mapDocToCircle(doc))
            .toList());
  }

  /// Récupérer les détails des membres d'un cercle
  Stream<List<Map<String, dynamic>>> getCircleMembers(String circleId, String currentUserId) {
    return _db.collection('tontines').doc(circleId).snapshots().asyncMap((circleDoc) async {
       if (!circleDoc.exists || circleDoc.data() == null) return [];
       
       final data = circleDoc.data() as Map<String, dynamic>;
       final memberIds = List<String>.from(data['memberIds'] ?? []);
       
       if (memberIds.isEmpty) return [];

       final users = <Map<String, dynamic>>[];
       
       for (var id in memberIds) {
          try {
            final userDoc = await _db.collection('users').doc(id).get();
            if (userDoc.exists) {
               final userData = userDoc.data()!;
               
               // Decrypt Name
               String name = userData['fullName'] ?? userData['displayName'] ?? userData['pseudo'] ?? 'Membre';
               if (userData['encryptedName'] != null) {
                 try {
                    name = SecurityService.decryptData(userData['encryptedName']);
                 } catch(_) {
                    // Keep fallback or existing name
                 }
               }
               
               users.add({
                  'id': id,
                  'name': name,
                  'photoUrl': userData['photoUrl'],
                  'trust': userData['honorScore'] != null ? (userData['honorScore'] / 20).round() : 3,
                  'guarantee': 'active', 
                  'isMe': id == currentUserId
               });
            }
          } catch (e) {
            debugPrint('Error fetching member $id: $e');
          }
       }
       return users;
    });
  }

  /// Rejoindre un cercle
  Future<void> joinCircle(String circleId, String userId) async {
    try {
      await _db.collection('tontines').doc(circleId).update({
        'memberIds': FieldValue.arrayUnion([userId]),
      });
      
      await _updateUserStats(userId, increment: 1);
    } catch (e) {
      debugPrint('❌ Erreur adhésion cercle: $e');
      rethrow;
    }
  }
  
  /// Get requests sent by me
  Stream<List<JoinRequest>> getMyJoinRequests(String userId) {
    return _db
        .collection('join_requests')
        .where('requesterId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
          final data = doc.data();
          return JoinRequest(
            id: doc.id,
            circleId: data['circleId'] ?? '',
            circleName: data['circleName'] ?? '',
            requesterId: data['requesterId'] ?? '',
            requesterName: data['requesterName'] ?? '',
            requestedAt: (data['requestedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
            status: JoinRequestStatus.values.firstWhere(
              (e) => e.name == (data['status'] ?? 'pending'),
              orElse: () => JoinRequestStatus.pending,
            ),
            message: data['message'],
          );
        }).toList());
  }

  /// Get pending requests for a specific circle (for Creator)
  Stream<List<JoinRequest>> getJoinRequestsForCircle(String circleId) {
    return _db
        .collection('join_requests')
        .where('circleId', isEqualTo: circleId)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
          final data = doc.data();
          return JoinRequest(
            id: doc.id,
            circleId: data['circleId'] ?? '',
            circleName: data['circleName'] ?? '',
            requesterId: data['requesterId'] ?? '',
            requesterName: data['requesterName'] ?? '',
            requestedAt: (data['requestedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
            status: JoinRequestStatus.pending,
            message: data['message'],
          );
        }).toList());
  }

  /// Envoyer une demande d'adhésion
  Future<void> requestToJoin({
    required String circleId,
    required String circleName,
    required String requesterId,
    required String requesterName,
    String? message,
  }) async {
    try {
      // 1. Check if a request already exists to avoid duplicates
      final existing = await _db.collection('join_requests')
          .where('circleId', isEqualTo: circleId)
          .where('requesterId', isEqualTo: requesterId)
          .where('status', isEqualTo: 'pending')
          .get();
          
      if (existing.docs.isNotEmpty) {
        throw Exception("Une demande est déjà en attente pour ce cercle.");
      }

      // 2. Add the request
      await _db.collection('join_requests').add({
        'circleId': circleId,
        'circleName': circleName,
        'requesterId': requesterId,
        'requesterName': requesterName,
        'requestedAt': FieldValue.serverTimestamp(),
        'status': 'pending',
        'message': message,
      });

      // 3. Trigger notification for creator
      final circleDoc = await _db.collection('tontines').doc(circleId).get();
      if (circleDoc.exists) {
        final creatorId = circleDoc.data()?['creatorId'];
        if (creatorId != null) {
          // Persist in Firestore
          await _db.collection('users').doc(creatorId).collection('notifications').add({
            'title': 'Nouvelle demande ! 👤',
            'message': '$requesterName souhaite rejoindre "$circleName".',
            'circleId': circleId,
            'requesterId': requesterId,
            'type': 'join_request',
            'timestamp': FieldValue.serverTimestamp(),
            'read': false,
          });

          // External alert
          NotificationService.sendJoinRequestNotification(
            creatorId: creatorId,
            requesterName: requesterName,
            circleName: circleName,
          );
        }
      }
    } catch (e) {
      debugPrint('❌ Erreur demande adhésion: $e');
      rethrow;
    }
  }

  /// Approuver une demande (V16: Passage en "Pending Signature")
  Future<void> approveRequest(String requestId, String circleId, String userId) async {
    try {
      // 1. Get request details to get the circle name
      final requestDoc = await _db.collection('join_requests').doc(requestId).get();
      if (!requestDoc.exists) throw Exception("Demande introuvable.");
      final requestData = requestDoc.data()!;
      final circleName = requestData['circleName'] ?? 'Cercle';

      final batch = _db.batch();
      
      // 2. Update request status
      batch.update(_db.collection('join_requests').doc(requestId), {
        'status': 'approved',
      });
      
      // 3. Add to pendingSignatureIds in Tontine
      batch.update(_db.collection('tontines').doc(circleId), {
        'pendingSignatureIds': FieldValue.arrayUnion([userId]),
      });

      // 4. Create a REAL in-app notification document for the user
      final notifRef = _db.collection('users').doc(userId).collection('notifications').doc();
      batch.set(notifRef, {
        'id': notifRef.id,
        'title': 'Demande Approuvée ! 🎉',
        'message': 'Votre demande pour rejoindre "$circleName" a été acceptée. Veuillez signer la charte pour finaliser.',
        'circleId': circleId,
        'type': 'join_approval',
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
      });
      
      await batch.commit();

      // 5. Trigger external alert (Debug/Simulation context for SMS/Mail)
      NotificationService.sendJoinApprovalNotification(
        requesterId: userId,
        circleName: circleName,
      );
    } catch (e) {
      debugPrint('❌ Erreur approbation demande: $e');
      rethrow;
    }
  }

  /// Finaliser l'adhésion après signature légale
  Future<void> finalizeMembership(String circleId, String userId) async {
    final batch = _db.batch();
    
    // Move from pendingSignature to memberIds
    batch.update(_db.collection('tontines').doc(circleId), {
      'pendingSignatureIds': FieldValue.arrayRemove([userId]),
      'memberIds': FieldValue.arrayUnion([userId]),
    });
    
    await batch.commit();
    await _updateUserStats(userId, increment: 1);
  }

  TontineCircle _mapDocToCircle(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return TontineCircle(
      id: doc.id,
      name: data['name'] ?? '',
      objective: data['objective'] ?? '',
      amount: (data['amount'] ?? 0).toDouble(),
      maxParticipants: data['maxParticipants'] ?? 10,
      frequency: data['frequency'] ?? 'Mensuel',
      payoutDay: data['payoutDay'] ?? 1,
      orderType: data['orderType'] ?? 'Aléatoire',
      creatorId: data['creatorId'] ?? '',
      creatorName: data['creatorName'] ?? '',
      invitationCode: data['invitationCode'] ?? '',
      isPublic: data['isPublic'] ?? true,
      isSponsored: data['isSponsored'] ?? false,
      currency: data['currency'] ?? 'FCFA', // Fallback to FCFA for old circles
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      memberIds: List<String>.from(data['memberIds'] ?? []),
      currentCycle: data['currentCycle'] ?? 1,
      pendingSignatureIds: List<String>.from(data['pendingSignatureIds'] ?? []),
    );
  }

  /// Update user stats (Back Office Sync)
  Future<void> _updateUserStats(String userId, {required int increment}) async {
    try {
      final userRef = _db.collection('users').doc(userId);
      await userRef.set({
        'activeCirclesCount': FieldValue.increment(increment),
        'stats': {
          'activeCircles': FieldValue.increment(increment)
        }
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('⚠️ Warning: Failed to update user stats for $userId: $e');
    }
  }
}
