import 'package:flutter/material.dart';
import 'package:tontetic/core/models/entitlement_model.dart';
import 'package:tontetic/core/services/security_service.dart';

enum UserZone { 
  zoneFCFA(label: 'Sénégal', currency: 'FCFA', locale: 'fr_SN'), 
  zoneEuro(label: 'France', currency: '€', locale: 'fr_FR');

  final String label;
  final String currency;
  final String locale;
  const UserZone({required this.label, required this.currency, required this.locale});
}

enum AccountStatus { guest, pending, verified }

enum BioPrivacyLevel { public, friends, private }

enum UserType { individual, company }

class UserState {
  final String uid;
  final String phoneNumber;
  final bool isPremium; // Legacy-sync: true if plan is not free
  final UserZone zone;
  final AccountStatus status;
  final String encryptedName;
  final String encryptedAddress;

  // Auth V2.0 Fields
  final UserType userType;
  final String encryptedSiret; // For Companies (SIRET/NINEA)
  final String encryptedRepresentative; // For Companies
  final String encryptedBirthDate; // For Individuals

  // New : Compteur de cercles actifs pour l'ACL
  final int activeCirclesCount;

  // V3.5 + V5.1 Profile
  final String? photoUrl;
  final String bio;
  final String jobTitle;
  final String company; 
  final BioPrivacyLevel bioPrivacy;
  
  // NOTE: In a real app, this would be computed from a list of user's circles.
  // For this mock, we assume 'premium' users are active in at least one circle.
  bool get hasActiveCircles => isPremium; 

  final List<String> trustScoreHistory;
  final bool isProfileCertified;
  final ThemeMode themeMode;
  // RGPD Fields
  final DateTime? createdAt;
  final String email;
  final int honorScore;
  final String? organizationId; // Links employee to Company UserID
  final String? professionalEmail; // For Domain Verification
  
  // V17 Stripe Integration
  final String? stripeCustomerId;
  final String? stripeSubscriptionId;
  final String? stripeConnectAccountId;
  final bool stripeConnectOnboardingComplete;
  
  // V8.0 Discovery Engine
  final List<String> objectives; // e.g. ['Moto', 'Maison', 'Voyage']
  
  // V9.5 Merchant Mode
  final bool isMerchant; // If true, user has a Pro/Business account
  
  // V11.2 Merchant Charter
  final bool hasSignedCharter; // Required before first publication

  final String? planId; // V15: Dynamic Plan Reference (Firestore)
  final Entitlement? entitlement; // New: Full Entitlements (Truth)

  bool get isEmployee => organizationId != null;

  bool get isKyVerified => status == AccountStatus.verified;

  String get currencySymbol => zone.currency;
  
  /// Returns true if user is in Africa (FCFA zone: Senegal, Mali, Ivory Coast, etc.)
  /// Used to show/hide mobile money options (Wave, Orange Money)
  bool get isAfricanRegion => zone == UserZone.zoneFCFA;
  
  /// Returns true if user is in Europe (Euro zone: France, Belgium, etc.)
  /// Used to show/hide SEPA options
  bool get isEuropeanRegion => zone == UserZone.zoneEuro;
  
  // Decrypted getters for UI
  String get displayName => SecurityService.decryptData(encryptedName);
  // Auth V2.0 Getters
  String get siret => SecurityService.decryptData(encryptedSiret);
  String get representativeName => SecurityService.decryptData(encryptedRepresentative);
  String get birthDate => SecurityService.decryptData(encryptedBirthDate);
  String get subscriptionTier => planId?.split('_').last ?? 'gratuit';

