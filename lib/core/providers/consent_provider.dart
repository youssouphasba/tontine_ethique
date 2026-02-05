import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';

/// RGPD Article 7: Consent Tracking
/// Tracks all user consents with timestamps and IP addresses
/// Persiste les consentements en Firestore pour audit légal

enum ConsentType {
  cgu,           // Terms of Service
  privacy,       // Privacy Policy
  newsletter,    // Marketing emails
  cookies,       // Cookie usage
  dataSharing,   // Third-party data sharing
  voiceRecording,// AI voice consent
  charter,       // Community charter
  analytics,     // Usage statistics (Firebase Analytics, etc.)
}

class ConsentRecord {
  final ConsentType type;
  final bool accepted;
  final DateTime timestamp;
  final String ipAddress;
  final String? version; // CGU version if applicable
  final String? userAgent;
  final String? userId;

  ConsentRecord({
    required this.type,
    required this.accepted,
    required this.timestamp,
    required this.ipAddress,
    this.version,
    this.userAgent,
    this.userId,
  });

  Map<String, dynamic> toJson() => {
    'type': type.name,
    'accepted': accepted,
    'timestamp': timestamp.toIso8601String(),
    'ipAddress': ipAddress,
    'version': version,
    'userAgent': userAgent,
    'userId': userId,
  };

  factory ConsentRecord.fromJson(Map<String, dynamic> json) {
    return ConsentRecord(
      type: ConsentType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => ConsentType.cgu,
      ),
      accepted: json['accepted'] ?? false,
      timestamp: json['timestamp'] is Timestamp
          ? (json['timestamp'] as Timestamp).toDate()
          : DateTime.parse(json['timestamp']),
      ipAddress: json['ipAddress'] ?? 'unknown',
      version: json['version'],
      userAgent: json['userAgent'],
      userId: json['userId'],
    );
  }
}

class ConsentState {
  final List<ConsentRecord> consents;
  final bool cguAccepted;
  final bool privacyAccepted;
  final bool newsletterAccepted;
  final bool voiceConsentGiven;
  final bool analyticsAccepted;

  ConsentState({
    this.consents = const [],
    this.cguAccepted = false,
    this.privacyAccepted = false,
    this.newsletterAccepted = false,
    this.voiceConsentGiven = false,
    this.analyticsAccepted = false, // Default off - opt-in for RGPD
  });

  ConsentState copyWith({
    List<ConsentRecord>? consents,
    bool? cguAccepted,
    bool? privacyAccepted,
    bool? newsletterAccepted,
    bool? voiceConsentGiven,
    bool? analyticsAccepted,
  }) {
    return ConsentState(
      consents: consents ?? this.consents,
      cguAccepted: cguAccepted ?? this.cguAccepted,
      privacyAccepted: privacyAccepted ?? this.privacyAccepted,
      newsletterAccepted: newsletterAccepted ?? this.newsletterAccepted,
      voiceConsentGiven: voiceConsentGiven ?? this.voiceConsentGiven,
      analyticsAccepted: analyticsAccepted ?? this.analyticsAccepted,
    );
  }

  bool hasConsent(ConsentType type) {
    final record = consents.where((c) => c.type == type).lastOrNull;
    return record?.accepted ?? false;
  }
}

class ConsentNotifier extends StateNotifier<ConsentState> {
  ConsentNotifier() : super(ConsentState());

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  String? _cachedIpAddress;

  /// Obtient l'adresse IP publique réelle (pour audit RGPD)
  Future<String> _getPublicIpAddress() async {
    if (_cachedIpAddress != null) return _cachedIpAddress!;

    try {
      // Utilise un service externe pour obtenir l'IP publique
      final response = await http.get(
        Uri.parse('https://api.ipify.org?format=json'),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _cachedIpAddress = data['ip'] as String?;
        return _cachedIpAddress ?? 'ip-fetch-failed';
      }
    } catch (e) {
      debugPrint('CONSENT: Failed to fetch IP: $e');
    }

    return 'ip-unavailable';
  }

