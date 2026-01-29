import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// V17: Service de Garantie SEPA Conditionnelle
/// 
/// ARCHITECTURE SEPA PURE (aucun transit par Tontetic):
/// 
/// 1. MANDAT A - Cotisations récurrentes
///    → Prélèvement SEPA automatique chaque tour
///    → Directement du compte membre → compte bénéficiaire
/// 
/// 2. MANDAT B - Garantie conditionnelle
///    → AUTORISATION seulement, pas de prélèvement
///    → Déclenchée UNIQUEMENT en cas de défaut avéré
///    → Montant = 1 cotisation maximum
/// 
/// RÈGLES JURIDIQUES:
/// - Tontetic = prestataire technique uniquement
/// - Aucun encaissement, aucun wallet
/// - Pas de licence ACPR/EME/EMI requise
/// - Garantie = consentement préalable, pas dette exigible

enum MandateType {
  contributionRecurring,  // Mandat A: cotisations
  guaranteeConditional,   // Mandat B: garantie (déclenchée sur défaut)
}

enum MandateStatus {
  pending,      // En attente de signature
  active,       // Signé et actif
  suspended,    // Suspendu temporairement
  revoked,      // Révoqué par l'utilisateur
  triggered,    // Garantie déclenchée (Mandat B uniquement)
}

enum DefaultType {
  insufficientFunds,    // Fonds insuffisants (rejet SEPA)
  maxRetriesExceeded,   // Nombre max de tentatives atteint
  gracePeriodExpired,   // Délai de grâce expiré
}

class SepaMandate {
  final String id;
  final String oderId;
  final String tontineId;
  final MandateType type;
  final MandateStatus status;
  final double amount;              // Montant cotisation ou garantie max
  final String iban;                // IBAN du membre (masqué)
  final DateTime signedAt;
  final DateTime? triggeredAt;      // Pour Mandat B uniquement
  final DefaultType? triggerReason; // Raison du déclenchement
  
  // Conditions du Mandat B (garantie)
  final int maxRetries;             // Nb tentatives avant défaut (ex: 3)
  final int gracePeriodDays;        // Délai de grâce en jours (ex: 7)

  SepaMandate({
    required this.id,
    required this.oderId,
    required this.tontineId,
    required this.type,
    required this.status,
    required this.amount,
    required this.iban,
    required this.signedAt,
    this.triggeredAt,
    this.triggerReason,
    this.maxRetries = 3,
    this.gracePeriodDays = 7,
  });

  bool get isGuarantee => type == MandateType.guaranteeConditional;
  bool get isTriggered => status == MandateStatus.triggered;
  bool get canTrigger => isGuarantee && status == MandateStatus.active;

  Map<String, dynamic> toJson() => {
    'id': id,
    'user_id': oderId,
    'tontine_id': tontineId,
    'type': type.name,
    'status': status.name,
    'amount': amount,
    'iban': iban,
    'signed_at': signedAt.toIso8601String(),
    'triggered_at': triggeredAt?.toIso8601String(),
    'trigger_reason': triggerReason?.name,
    'max_retries': maxRetries,
    'grace_period_days': gracePeriodDays,
  };

  factory SepaMandate.fromJson(Map<String, dynamic> json) => SepaMandate(
    id: json['id'],
    oderId: json['user_id'],
    tontineId: json['tontine_id'],
    type: MandateType.values.byName(json['type']),
    status: MandateStatus.values.byName(json['status']),
    amount: (json['amount'] as num).toDouble(),
    iban: json['iban'],
    signedAt: DateTime.parse(json['signed_at']),
    triggeredAt: json['triggered_at'] != null 
        ? DateTime.parse(json['triggered_at']) 
        : null,
    triggerReason: json['trigger_reason'] != null 
        ? DefaultType.values.byName(json['trigger_reason']) 
        : null,
    maxRetries: json['max_retries'] ?? 3,
    gracePeriodDays: json['grace_period_days'] ?? 7,
  );
}

class DefaultEvent {
  final String id;
  final String oderId;
  final String tontineId;
  final int tourNumber;
  final DefaultType type;
  final int attemptCount;
  final DateTime detectedAt;
  final DateTime gracePeriodEndsAt;
  final bool guaranteeTriggered;

