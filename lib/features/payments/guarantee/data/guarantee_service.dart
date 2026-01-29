import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

enum SolidaryStatus { pending, secure, triggered }

/// Service Technique de Gestion de la Réserve de Solidarité
/// Note : Ce service ne constitue pas une assurance financière.
/// PRODUCTION: Reads status from Firestore tontine_members collection
class SolidaryService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  /// Engage la solidarité communautaire - écrit dans Firestore
  static Future<bool> authorizeEngagement(BuildContext context, double amount, {String? memberId, String? tontineId}) async {
    if (memberId == null || tontineId == null) {
      debugPrint('[Solidary] Error: memberId and tontineId required');
      return false;
    }
    
    try {
      await _firestore
          .collection('tontines')
          .doc(tontineId)
          .collection('members')
          .doc(memberId)
          .set({
        'solidaryStatus': SolidaryStatus.pending.name,
        'solidaryAmount': amount,
        'solidaryRequestedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      
      debugPrint('[Solidary] Engagement authorized for $memberId: $amount');
      return true;
    } catch (e) {
      debugPrint('[Solidary] Error authorizing engagement: $e');
      return false;
    }
  }

  /// Action Admin : Exécuter l'accord de solidarité (Fonds redistribués au cercle)
  static Future<void> executeSolidarity(BuildContext context, String memberName, double amount, {String? memberId, String? tontineId}) async {
    if (memberId == null || tontineId == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erreur: Informations manquantes'), backgroundColor: Colors.red),
        );
      }
      return;
    }
    
    try {
      await _firestore
          .collection('tontines')
          .doc(tontineId)
          .collection('members')
          .doc(memberId)
          .update({
        'solidaryStatus': SolidaryStatus.triggered.name,
        'solidaryExecutedAt': FieldValue.serverTimestamp(),
      });
      
      // Log admin action
      await _firestore.collection('audit_logs').add({
        'action': 'SOLIDARITY_EXECUTED',
        'memberId': memberId,
        'tontineId': tontineId,
        'amount': amount,
        'timestamp': FieldValue.serverTimestamp(),
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Accord de solidarité pour $memberName exécuté ($amount).'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('[Solidary] Error executing solidarity: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  /// Récupère le statut d'engagement d'un membre depuis Firestore
  static Future<SolidaryStatus> getMemberStatus(String memberId, String tontineId) async {
    try {
      final doc = await _firestore
          .collection('tontines')
          .doc(tontineId)
          .collection('members')
          .doc(memberId)
          .get();
      
      if (!doc.exists) return SolidaryStatus.pending;
      
      final statusStr = doc.data()?['solidaryStatus'] as String?;
      if (statusStr == null) return SolidaryStatus.pending;
      
      return SolidaryStatus.values.firstWhere(
        (s) => s.name == statusStr,
        orElse: () => SolidaryStatus.pending,
      );
    } catch (e) {
      debugPrint('[Solidary] Error getting member status: $e');
      return SolidaryStatus.pending;
    }
  }
  
  /// Stream le statut en temps réel
  static Stream<SolidaryStatus> streamMemberStatus(String memberId, String tontineId) {
    return _firestore
        .collection('tontines')
        .doc(tontineId)
        .collection('members')
        .doc(memberId)
        .snapshots()
        .map((doc) {
          if (!doc.exists) return SolidaryStatus.pending;
          final statusStr = doc.data()?['solidaryStatus'] as String?;
          if (statusStr == null) return SolidaryStatus.pending;
          return SolidaryStatus.values.firstWhere(
            (s) => s.name == statusStr,
            orElse: () => SolidaryStatus.pending,
          );
        });
  }
}
