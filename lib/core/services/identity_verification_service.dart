import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

/// Service de vérification d'identité (KYC) via Stripe Identity
///
/// Ce service gère le processus complet de KYC :
/// 1. Création d'une session de vérification Stripe Identity
/// 2. Redirection vers l'interface Stripe pour la capture document/selfie
/// 3. Réception du résultat via webhook (côté serveur)
/// 4. Mise à jour du statut utilisateur dans Firestore
class IdentityVerificationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // URL des Cloud Functions
  static const String _functionsBaseUrl =
      'https://europe-west1-tontetic-admin.cloudfunctions.net';

  /// Lance le processus de vérification KYC pour un utilisateur
  /// Retourne l'URL de vérification Stripe Identity pour redirection
  Future<VerificationResult> startVerification({
    required String userId,
    String? email,
    String? returnUrl,
  }) async {
    try {
      debugPrint('[KYC] Initialisation Stripe Identity pour $userId');

      final response = await http.post(
        Uri.parse('$_functionsBaseUrl/createIdentityVerificationSession'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userId': userId,
          'email': email,
          'returnUrl': returnUrl ?? (kIsWeb
              ? 'https://tontetic-app.web.app/kyc/complete'
              : 'tontetic://kyc/complete'),
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        debugPrint('[KYC] ✅ Session créée: ${data['sessionId']}');

        return VerificationResult(
          success: true,
          sessionId: data['sessionId'],
          verificationUrl: data['url'],
          clientSecret: data['clientSecret'],
        );
      } else {
        final error = jsonDecode(response.body);
        debugPrint('[KYC] ❌ Erreur: ${error['error']}');
        return VerificationResult(
          success: false,
          error: error['error'] ?? 'Erreur serveur',
        );
      }
    } catch (e) {
      debugPrint('[KYC] ❌ Exception: $e');
      return VerificationResult(
        success: false,
        error: 'Erreur de connexion: $e',
      );
    }
  }

  /// Lance la vérification et ouvre directement l'URL Stripe Identity
  Future<bool> startAndLaunchVerification({
    required String userId,
    String? email,
  }) async {
    final result = await startVerification(userId: userId, email: email);

    if (result.success && result.verificationUrl != null) {
      final uri = Uri.parse(result.verificationUrl!);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return true;
      }
    }
    return false;
  }

  /// Récupère le statut KYC actuel de l'utilisateur
  Future<KycStatus> getKycStatus(String userId) async {
    try {
      // D'abord vérifier le cache Firestore
      final doc = await _firestore.collection('users').doc(userId).get();
      if (!doc.exists) return KycStatus.none;

      final data = doc.data()!;
      final status = data['kycStatus'] as String? ?? 'none';
      final sessionId = data['kycSessionId'] as String?;

      // Si statut pending, vérifier avec Stripe pour avoir l'état actuel
      if (status == 'pending' && sessionId != null) {
        final liveStatus = await _fetchLiveStatus(sessionId);
        if (liveStatus != null) {
          return _parseStatus(liveStatus);
        }
      }

      return _parseStatus(status);
    } catch (e) {
      debugPrint('[KYC] Erreur getKycStatus: $e');
      return KycStatus.none;
    }
  }

  /// Récupère le statut en temps réel depuis Stripe
  Future<String?> _fetchLiveStatus(String sessionId) async {
    try {
      final response = await http.get(
        Uri.parse('$_functionsBaseUrl/getIdentityVerificationStatus?sessionId=$sessionId'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['status'];
      }
    } catch (e) {
      debugPrint('[KYC] Erreur fetch live status: $e');
    }
    return null;
  }

  KycStatus _parseStatus(String status) {
    switch (status) {
      case 'verified':
        return KycStatus.verified;
      case 'pending':
      case 'processing':
        return KycStatus.pending;
      case 'requires_input':
        return KycStatus.requiresInput;
      case 'canceled':
        return KycStatus.canceled;
      default:
        return KycStatus.none;
    }
  }

  /// Vérifie si l'utilisateur est vérifié KYC
  Future<bool> isUserVerified(String userId) async {
    final status = await getKycStatus(userId);
    return status == KycStatus.verified;
  }

  /// Stream du statut KYC (écoute les changements Firestore)
  Stream<KycStatus> watchKycStatus(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .snapshots()
        .map((doc) {
      if (!doc.exists) return KycStatus.none;
      final status = doc.data()?['kycStatus'] as String? ?? 'none';
      return _parseStatus(status);
    });
  }
}

/// Résultat d'une tentative de vérification
class VerificationResult {
  final bool success;
  final String? sessionId;
  final String? verificationUrl;
  final String? clientSecret;
  final String? error;

  VerificationResult({
    required this.success,
    this.sessionId,
    this.verificationUrl,
    this.clientSecret,
    this.error,
  });
}

/// Statuts possibles du KYC
enum KycStatus {
  none,           // Jamais commencé
  pending,        // En cours de traitement
  requiresInput,  // Besoin d'informations supplémentaires
  verified,       // Vérifié avec succès
  canceled,       // Annulé par l'utilisateur
}

/// Extension pour afficher le statut en français
extension KycStatusExtension on KycStatus {
  String get label {
    switch (this) {
      case KycStatus.none:
        return 'Non vérifié';
      case KycStatus.pending:
        return 'En cours';
      case KycStatus.requiresInput:
        return 'Information requise';
      case KycStatus.verified:
        return 'Vérifié ✓';
      case KycStatus.canceled:
        return 'Annulé';
    }
  }

  bool get isVerified => this == KycStatus.verified;
  bool get isPending => this == KycStatus.pending;
  bool get needsAction => this == KycStatus.none || this == KycStatus.requiresInput;
}