  DefaultEvent({
    required this.id,
    required this.oderId,
    required this.tontineId,
    required this.tourNumber,
    required this.type,
    required this.attemptCount,
    required this.detectedAt,
    required this.gracePeriodEndsAt,
    this.guaranteeTriggered = false,
  });

  bool get isGracePeriodExpired => DateTime.now().isAfter(gracePeriodEndsAt);
}

class SepaGuaranteeService {
  
  // Configuration par défaut
  static const int defaultMaxRetries = 3;
  static const int defaultGracePeriodDays = 7;

  // ============ CRÉATION DES MANDATS ============

  /// Créer les deux mandats SEPA à la signature
  /// Appelé quand un membre rejoint une tontine
  Future<MandateCreationResult> createMandates({
    required String oderId,
    required String tontineId,
    required double contributionAmount,
    required String iban,
  }) async {
    final now = DateTime.now();
    final guaranteeAmount = contributionAmount; // 1 cotisation = garantie max

    // Mandat A: Cotisations récurrentes
    final mandateA = SepaMandate(
      id: 'mandate_a_${now.millisecondsSinceEpoch}',
      oderId: oderId,
      tontineId: tontineId,
      type: MandateType.contributionRecurring,
      status: MandateStatus.pending,
      amount: contributionAmount,
      iban: _maskIban(iban),
      signedAt: now,
    );

    // Mandat B: Garantie conditionnelle (AUTORISATION SEULEMENT)
    final mandateB = SepaMandate(
      id: 'mandate_b_${now.millisecondsSinceEpoch}',
      oderId: oderId,
      tontineId: tontineId,
      type: MandateType.guaranteeConditional,
      status: MandateStatus.pending,
      amount: guaranteeAmount,
      iban: _maskIban(iban),
      signedAt: now,
      maxRetries: defaultMaxRetries,
      gracePeriodDays: defaultGracePeriodDays,
    );

    debugPrint('[SEPA] Created mandates for $oderId:');
    debugPrint('  → Mandat A: $contributionAmount€ (cotisations)');
    debugPrint('  → Mandat B: $guaranteeAmount€ (garantie conditionnelle)');

    return MandateCreationResult(
      mandateA: mandateA,
      mandateB: mandateB,
      legalText: _generateLegalText(contributionAmount, guaranteeAmount),
    );
  }

  // ============ DÉTECTION DE DÉFAUT ============

  /// Enregistrer un échec de prélèvement
  /// Appelé automatiquement par le PSP (webhook Stripe)
  Future<DefaultCheckResult> recordPaymentFailure({
    required String oderId,
    required String tontineId,
    required int tourNumber,
    required int currentAttempt,
    required int maxRetries,
    required int gracePeriodDays,
  }) async {
    final now = DateTime.now();
    
    // Créer l'événement de défaut
    final defaultEvent = DefaultEvent(
      id: 'default_${now.millisecondsSinceEpoch}',
      oderId: oderId,
      tontineId: tontineId,
      tourNumber: tourNumber,
      type: currentAttempt >= maxRetries 
          ? DefaultType.maxRetriesExceeded 
          : DefaultType.insufficientFunds,
      attemptCount: currentAttempt,
      detectedAt: now,
      gracePeriodEndsAt: now.add(Duration(days: gracePeriodDays)),
    );

    debugPrint('[SEPA] Payment failure recorded:');
    debugPrint('  → User: $oderId');
    debugPrint('  → Attempt: $currentAttempt / $maxRetries');
    debugPrint('  → Grace period ends: ${defaultEvent.gracePeriodEndsAt}');

    // Vérifier si on doit déclencher la garantie
    final shouldTrigger = currentAttempt >= maxRetries;

    return DefaultCheckResult(
      event: defaultEvent,
      shouldTriggerGuarantee: shouldTrigger,
      message: shouldTrigger
          ? 'Défaut avéré après $maxRetries tentatives. Garantie sera déclenchée.'
          : 'Tentative $currentAttempt échouée. $maxRetries tentatives restantes.',
    );
  }

  // ============ DÉCLENCHEMENT AUTOMATIQUE ============

