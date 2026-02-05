import 'package:flutter/foundation.dart';

/// V17: Système Marchand Dual
///
/// This file contains models and enums only.
/// Provider implementation is in: lib/core/providers/merchant_account_provider.dart
/// 
/// ARCHITECTURE LÉGALE:
/// - Pas de commission sur ventes
/// - Paiement hors plateforme
/// - Monétisation via abonnements et boosts uniquement
/// - Plateforme = mise en relation, pas marketplace financière

/// Type de compte marchand
enum MerchantType {
  particulier,  // KYC léger, plafond CA
  verifie,      // KYC complet, accès pro
}

/// Statut KYC du marchand
enum MerchantKycStatus {
  pending,      // En attente de vérification
  lightVerified, // KYC léger validé (particulier)
  fullVerified,  // KYC complet validé (vérifié)
  rejected,     // Rejeté
  expired,      // Expiré (renouvellement requis)
}

/// Statut du compte marchand
enum MerchantAccountStatus {
  active,       // Compte actif
  suspended,    // Suspendu (dépassement CA, KYC expiré...)
  blocked,      // Bloqué (violation CGU)
}

/// Modèle de compte marchand
@immutable
class MerchantAccount {
  final String id;
  final String userId;
  final MerchantType type;
  final MerchantKycStatus kycStatus;
  final MerchantAccountStatus accountStatus;
  
  // KYC Data
  final String? email;
  final String? pspAccountId;      // Stripe/Wave account ID
  final String? siretNinea;        // Pour vérifiés uniquement
  final String? idDocumentUrl;     // URL doc identité
  final String? selfieUrl;         // Pour vérifiés uniquement
  final String? iban;              // Pour remboursements uniquement (pas ventes!)
  
  // Limites et stats
  final double caAnnuel;           // Chiffre d'affaires année en cours
  final int offresActives;         // Nombre d'offres publiées
  final DateTime? subscriptionEnd; // Fin d'abonnement
  
  // Timestamps
  final DateTime createdAt;
  final DateTime? kycVerifiedAt;
  final DateTime? suspendedAt;
  
  // Constantes plafonds
  static const double particulierCaMax = 3000.0;  // € par an
  static const int particulierOffresMax = 5;
  
  const MerchantAccount({
    required this.id,
    required this.userId,
    required this.type,
    required this.kycStatus,
    required this.accountStatus,
    this.email,
    this.pspAccountId,
    this.siretNinea,
    this.idDocumentUrl,
    this.selfieUrl,
    this.iban,
    this.caAnnuel = 0.0,
    this.offresActives = 0,
    this.subscriptionEnd,
    required this.createdAt,
    this.kycVerifiedAt,
    this.suspendedAt,
  });

  /// Vérifie si le particulier a dépassé le plafond CA
  bool get isCaThresholdExceeded => 
      type == MerchantType.particulier && caAnnuel >= particulierCaMax;

  /// Vérifie si le particulier a atteint la limite d'offres
  bool get isOffresLimitReached =>
      type == MerchantType.particulier && offresActives >= particulierOffresMax;

  /// Peut publier une nouvelle offre
  bool get canPublishOffer {
    if (accountStatus != MerchantAccountStatus.active) return false;
    if (kycStatus != MerchantKycStatus.lightVerified && 
        kycStatus != MerchantKycStatus.fullVerified) {
      return false;
    }
    if (type == MerchantType.particulier && isOffresLimitReached) return false;
    if (isCaThresholdExceeded) return false;
    return true;
  }

  /// Message d'erreur si ne peut pas publier
  String? get publishBlockReason {
    if (accountStatus == MerchantAccountStatus.suspended) {
      return 'Compte suspendu. Contactez le support.';
    }
    if (accountStatus == MerchantAccountStatus.blocked) {
      return 'Compte bloqué pour violation des CGU.';
    }
    if (kycStatus == MerchantKycStatus.pending) {
      return 'Vérification KYC en cours.';
    }
    if (kycStatus == MerchantKycStatus.rejected) {
      return 'KYC rejeté. Veuillez soumettre de nouveaux documents.';
    }
    if (kycStatus == MerchantKycStatus.expired) {
      return 'KYC expiré. Veuillez renouveler votre vérification.';
    }
    if (isCaThresholdExceeded) {
      return 'Plafond CA atteint ($particulierCaMax€/an). Passez en compte Vérifié.';
    }
    if (isOffresLimitReached) {
      return 'Limite d\'offres atteinte ($particulierOffresMax). Passez en compte Vérifié ou supprimez des offres.';
    }
    return null;
  }

  /// Abonnement requis selon type
  String get requiredSubscription => 
      type == MerchantType.particulier ? 'MerchantParticulier' : 'MerchantPro';

