import 'package:flutter/foundation.dart';

/// B. Flux Utilisateurs (argent tiers) - LECTURE SEULE
/// C. Flux Promotionnels (primes) - traçable

// ============================================================
// ENUMS & TYPES
// ============================================================

/// Types de flux financiers
enum FinancialFlowType {
  platform,     // Notre argent (abos, commissions, boosts)
  userThirdParty,  // Argent tiers - LECTURE SEULE via PSP
  promotional,  // Primes, cashback, parrainage
}

/// PSP disponibles
enum PaymentProvider {
  stripe,
  wave,
  paypal,
  orangeMoney,
}

/// Statuts de transaction plateforme
enum PlatformTransactionStatus {
  pending,
  paid,
  failed,
  refunded,
  disputed,
}

/// Types de revenus plateforme
enum PlatformRevenueType {
  enterpriseSubscription,  // Abonnement entreprise
  premiumOption,           // Options premium utilisateur
  merchantBoost,           // Boost marchand
  fixedCommission,         // Commission fixe (si autorisée)
}

/// Statuts PSP (LECTURE SEULE)
enum PspTransactionStatus {
  authorized,   // Autorisé
  captured,     // Prélevé
  rejected,     // Rejeté
  pending,      // En attente
}

/// Types de primes
enum PromotionalType {
  referral,       // Parrainage
  cashback,       // Cashback
  enterpriseBonus,// Bonus entreprise
}

/// Statuts de prime
enum PromotionalStatus {
  eligible,    // Éligible
  triggered,   // Déclenché
  paid,        // Versé
  expired,     // Expiré
}

/// Types d'événements ledger
enum LedgerEventType {
  platformRevenue,
  platformRefund,
  pspNotification,
  promotionalCredit,
  reconciliationAdjustment,
  systemAction,
  adminAction,
}

/// Types d'alertes
enum FinancialAlertType {
  highFailureRate,
  unconfirmedAfter48h,
  paidButNotActivated,
  duplicatePsp,
  abnormalTransactionPeak,
  inactiveButBilled,
  promotionalWithoutEligibility,
}

enum AlertSeverity { info, warning, critical }

// ============================================================
// BLOC A: FLUX PLATEFORME (NOTRE ARGENT)
// ============================================================

class PlatformTransaction {
  final String id;
  final PlatformRevenueType type;
  final double amountHT;    // Hors Taxe
  final double tva;         // TVA
  final double amountTTC;   // Toutes Taxes Comprises
  final PaymentProvider psp;
  final String? invoiceId;  // ID facture émise
  final PlatformTransactionStatus status;
  final DateTime createdAt;
  final String? clientId;
  final String? clientName;
  final String? clientCountry;
  final double tvaRate;
  final bool isVatExempt;   // Exonération B2B intra-UE
  final String? vatNumber;  // N° TVA entreprise

  PlatformTransaction({
    required this.id,
    required this.type,
    required this.amountHT,
    required this.tva,
    required this.amountTTC,
    required this.psp,
    this.invoiceId,
    required this.status,
    required this.createdAt,
    this.clientId,
    this.clientName,
    this.clientCountry,
    this.tvaRate = 0.18,
    this.isVatExempt = false,
    this.vatNumber,
  });
}

// ============================================================
// BLOC B: FLUX UTILISATEURS (ARGENT TIERS - LECTURE SEULE)
// ============================================================

/// ⚠️ LECTURE SEULE - "Informations fournies à titre indicatif par le PSP"
class PspUserTransaction {
  final String pspReference;  // Référence PSP
  final PspTransactionStatus status;
  final DateTime date;
  final String circleId;
  final String circleName;
  final double amount;
  final PaymentProvider psp;
  
  // ⚠️ AUCUN CHAMP MODIFIABLE

  const PspUserTransaction({
    required this.pspReference,
    required this.status,
    required this.date,
    required this.circleId,
    required this.circleName,
    required this.amount,
    required this.psp,
  });
}

// ============================================================
// BLOC C: FLUX PROMOTIONNELS / PRIMES
// ============================================================

class PromotionalTransaction {
  final String id;
  final PromotionalType type;
  final double amount;
  final String payerProvider;  // Prestataire payeur
  final DateTime eligibilityDate;
  final PromotionalStatus status;
  final String? beneficiaryId;
  final String? beneficiaryName;
  final String? reason;