  UserState({
    required this.uid,
    required this.phoneNumber,
    required this.isPremium,
    required this.zone,
    required this.status,
    required this.encryptedName,
    this.encryptedAddress = '',
    this.userType = UserType.individual,
    this.encryptedSiret = '',
    this.encryptedRepresentative = '',
    this.encryptedBirthDate = '',
    this.activeCirclesCount = 0,
    this.photoUrl,
    this.bio = '',
    this.jobTitle = '',
    this.company = '',
    this.bioPrivacy = BioPrivacyLevel.public,
    this.trustScoreHistory = const [],
    this.isProfileCertified = false,
    this.themeMode = ThemeMode.system,
    this.createdAt,
    this.email = '',
    this.honorScore = 50,
    this.organizationId,
    this.professionalEmail,
    this.stripeCustomerId,
    this.stripeSubscriptionId,
    this.stripeConnectAccountId,
    this.stripeConnectOnboardingComplete = false,
    this.objectives = const [],
    this.isMerchant = false,
    this.hasSignedCharter = false,
    this.planId,
    this.entitlement,
  });

  UserState copyWith({
    String? uid,
    String? phoneNumber,
    bool? isPremium,
    UserZone? zone,
    AccountStatus? status,
    String? encryptedName,
    String? encryptedAddress,
    UserType? userType,
    String? encryptedSiret,
    String? encryptedRepresentative,
    String? encryptedBirthDate,
    int? activeCirclesCount,
    String? photoUrl,
    String? bio,
    String? jobTitle,
    String? company,
    BioPrivacyLevel? bioPrivacy,
    List<String>? trustScoreHistory,
    bool? isProfileCertified,
    ThemeMode? themeMode,
    String? organizationId,
    String? professionalEmail,
    List<String>? objectives,
    bool? isMerchant,
    bool? hasSignedCharter,
    String? email,
    int? honorScore,
    String? stripeCustomerId,
    String? stripeSubscriptionId,
    String? stripeConnectAccountId,
    bool? stripeConnectOnboardingComplete,
    String? planId,
    Entitlement? entitlement,
    DateTime? createdAt,
  }) {
    return UserState(
      uid: uid ?? this.uid,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      isPremium: isPremium ?? this.isPremium,
      zone: zone ?? this.zone,
      status: status ?? this.status,
      encryptedName: encryptedName ?? this.encryptedName,
      encryptedAddress: encryptedAddress ?? this.encryptedAddress,
      userType: userType ?? this.userType,
      encryptedSiret: encryptedSiret ?? this.encryptedSiret,
      encryptedRepresentative: encryptedRepresentative ?? this.encryptedRepresentative,
      encryptedBirthDate: encryptedBirthDate ?? this.encryptedBirthDate,
      activeCirclesCount: activeCirclesCount ?? this.activeCirclesCount,
      photoUrl: photoUrl ?? this.photoUrl,
      bio: bio ?? this.bio,
      jobTitle: jobTitle ?? this.jobTitle,
      company: company ?? this.company,
      bioPrivacy: bioPrivacy ?? this.bioPrivacy,
      trustScoreHistory: trustScoreHistory ?? this.trustScoreHistory,
      isProfileCertified: isProfileCertified ?? this.isProfileCertified,
      themeMode: themeMode ?? this.themeMode,
      organizationId: organizationId ?? this.organizationId,
      professionalEmail: professionalEmail ?? this.professionalEmail,
      objectives: objectives ?? this.objectives,
      isMerchant: isMerchant ?? this.isMerchant,
      hasSignedCharter: hasSignedCharter ?? this.hasSignedCharter,
      stripeCustomerId: stripeCustomerId ?? this.stripeCustomerId,
      stripeSubscriptionId: stripeSubscriptionId ?? this.stripeSubscriptionId,
      stripeConnectAccountId: stripeConnectAccountId ?? this.stripeConnectAccountId,
      stripeConnectOnboardingComplete: stripeConnectOnboardingComplete ?? this.stripeConnectOnboardingComplete,
      createdAt: createdAt ?? this.createdAt,
      email: email ?? this.email,
      honorScore: honorScore ?? this.honorScore,
      planId: planId ?? this.planId,
      entitlement: entitlement ?? this.entitlement,
    );
  }
}