  MerchantAccount copyWith({
    MerchantType? type,
    MerchantKycStatus? kycStatus,
    MerchantAccountStatus? accountStatus,
    String? email,
    String? pspAccountId,
    String? siretNinea,
    String? idDocumentUrl,
    String? selfieUrl,
    String? iban,
    double? caAnnuel,
    int? offresActives,
    DateTime? subscriptionEnd,
    DateTime? kycVerifiedAt,
    DateTime? suspendedAt,
  }) {
    return MerchantAccount(
      id: id,
      userId: userId,
      type: type ?? this.type,
      kycStatus: kycStatus ?? this.kycStatus,
      accountStatus: accountStatus ?? this.accountStatus,
      email: email ?? this.email,
      pspAccountId: pspAccountId ?? this.pspAccountId,
      siretNinea: siretNinea ?? this.siretNinea,
      idDocumentUrl: idDocumentUrl ?? this.idDocumentUrl,
      selfieUrl: selfieUrl ?? this.selfieUrl,
      iban: iban ?? this.iban,
      caAnnuel: caAnnuel ?? this.caAnnuel,
      offresActives: offresActives ?? this.offresActives,
      subscriptionEnd: subscriptionEnd ?? this.subscriptionEnd,
      createdAt: createdAt,
      kycVerifiedAt: kycVerifiedAt ?? this.kycVerifiedAt,
      suspendedAt: suspendedAt ?? this.suspendedAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'user_id': userId,
    'type': type.name,
    'kyc_status': kycStatus.name,
    'account_status': accountStatus.name,
    'email': email,
    'psp_account_id': pspAccountId,
    'siret_ninea': siretNinea,
    'id_document_url': idDocumentUrl,
    'selfie_url': selfieUrl,
    'iban': iban,
    'ca_annuel': caAnnuel,
    'offres_actives': offresActives,
    'subscription_end': subscriptionEnd?.toIso8601String(),
    'created_at': createdAt.toIso8601String(),
    'kyc_verified_at': kycVerifiedAt?.toIso8601String(),
    'suspended_at': suspendedAt?.toIso8601String(),
  };

  factory MerchantAccount.fromJson(Map<String, dynamic> json) => MerchantAccount(
    id: json['id'],
    userId: json['user_id'],
    type: MerchantType.values.byName(json['type']),
    kycStatus: MerchantKycStatus.values.byName(json['kyc_status']),
    accountStatus: MerchantAccountStatus.values.byName(json['account_status']),
    email: json['email'],
    pspAccountId: json['psp_account_id'],
    siretNinea: json['siret_ninea'],
    idDocumentUrl: json['id_document_url'],
    selfieUrl: json['selfie_url'],
    iban: json['iban'],
    caAnnuel: (json['ca_annuel'] as num?)?.toDouble() ?? 0.0,
    offresActives: json['offres_actives'] ?? 0,
    subscriptionEnd: json['subscription_end'] != null 
        ? DateTime.parse(json['subscription_end']) : null,
    createdAt: DateTime.parse(json['created_at']),
    kycVerifiedAt: json['kyc_verified_at'] != null 
        ? DateTime.parse(json['kyc_verified_at']) : null,
    suspendedAt: json['suspended_at'] != null 
        ? DateTime.parse(json['suspended_at']) : null,
  );
}

/// Options de boost produit
class BoostOption {
  final String id;
  final String name;
  final String description;
  final double price;
  final int durationDays;
  final bool isHomepageFeature;

  const BoostOption({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.durationDays,
    this.isHomepageFeature = false,
  });

  static const List<BoostOption> availableOptions = [
    BoostOption(
      id: 'boost_1d',
      name: 'Boost 1 jour',
      description: 'Votre produit apparaît en priorité pendant 24h',
      price: 1.99,
      durationDays: 1,
    ),
    BoostOption(
      id: 'boost_7d',
      name: 'Boost 7 jours',
      description: 'Visibilité premium pendant une semaine',
      price: 9.99,
      durationDays: 7,
    ),
    BoostOption(
      id: 'homepage_30d',
      name: 'Mise en avant Homepage',
      description: 'Affiché sur la page d\'accueil pendant 30 jours',
      price: 29.99,
      durationDays: 30,
      isHomepageFeature: true,
    ),
  ];
}

/// Obtenir les CGU marchands - Static utility
class MerchantCguHelper {
  static String getMerchantCgu() {
    return '''
ARTICLE – CONDITIONS MARCHANDS

1. TYPES DE COMPTES MARCHANDS
La Plateforme propose deux types de comptes marchands :

a) COMPTE PARTICULIER
• KYC simplifié (email + compte PSP)
• Plafond chiffre d'affaires : 3 000 € par an
• Limite : 5 offres actives simultanées
• Abonnement : 4,99 €/mois

b) COMPTE VÉRIFIÉ (Entreprises)
• KYC complet (SIRET/NINEA + pièce d'identité + selfie)
• Pas de plafond de chiffre d'affaires
• Offres illimitées
• Abonnement : 9,99 €/mois

2. RÉMUNÉRATION DE LA PLATEFORME
La Plateforme est rémunérée EXCLUSIVEMENT par :
• des abonnements marchands,
• des frais de services numériques (boost, mise en avant),
• des frais de publication au-delà du quota gratuit.

❌ La Plateforme ne prélève AUCUNE commission sur les ventes.
❌ La Plateforme n'intervient JAMAIS dans la transaction commerciale.

3. TRANSACTIONS HORS PLATEFORME
Toute transaction entre l'Utilisateur et le Marchand s'effectue
HORS de la Plateforme, sous la seule responsabilité des parties.

La Plateforme n'est pas responsable :
• du non-paiement par l'acheteur,
• de la non-livraison par le marchand,
• de tout litige commercial entre les parties.

4. DÉPASSEMENT DE SEUIL (Particuliers)
Lorsqu'un marchand Particulier atteint le plafond de 3 000 €/an :
• Notification automatique envoyée
• Nouvelles ventes bloquées
• Obligation de passer en compte Vérifié pour continuer

5. PRODUITS INTERDITS
Sont strictement interdits sur la Plateforme :
• Produits illégaux ou contrefaits
• Substances réglementées
• Contenu pour adultes
• Tout produit violant les CGU ou la loi applicable
''';
  }
}

// NOTE: Provider has been consolidated into merchant_account_provider.dart
// Use: import 'package:tontetic/core/providers/merchant_account_provider.dart';
// Provider: merchantShopProvider (or merchantAccountProvider for backward compat)