  PromotionalTransaction({
    required this.id,
    required this.type,
    required this.amount,
    required this.payerProvider,
    required this.eligibilityDate,
    required this.status,
    this.beneficiaryId,
    this.beneficiaryName,
    this.reason,
  });
}

// ============================================================
// JOURNAL FINANCIER IMMUABLE (LEDGER)
// ============================================================

/// ❌ PAS DE SUPPRESSION - ✅ SEULEMENT DES ÉCRITURES CORRECTIVES
class LedgerEntry {
  final String id;
  final DateTime timestampUtc;
  final LedgerEventType eventType;
  final String? userId;
  final String? enterpriseId;
  final String? pspId;
  final String action;  // Action système ou humaine
  final String? ipAddress;
  final String? deviceInfo;
  final double? amount;
  final String? currency;
  final Map<String, dynamic>? metadata;

  const LedgerEntry({
    required this.id,
    required this.timestampUtc,
    required this.eventType,
    this.userId,
    this.enterpriseId,
    this.pspId,
    required this.action,
    this.ipAddress,
    this.deviceInfo,
    this.amount,
    this.currency,
    this.metadata,
  });
}

// ============================================================
// RÉCONCILIATION PSP
// ============================================================

class PspReconciliation {
  final String id;
  final DateTime date;
  final PaymentProvider psp;
  final double expectedAmount;
  final double confirmedAmount;
  final double discrepancy;
  final int transactionCount;
  final int matchedCount;
  final int unmatchedCount;
  final List<String> alerts;

  PspReconciliation({
    required this.id,
    required this.date,
    required this.psp,
    required this.expectedAmount,
    required this.confirmedAmount,
    required this.discrepancy,
    required this.transactionCount,
    required this.matchedCount,
    required this.unmatchedCount,
    this.alerts = const [],
  });
}

// ============================================================
// GESTION DES LITIGES & REMBOURSEMENTS
// ============================================================

class DisputeCase {
  final String id;
  final DateTime receivedAt;
  final String reason;
  final String? userId;
  final String? transactionRef;
  final String decision;  // Plateforme ou PSP
  final String writtenTrace;
  final String status;
  final DateTime? resolvedAt;
  final bool refundTriggeredViaPsp;  // ⚠️ On ne rembourse jamais directement
  final String? proofArchiveId;

  DisputeCase({
    required this.id,
    required this.receivedAt,
    required this.reason,
    this.userId,
    this.transactionRef,
    required this.decision,
    required this.writtenTrace,
    required this.status,
    this.resolvedAt,
    this.refundTriggeredViaPsp = false,
    this.proofArchiveId,
  });
}

// ============================================================
// ALERTES AUTOMATIQUES
// ============================================================

class FinancialAlert {
  final String id;
  final FinancialAlertType type;
  final AlertSeverity severity;
  final String message;
  final DateTime createdAt;
  final bool acknowledged;
  final String? relatedEntityId;

  FinancialAlert({
    required this.id,
    required this.type,
    required this.severity,
    required this.message,
    required this.createdAt,
    this.acknowledged = false,
    this.relatedEntityId,
  });
}

// ============================================================
// SERVICE PRINCIPAL
// ============================================================

class FinancialDashboardService {
  static final FinancialDashboardService _instance = FinancialDashboardService._internal();
  factory FinancialDashboardService() => _instance;
  FinancialDashboardService._internal();

  // Data stores
  final List<PlatformTransaction> _platformTransactions = [];
  final List<PspUserTransaction> _pspUserTransactions = [];  // LECTURE SEULE
  final List<PromotionalTransaction> _promotionalTransactions = [];
  final List<LedgerEntry> _ledger = [];  // IMMUABLE
  final List<PspReconciliation> _reconciliations = [];
  final List<DisputeCase> _disputes = [];
  final List<FinancialAlert> _alerts = [];

  // ============================================================
  // INITIALISATION DEMO
  // ============================================================

  void initDemoData() {
    // Demo data removed for production. 
    // In a real app, this internal storage would be populated by 
    // fetching from Firestore or an API in the initialization logic.
  }

