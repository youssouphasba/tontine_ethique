import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tontetic/core/services/stripe_service.dart';

import 'package:flutter/foundation.dart';

/// V11.8 - SEPA Mandate Service (Stripe Integration)
/// Handles IBAN collection authorization and mandate signing

enum MandateStatus { none, pending, signed, revoked }

class SepaMandate {
  final String id;
  final String last4;
  final String bankName;
  final DateTime signedAt;
  final MandateStatus status;
  final String stripeSetupIntentId;

  SepaMandate({
    required this.id,
    required this.last4,
    required this.bankName,
    required this.signedAt,
    this.status = MandateStatus.signed,
    required this.stripeSetupIntentId,
  });
}

class SepaMandateService {
  // Plus de stockage Mock en mémoire.
  // La vérité est dans Firestore (users/{uid} ou sous-collection mandates).
  
  /// Initiates a Stripe SetupIntent for SEPA Direct Debit
  /// Returns the Client Secret or ID to start the UI flow
  Future<String?> createSetupIntent({String? email, String? customerId}) async {
    // Appel réel via StripeService (qui appelle Cloud Functions)
    try {
      final customerIdResult = await StripeService.setupSepaMandate(
        email: email, 
        customerId: customerId
      );
      return customerIdResult; // ou retourner le setupIntentId si besoin
    } catch (e) {
      debugPrint('Erreur SEPA Setup: $e');
      return null;
    }
  }

  /// Finalise et sauvegarde le mandat (Côté Client -> Firestore)
  Future<void> saveMandate({
    required String userId,
    required String ibanLast4,
    required String bankName,
    required String setupIntentId,
  }) async {
    // Sauvegarde REELLE dans Firestore
    await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('mandates')
        .add({
      'last4': ibanLast4,
      'bankName': bankName,
      'status': 'active', // Stripe confirmera via Webhook normalement
      'stripeSetupIntentId': setupIntentId,
      'signedAt': FieldValue.serverTimestamp(),
      'type': 'sepa',
    });
    
    // Mise à jour du user pour accès rapide
    await FirebaseFirestore.instance.collection('users').doc(userId).update({
      'hasValidSepaMandate': true,
      'sepaBankName': bankName,
      'sepaLast4': ibanLast4,
    });
  }

  // Getter dynamique (à remplacer par un StreamProvider dans l'UI)
  // SepaMandate? get activeMandate => null; // Forcer l'UI à utiliser les Streams Firestore
}

final sepaMandateProvider = Provider<SepaMandateService>((ref) {
  return SepaMandateService();
});
