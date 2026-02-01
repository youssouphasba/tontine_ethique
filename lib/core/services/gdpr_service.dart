import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tontetic/core/providers/user_provider.dart';
// Added for deleteAccount calling logic usage transparency if needed
import 'package:tontetic/core/providers/auth_provider.dart';
import 'package:tontetic/core/providers/tontine_provider.dart';
import 'package:tontetic/features/wallet/data/wallet_provider.dart';
import 'package:tontetic/core/providers/consent_provider.dart';


/// RGPD/GDPR Compliance Service
/// Implements Articles 15, 17, 20 of GDPR

class GDPRService {
  final Ref _ref;
  
  GDPRService(this._ref);

  /// Article 15 & 20: Export all user data
  Future<Map<String, dynamic>> exportUserData() async {
    final user = _ref.read(userProvider);
    final circles = _ref.read(circleProvider);
    final wallet = _ref.read(walletProvider);
    final consents = _ref.read(consentProvider);
    
    // Mask sensitive data for export
    String maskPhone(String phone) {
      if (phone.length < 6) return '***';
      return '${phone.substring(0, 4)} *** ** ${phone.substring(phone.length - 2)}';
    }
    
    String maskEmail(String email) {
      final parts = email.split('@');
      if (parts.length != 2) return '[email masqué]';
      final name = parts[0];
      final masked = name.length > 2 
        ? '${name.substring(0, 2)}***'
        : '***';
      return '$masked@${parts[1]}';
    }

    final exportData = {
      'metadata': {
        'exportDate': DateTime.now().toIso8601String(),
        'version': '1.0',
        'format': 'JSON (RGPD Art.20)',
      },
      'user': {
        'id': user.phoneNumber.hashCode.toString(),
        'displayName': user.displayName,
        'email': maskEmail(user.email),
        'phone': maskPhone(user.phoneNumber),
        'zone': user.zone.toString().split('.').last,
        'subscriptionTier': user.subscriptionTier,
        'honorScore': user.honorScore,
        'createdAt': user.createdAt?.toIso8601String() ?? 'Non enregistré',
      },
      'consents': consents.consents.map((c) => {
        'type': c.type,
        'accepted': c.accepted,
        'timestamp': c.timestamp.toIso8601String(),
        'ipAddress': c.ipAddress,
      }).toList(),
      'circles': circles.myCircles.map((c) => {
        'name': c.name,
        'role': c.creatorId == user.phoneNumber ? 'Créateur' : 'Membre',
        'amount': c.amount,
        'joinedAt': c.createdAt.toIso8601String(),
      }).toList(),
      'transactions': wallet.transactions.map((t) => {
        'date': t.date.toIso8601String(),
        'amount': t.amount,
        'type': t.type,
        'title': t.title,
      }).toList(),
      'legal': {
        'retentionPolicy': 'Transactions: 5 ans (anti-blanchiment), Mandats SEPA: 10 ans',
        'dataController': 'Tontetic SAS',
        'contact': 'rgpd@tontetic.io',
      },
    };

    // Log export action
    debugPrint('[RGPD] GDPR_DATA_EXPORT - User: ${user.phoneNumber} - Export complet des données utilisateur');

    return exportData;
  }

  /// Convert export to JSON string
  Future<String> exportToJson() async {
    final data = await exportUserData();
    return const JsonEncoder.withIndent('  ').convert(data);
  }

  /// Article 17: Right to erasure (with legal retention)
  Future<Map<String, dynamic>> requestDeletion() async {
    final user = _ref.read(userProvider);
    
    // Generate anonymous ID for retained records
    final anonymousId = 'ANON_${DateTime.now().millisecondsSinceEpoch}';
    
    // Log deletion request BEFORE anonymization
    debugPrint('[RGPD] GDPR_DELETION_REQUEST - User: ${user.phoneNumber} - Demande de suppression - Anonymisation vers $anonymousId');

    // Return what will be deleted vs retained
    return {
      'status': 'pending_confirmation',
      'willBeDeleted': [
        'Nom et prénom',
        'Email',
        'Numéro de téléphone',
        'Score d\'Honneur',
        'Préférences',
        'Historique de chat',
      ],
      'willBeAnonymized': [
        'Transactions financières (conservées 5 ans)',
        'Mandats SEPA signés (conservés 10 ans)',
        'Logs d\'audit (conservés 5 ans)',
      ],
      'anonymousId': anonymousId,
      'note': 'Les données anonymisées ne permettent plus de vous identifier.',
    };
  }