  // ============================================================
  // BLOC A: FLUX PLATEFORME (NOTRE ARGENT)
  // ============================================================

  List<PlatformTransaction> getPlatformTransactions() => 
    List.unmodifiable(_platformTransactions);

  Map<String, dynamic> getPlatformStats() {
    final paid = _platformTransactions.where((t) => t.status == PlatformTransactionStatus.paid);
    
    final totalHT = paid.fold<double>(0, (sum, t) => sum + t.amountHT);
    final totalTVA = paid.fold<double>(0, (sum, t) => sum + t.tva);
    final totalTTC = paid.fold<double>(0, (sum, t) => sum + t.amountTTC);

    // MRR (Monthly Recurring Revenue)
    final subscriptions = paid.where((t) => t.type == PlatformRevenueType.enterpriseSubscription);
    final mrr = subscriptions.fold<double>(0, (sum, t) => sum + t.amountTTC);

    // Par type
    final byType = <PlatformRevenueType, double>{};
    for (final t in paid) {
      byType[t.type] = (byType[t.type] ?? 0) + t.amountTTC;
    }

    return {
      'totalHT': totalHT,
      'totalTVA': totalTVA,
      'totalTTC': totalTTC,
      'mrr': mrr,
      'transactionCount': paid.length,
      'byType': byType.map((k, v) => MapEntry(k.name, v)),
      'byPsp': _groupByPsp(paid),
    };
  }

  // ============================================================
  // BLOC B: FLUX UTILISATEURS (LECTURE SEULE - PSP)
  // ============================================================

  /// ⚠️ LECTURE SEULE - "Informations fournies à titre indicatif par le PSP"
  List<PspUserTransaction> getPspUserTransactions() => 
    List.unmodifiable(_pspUserTransactions);

  Map<String, dynamic> getPspUserStats() {
    return {
      'disclaimer': 'Informations fournies à titre indicatif par le PSP',
      'totalTransactions': _pspUserTransactions.length,
      'captured': _pspUserTransactions.where((t) => t.status == PspTransactionStatus.captured).length,
      'authorized': _pspUserTransactions.where((t) => t.status == PspTransactionStatus.authorized).length,
      'rejected': _pspUserTransactions.where((t) => t.status == PspTransactionStatus.rejected).length,
      'pending': _pspUserTransactions.where((t) => t.status == PspTransactionStatus.pending).length,
    };
  }

  // ============================================================
  // BLOC C: FLUX PROMOTIONNELS
  // ============================================================

  List<PromotionalTransaction> getPromotionalTransactions() => 
    List.unmodifiable(_promotionalTransactions);

  Map<String, dynamic> getPromotionalStats() {
    return {
      'total': _promotionalTransactions.length,
      'totalAmount': _promotionalTransactions.fold<double>(0, (sum, t) => sum + t.amount),
      'paid': _promotionalTransactions.where((t) => t.status == PromotionalStatus.paid).length,
      'triggered': _promotionalTransactions.where((t) => t.status == PromotionalStatus.triggered).length,
      'eligible': _promotionalTransactions.where((t) => t.status == PromotionalStatus.eligible).length,
    };
  }

  // ============================================================
  // LEDGER IMMUABLE
  // ============================================================

  /// ❌ PAS DE SUPPRESSION - Ajouter seulement
  void _addLedgerEntry({
    required LedgerEventType eventType,
    required String action,
    String? userId,
    String? enterpriseId,
    String? pspId,
    double? amount,
    String? ipAddress,
    String? deviceInfo,
  }) {
    _ledger.add(LedgerEntry(
      id: 'ledger_${_ledger.length + 1}_${DateTime.now().millisecondsSinceEpoch}',
      timestampUtc: DateTime.now().toUtc(),
      eventType: eventType,
      userId: userId,
      enterpriseId: enterpriseId,
      pspId: pspId,
      action: action,
      amount: amount,
      ipAddress: ipAddress,
      deviceInfo: deviceInfo,
      currency: 'FCFA',
    ));
  }