  /// Déclencher la garantie (AUTOMATIQUE - pas de décision humaine)
  /// Appelé uniquement quand défaut objectif est constaté
  Future<GuaranteeTriggerResult> triggerGuarantee({
    required SepaMandate mandateB,
    required DefaultEvent defaultEvent,
    required String beneficiaryIban,
  }) async {
    // Vérifications
    if (!mandateB.canTrigger) {
      return GuaranteeTriggerResult(
        success: false,
        message: 'Le mandat de garantie ne peut pas être déclenché (status: ${mandateB.status})',
      );
    }

    debugPrint('[SEPA] ⚠️ TRIGGERING GUARANTEE:');
    debugPrint('  → User: ${mandateB.oderId}');
    debugPrint('  → Amount: ${mandateB.amount}€');
    debugPrint('  → Reason: ${defaultEvent.type.name}');
    debugPrint('  → Beneficiary: ${_maskIban(beneficiaryIban)}');

    // Ici on enverrait la commande au PSP (Stripe)
    // await _pspClient.triggerConditionalMandate(mandateB.id, beneficiaryIban);

    return GuaranteeTriggerResult(
      success: true,
      message: 'Garantie déclenchée automatiquement. '
               'Montant: ${mandateB.amount}€ → Bénéficiaire du tour.',
      triggeredAt: DateTime.now(),
    );
  }

  // ============ TEXTES LÉGAUX ============

  String _generateLegalText(double contribution, double guarantee) {
    return '''
MANDATS DE PRÉLÈVEMENT SEPA

═══════════════════════════════════════════════════════════

MANDAT A - COTISATIONS RÉCURRENTES
Montant : $contribution €
Fréquence : À chaque tour de la tontine
Prélèvement : Automatique selon le calendrier défini

═══════════════════════════════════════════════════════════

MANDAT B - GARANTIE CONDITIONNELLE
Montant maximum : $guarantee €

⚠️ IMPORTANT : Ce mandat est une AUTORISATION, pas un prélèvement.

CONDITIONS DE DÉCLENCHEMENT :
• Prélèvement SEPA rejeté (fonds insuffisants)
• Après $defaultMaxRetries tentatives de prélèvement échouées
• Après expiration du délai de grâce de $defaultGracePeriodDays jours

AUCUN PRÉLÈVEMENT ne sera effectué tant qu'un défaut objectif,
tel que défini ci-dessus, n'est pas constaté par le prestataire
de paiement.

En cas de déclenchement, le montant sera versé directement au
bénéficiaire du tour concerné, jamais à Tontetic.

═══════════════════════════════════════════════════════════

En signant ces mandats, vous autorisez le prestataire de paiement
à débiter votre compte selon les conditions ci-dessus.

Vous pouvez révoquer ce mandat à tout moment en contactant votre
banque, sous réserve des obligations en cours.
''';
  }

  String getLegalClauseForCGU() {
    return '''
La garantie constitue une autorisation de prélèvement conditionnelle.
Aucun montant n'est prélevé tant qu'un défaut objectif, tel que défini
dans les présentes, n'est constaté par le prestataire de paiement.

Le défaut est caractérisé de manière objective et automatique par :
- Le rejet du prélèvement SEPA pour insuffisance de provision
- L'échec de $defaultMaxRetries tentatives successives de prélèvement
- Le dépassement du délai de grâce de $defaultGracePeriodDays jours

Le déclenchement de la garantie est automatique et ne fait l'objet
d'aucune décision discrétionnaire de Tontetic ou des autres membres.
''';
  }

  // ============ HELPERS ============

  String _maskIban(String iban) {
    if (iban.length < 8) return '****';
    return '${iban.substring(0, 4)}****${iban.substring(iban.length - 4)}';
  }
}

// ============ RESULT CLASSES ============

class MandateCreationResult {
  final SepaMandate mandateA;
  final SepaMandate mandateB;
  final String legalText;

  MandateCreationResult({
    required this.mandateA,
    required this.mandateB,
    required this.legalText,
  });
}

class DefaultCheckResult {
  final DefaultEvent event;
  final bool shouldTriggerGuarantee;
  final String message;

  DefaultCheckResult({
    required this.event,
    required this.shouldTriggerGuarantee,
    required this.message,
  });
}

class GuaranteeTriggerResult {
  final bool success;
  final String message;
  final DateTime? triggeredAt;

  GuaranteeTriggerResult({
    required this.success,
    required this.message,
    this.triggeredAt,
  });
}

// ============ PROVIDER ============

final sepaGuaranteeServiceProvider = Provider<SepaGuaranteeService>((ref) {
  return SepaGuaranteeService();
});