  /// Obtient le User-Agent pour l'audit
  String _getUserAgent() {
    if (kIsWeb) {
      return 'web-client';
    }
    try {
      return '${Platform.operatingSystem}/${Platform.operatingSystemVersion}';
    } catch (_) {
      return 'unknown-platform';
    }
  }

  /// Enregistre un consentement avec persistance Firestore
  Future<void> recordConsent({
    required ConsentType type,
    required bool accepted,
    String? ipAddress, // Si null, sera récupérée automatiquement
    String? version,
  }) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    final realIp = ipAddress ?? await _getPublicIpAddress();
    final userAgent = _getUserAgent();

    final record = ConsentRecord(
      type: type,
      accepted: accepted,
      timestamp: DateTime.now(),
      ipAddress: realIp,
      version: version,
      userAgent: userAgent,
      userId: userId,
    );

    // Mise à jour de l'état local
    state = state.copyWith(
      consents: [...state.consents, record],
      cguAccepted: type == ConsentType.cgu ? accepted : state.cguAccepted,
      privacyAccepted: type == ConsentType.privacy ? accepted : state.privacyAccepted,
      newsletterAccepted: type == ConsentType.newsletter ? accepted : state.newsletterAccepted,
      voiceConsentGiven: type == ConsentType.voiceRecording ? accepted : state.voiceConsentGiven,
      analyticsAccepted: type == ConsentType.analytics ? accepted : state.analyticsAccepted,
    );

    // Persistance en Firestore pour audit légal (RGPD)
    if (userId != null) {
      try {
        await _db
            .collection('users')
            .doc(userId)
            .collection('consents')
            .add({
          ...record.toJson(),
          'createdAt': FieldValue.serverTimestamp(),
        });
        debugPrint('CONSENT: Recorded ${type.name} consent for user');
      } catch (e) {
        debugPrint('CONSENT: Failed to persist consent: $e');
        // On ne bloque pas l'UX si Firestore échoue
      }
    }
  }

  Future<void> revokeConsent(ConsentType type) async {
    await recordConsent(type: type, accepted: false);
  }

  Future<void> acceptCGUAndPrivacy(String cguVersion) async {
    await recordConsent(
      type: ConsentType.cgu,
      accepted: true,
      version: cguVersion,
    );
    await recordConsent(
      type: ConsentType.privacy,
      accepted: true,
      version: cguVersion,
    );
  }

  /// Charge les consentements depuis Firestore pour un utilisateur
  Future<void> loadConsentsForUser(String userId) async {
    try {
      final snapshot = await _db
          .collection('users')
          .doc(userId)
          .collection('consents')
          .orderBy('createdAt', descending: false)
          .get();

      final records = snapshot.docs
          .map((doc) => ConsentRecord.fromJson(doc.data()))
          .toList();

      // Recalculer l'état à partir des consentements chargés
      bool cgu = false, privacy = false, newsletter = false, voice = false, analytics = false;
      for (final record in records) {
        switch (record.type) {
          case ConsentType.cgu:
            cgu = record.accepted;
            break;
          case ConsentType.privacy:
            privacy = record.accepted;
            break;
          case ConsentType.newsletter:
            newsletter = record.accepted;
            break;
          case ConsentType.voiceRecording:
            voice = record.accepted;
            break;
          case ConsentType.analytics:
            analytics = record.accepted;
            break;
          default:
            break;
        }
      }

      state = ConsentState(
        consents: records,
        cguAccepted: cgu,
        privacyAccepted: privacy,
        newsletterAccepted: newsletter,
        voiceConsentGiven: voice,
        analyticsAccepted: analytics,
      );
    } catch (e) {
      debugPrint('CONSENT: Failed to load consents: $e');
    }
  }

  List<ConsentRecord> getHistoryForType(ConsentType type) {
    return state.consents.where((c) => c.type == type).toList();
  }

  void clearAll() {
    state = ConsentState();
    _cachedIpAddress = null;
  }
}

final consentProvider = StateNotifierProvider<ConsentNotifier, ConsentState>((ref) {
  return ConsentNotifier();
});