  /// Écriture corrective (le seul moyen de "modifier")
  void addCorrectiveEntry({
    required String originalEntryId,
    required String reason,
    required double? correctedAmount,
    String? adminId,
  }) {
    _addLedgerEntry(
      eventType: LedgerEventType.reconciliationAdjustment,
      action: 'CORRECTION: $reason (réf: $originalEntryId)',
      amount: correctedAmount,
    );
    debugPrint('[Ledger] Corrective entry added for $originalEntryId');
  }

  List<LedgerEntry> getLedger() => List.unmodifiable(_ledger);

  // ============================================================
  // RÉCONCILIATION PSP
  // ============================================================

  List<PspReconciliation> getReconciliations() => List.unmodifiable(_reconciliations);

  PspReconciliation? getLatestReconciliation(PaymentProvider psp) {
    final filtered = _reconciliations.where((r) => r.psp == psp).toList();
    if (filtered.isEmpty) return null;
    filtered.sort((a, b) => b.date.compareTo(a.date));
    return filtered.first;
  }

  // ============================================================
  // LITIGES & REMBOURSEMENTS
  // ============================================================

  List<DisputeCase> getDisputes() => List.unmodifiable(_disputes);

  /// ⚠️ On ne rembourse jamais directement - on déclenche via le PSP
  void triggerRefundViaPsp(String disputeId) {
    final index = _disputes.indexWhere((d) => d.id == disputeId);
    if (index == -1) return;

    _addLedgerEntry(
      eventType: LedgerEventType.adminAction,
      action: 'Remboursement déclenché via PSP pour litige $disputeId',
    );
    debugPrint('[Financial] Refund triggered via PSP for dispute $disputeId');
  }

  // ============================================================
  // ALERTES
  // ============================================================

  List<FinancialAlert> getAlerts() => List.unmodifiable(_alerts);

  List<FinancialAlert> getCriticalAlerts() =>
    _alerts.where((a) => a.severity == AlertSeverity.critical && !a.acknowledged).toList();

  void acknowledgeAlert(String alertId) {
    final index = _alerts.indexWhere((a) => a.id == alertId);
    if (index == -1) return;

    _alerts[index] = FinancialAlert(
      id: _alerts[index].id,
      type: _alerts[index].type,
      severity: _alerts[index].severity,
      message: _alerts[index].message,
      createdAt: _alerts[index].createdAt,
      acknowledged: true,
      relatedEntityId: _alerts[index].relatedEntityId,
    );
  }

  // ============================================================
  // REPORTING (MRR, Churn, etc.)
  // ============================================================

  Map<String, dynamic> getExecutiveReport() {
    final platformStats = getPlatformStats();
    
    return {
      'mrr': platformStats['mrr'],
      'totalRevenueTTC': platformStats['totalTTC'],
      'totalTVA': platformStats['totalTVA'],
      'enterpriseCount': _platformTransactions
        .where((t) => t.type == PlatformRevenueType.enterpriseSubscription)
        .map((t) => t.clientId)
        .toSet()
        .length,
      'averageBasket': platformStats['transactionCount'] > 0 
        ? (platformStats['totalTTC'] as double) / (platformStats['transactionCount'] as int)
        : 0,
      'topClients': _getTopClients(5),
      'revenueByFeature': platformStats['byType'],
      'pspReconciliationStatus': _getReconciliationSummary(),
      'activeAlerts': _alerts.where((a) => !a.acknowledged).length,
      'criticalAlerts': getCriticalAlerts().length,
    };
  }

  List<Map<String, dynamic>> _getTopClients(int limit) {
    final byClient = <String, double>{};
    for (final t in _platformTransactions.where((t) => t.status == PlatformTransactionStatus.paid)) {
      final key = t.clientName ?? 'Unknown';
      byClient[key] = (byClient[key] ?? 0) + t.amountTTC;
    }
    final sorted = byClient.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(limit).map((e) => {'name': e.key, 'revenue': e.value}).toList();
  }

  Map<String, dynamic> _getReconciliationSummary() {
    final lastRecons = <PaymentProvider, PspReconciliation>{};
    for (final psp in PaymentProvider.values) {
      final latest = getLatestReconciliation(psp);
      if (latest != null) lastRecons[psp] = latest;
    }
    return {
      'status': lastRecons.values.every((r) => r.discrepancy == 0) ? 'OK' : 'ALERT',
      'totalDiscrepancy': lastRecons.values.fold<double>(0, (sum, r) => sum + r.discrepancy),
      'byPsp': lastRecons.map((k, v) => MapEntry(k.name, {
        'discrepancy': v.discrepancy,
        'matched': '${v.matchedCount}/${v.transactionCount}',
      })),
    };
  }

