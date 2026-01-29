import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:tontetic/core/providers/circle_provider.dart';
import 'package:tontetic/core/services/security_service.dart';

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
               String name = userData['fullName'] ?? 'Membre Tontetic';
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

  /// Envoyer une demande d'adhésion
  Future<void> requestToJoin({
    required String circleId,
    required String circleName,
    required String requesterId,
    required String requesterName,
    String? message,
  }) async {
    try {
      await _db.collection('join_requests').add({
        'circleId': circleId,
        'circleName': circleName,
        'requesterId': requesterId,
        'requesterName': requesterName,
        'requestedAt': FieldValue.serverTimestamp(),
        'status': 'pending',
        'message': message,
      });
    } catch (e) {
      debugPrint('❌ Erreur demande adhésion: $e');
      rethrow;
    }
  }

  /// Approuver une demande
  Future<void> approveRequest(String requestId, String circleId, String userId) async {
    final batch = _db.batch();
    
    batch.update(_db.collection('join_requests').doc(requestId), {
      'status': 'approved',
    });
    
    batch.update(_db.collection('tontines').doc(circleId), {
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