  /// Execute deletion after confirmation
  Future<bool> executeDeletion(String anonymousId) async {
    final user = _ref.read(userProvider);
    final uid = user.uid;
    
    if (uid.isEmpty) return false;

    try {
      debugPrint('[RGPD] 🚨 Starting deletion process for $uid');

      // 1. Storage Cleanup (Best Effort)
      // Tries to delete profile pictures and KYC docs if they exist
      final storageRef = FirebaseStorage.instance.ref();
      
      // 0. FAILSAFE: Mark as deletion_pending immediately
      // This prevents the user from using the app if the process is interrupted
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'accountStatus': 'deletion_pending',
        'deletionStartedAt': FieldValue.serverTimestamp(),
      });

      // 1. Storage Cleanup (Best Effort)
      final filesToDelete = [
        'users/$uid/profile.jpg',
        'users/$uid/id_document.jpg',
        'users/$uid/selfie.jpg',
        'kyc/$uid/id_card.jpg', // Legacy path
        'kyc/$uid/selfie.jpg',  // Legacy path
      ];

      for (final path in filesToDelete) {
        try {
          await storageRef.child(path).delete();
          debugPrint('[RGPD] Deleted storage file: $path');
        } catch (e) {
          // Ignore if file not found
          debugPrint('[RGPD] File not found or error: $path ($e)');
        }
      }

      // 2. Anonymize User Document in Firestore
      // We keep the doc ID for referential integrity (transaction history) but scrub PII
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'fullName': 'Utilisateur Supprimé',
        'email': '$anonymousId@deleted.tontetic.com',
        'phoneNumber': '0000000000',
        'photoUrl': null,
        'bio': null,
        'jobTitle': null,
        'company': null,
        'encryptedName': null,
        'encryptedAddress': null,
        'encryptedSiret': null,
        'encryptedRepresentative': null,
        'encryptedBirthDate': null,
        'isDeleted': true,
        'deletedAt': FieldValue.serverTimestamp(),
        'deletionId': anonymousId,
        'fcmToken': null,
      });
      debugPrint('[RGPD] Firestore user document anonymized');

      // 3. Delete from 'merchants' collection if exists
      // Check if user was a merchant
      final merchantQuery = await FirebaseFirestore.instance
          .collection('merchants')
          .where('user_id', isEqualTo: user.phoneNumber) // Assuming link is via phone
          .get();
      
      for (final doc in merchantQuery.docs) {
        await doc.reference.update({
          'account_status': 'closed',
          'email': null,
          'siret_ninea': null,
          'id_document_url': null,
          'selfie_url': null,
          'iban': null,
          'deleted_at': FieldValue.serverTimestamp(),
        });
        debugPrint('[RGPD] Merchant account anonymized: ${doc.id}');
      }

      // 4. Local State Cleanup
      _ref.read(userProvider.notifier).anonymize(anonymousId);
      
      // 5. Auth Account Deletion (Final Step)
      // This will revoke access token.
      final authService = _ref.read(authServiceProvider);
      final authResult = await authService.deleteAccount();
      
      if (!authResult.success) {
        throw Exception(authResult.error);
      }

      debugPrint('[RGPD] GDPR_DELETION_EXECUTED - User: $uid -> $anonymousId - Compte supprimé et anonymisé');
      return true;

    } catch (e) {
      debugPrint('[RGPD] ❌ Critical error during deletion: $e');
      // Even if it failed partialy, we return false so UI can show error
      return false;
    }
  }

  /// Get consent history
  List<ConsentRecord> getConsentHistory() {
    return _ref.read(consentProvider).consents;
  }
}

final gdprServiceProvider = Provider<GDPRService>((ref) {
  return GDPRService(ref);
});