  Map<String, dynamic> _groupByPsp(Iterable<PlatformTransaction> transactions) {
    final byPsp = <PaymentProvider, double>{};
    for (final t in transactions) {
      byPsp[t.psp] = (byPsp[t.psp] ?? 0) + t.amountTTC;
    }
    return byPsp.map((k, v) => MapEntry(k.name, v));
  }

  // ============================================================
  // EXPORTS LÉGAUX (CSV / Archivage)
  // ============================================================

  /// Export mensuel pour expert-comptable
  String exportMonthlyCSV(int year, int month) {
    final transactions = _platformTransactions.where((t) =>
      t.createdAt.year == year && t.createdAt.month == month);

    final buffer = StringBuffer();
    buffer.writeln('Date,Type,Client,Pays,MontantHT,TVA,TauxTVA,MontantTTC,PSP,Facture,Statut,NumTVA');
    
    for (final t in transactions) {
      buffer.writeln(
        '"${t.createdAt.toIso8601String()}","${t.type.name}","${t.clientName}","${t.clientCountry}",'
        '"${t.amountHT}","${t.tva}","${(t.tvaRate * 100).toStringAsFixed(0)}%","${t.amountTTC}",'
        '"${t.psp.name}","${t.invoiceId ?? ''}","${t.status.name}","${t.vatNumber ?? ''}"'
      );
    }
    return buffer.toString();
  }

  /// Export du ledger
  String exportLedgerCSV() {
    final buffer = StringBuffer();
    buffer.writeln('Timestamp,Type,Action,UserID,EnterpriseID,PspID,Amount,Currency,IP');
    
    for (final e in _ledger) {
      buffer.writeln(
        '"${e.timestampUtc.toIso8601String()}","${e.eventType.name}","${e.action}",'
        '"${e.userId ?? ''}","${e.enterpriseId ?? ''}","${e.pspId ?? ''}",'
        '"${e.amount ?? ''}","${e.currency ?? ''}","${e.ipAddress ?? ''}"'
      );
    }
    return buffer.toString();
  }

  /// Note: Archivage 10 ans (UE) - structure présente même si non utilisée
  Future<String> createYearlyArchive(int year) async {
    // Simulation - en production: génération de fichier signé
    debugPrint('[Financial] Creating yearly archive for $year');
    return 'archive_${year}_${DateTime.now().millisecondsSinceEpoch}.zip';
  }

  // ============================================================
  // LABELS
  // ============================================================

  String getRevenueTypeLabel(PlatformRevenueType type) {
    switch (type) {
      case PlatformRevenueType.enterpriseSubscription: return 'Abonnement Entreprise';
      case PlatformRevenueType.premiumOption: return 'Option Premium';
      case PlatformRevenueType.merchantBoost: return 'Boost Marchand';
      case PlatformRevenueType.fixedCommission: return 'Commission Fixe';
    }
  }

  String getPspStatusLabel(PspTransactionStatus status) {
    switch (status) {
      case PspTransactionStatus.authorized: return 'Autorisé';
      case PspTransactionStatus.captured: return 'Prélevé';
      case PspTransactionStatus.rejected: return 'Rejeté';
      case PspTransactionStatus.pending: return 'En attente';
    }
  }

  String getAlertTypeLabel(FinancialAlertType type) {
    switch (type) {
      case FinancialAlertType.highFailureRate: return 'Taux d\'échec élevé';
      case FinancialAlertType.unconfirmedAfter48h: return 'Non confirmé >48h';
      case FinancialAlertType.paidButNotActivated: return 'Payé mais non activé';
      case FinancialAlertType.duplicatePsp: return 'Doublon PSP';
      case FinancialAlertType.abnormalTransactionPeak: return 'Pic anormal';
      case FinancialAlertType.inactiveButBilled: return 'Inactif mais facturé';
      case FinancialAlertType.promotionalWithoutEligibility: return 'Prime sans éligibilité';
    }
  }
}
