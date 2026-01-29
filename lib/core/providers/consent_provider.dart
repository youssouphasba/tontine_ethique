import 'package:flutter_riverpod/flutter_riverpod.dart';

/// RGPD Article 7: Consent Tracking
/// Tracks all user consents with timestamps and IP addresses

enum ConsentType {
  cgu,           // Terms of Service
  privacy,       // Privacy Policy  
  newsletter,    // Marketing emails
  cookies,       // Cookie usage
  dataSharing,   // Third-party data sharing
  voiceRecording,// AI voice consent
}

class ConsentRecord {
  final ConsentType type;
  final bool accepted;
  final DateTime timestamp;
  final String ipAddress;
  final String? version; // CGU version if applicable

  ConsentRecord({
    required this.type,
    required this.accepted,
    required this.timestamp,
    required this.ipAddress,
    this.version,
  });

  Map<String, dynamic> toJson() => {
    'type': type.name,
    'accepted': accepted,
    'timestamp': timestamp.toIso8601String(),
    'ipAddress': ipAddress,
    'version': version,
  };
}

class ConsentState {
  final List<ConsentRecord> consents;
  final bool cguAccepted;
  final bool privacyAccepted;
  final bool newsletterAccepted;
  final bool voiceConsentGiven;

  ConsentState({
    this.consents = const [],
    this.cguAccepted = false,
    this.privacyAccepted = false,
    this.newsletterAccepted = false,
    this.voiceConsentGiven = false,
  });

  ConsentState copyWith({
    List<ConsentRecord>? consents,
    bool? cguAccepted,
    bool? privacyAccepted,
    bool? newsletterAccepted,
    bool? voiceConsentGiven,
  }) {
    return ConsentState(
      consents: consents ?? this.consents,
      cguAccepted: cguAccepted ?? this.cguAccepted,
      privacyAccepted: privacyAccepted ?? this.privacyAccepted,
      newsletterAccepted: newsletterAccepted ?? this.newsletterAccepted,
      voiceConsentGiven: voiceConsentGiven ?? this.voiceConsentGiven,
    );
  }

  bool hasConsent(ConsentType type) {
    final record = consents.where((c) => c.type == type).lastOrNull;
    return record?.accepted ?? false;
  }
}

class ConsentNotifier extends StateNotifier<ConsentState> {
  ConsentNotifier() : super(ConsentState());

  void recordConsent({
    required ConsentType type,
    required bool accepted,
    required String ipAddress,
    String? version,
  }) {
    final record = ConsentRecord(
      type: type,
      accepted: accepted,
      timestamp: DateTime.now(),
      ipAddress: ipAddress,
      version: version,
    );

    state = state.copyWith(
      consents: [...state.consents, record],
      cguAccepted: type == ConsentType.cgu ? accepted : state.cguAccepted,
      privacyAccepted: type == ConsentType.privacy ? accepted : state.privacyAccepted,
      newsletterAccepted: type == ConsentType.newsletter ? accepted : state.newsletterAccepted,
      voiceConsentGiven: type == ConsentType.voiceRecording ? accepted : state.voiceConsentGiven,
    );
  }

  void revokeConsent(ConsentType type, String ipAddress) {
    recordConsent(type: type, accepted: false, ipAddress: ipAddress);
  }

  void acceptCGUAndPrivacy(String ipAddress, String cguVersion) {
    recordConsent(
      type: ConsentType.cgu,
      accepted: true,
      ipAddress: ipAddress,
      version: cguVersion,
    );
    recordConsent(
      type: ConsentType.privacy,
      accepted: true,
      ipAddress: ipAddress,
      version: cguVersion,
    );
  }

  List<ConsentRecord> getHistoryForType(ConsentType type) {
    return state.consents.where((c) => c.type == type).toList();
  }

  void clearAll() {
    state = ConsentState();
  }
}

final consentProvider = StateNotifierProvider<ConsentNotifier, ConsentState>((ref) {
  return ConsentNotifier();
});
