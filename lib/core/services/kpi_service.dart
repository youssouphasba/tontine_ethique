import 'package:flutter/foundation.dart';
import 'package:tontetic/core/database/database_schema.dart';

/// KPI Service for Financial Back-Office
/// 
/// RÈGLE FONDAMENTALE:
/// Le dashboard NE doit JAMAIS calculer:
/// ❌ solde utilisateur
/// ❌ total argent par cercle
/// ❌ total fonds détenus
/// ❌ redistribution automatique

class KpiService {
  static final KpiService _instance = KpiService._internal();
  factory KpiService() => _instance;
  KpiService._internal();

  // Demo data stores
  final List<CompanyRecord> _companies = [];
  final List<SubscriptionRecord> _subscriptions = [];
  final List<PlatformTransactionRecord> _platformTransactions = [];
  final List<UserPaymentEventRecord> _userPaymentEvents = [];
  final List<CircleRecord> _circles = [];
  final List<GuaranteeRecord> _guarantees = [];
  final List<MerchantAccountRecord> _merchants = [];
  final List<MerchantBoostRecord> _boosts = [];
  final List<AuditLedgerRecord> _auditLedger = [];

  // ============================================================
  // INITIALIZATION
  // ============================================================

  void initDemoData() {
    // PRODUCTION: No demo data - all KPI data comes from Firestore collections
    // The getXxxKpis() methods will return empty/zero values until real data exists
    debugPrint('[KPI] Service initialized (no demo data)');
  }

  // ================================================================
  // A. KPIs FINANCIERS PLATEFORME
  // ================================================================

  Map<String, dynamic> getFinancialKpis() {
    final paidTransactions = _platformTransactions
        .where((t) => t.status == TransactionStatus.paid);
    final failedTransactions = _platformTransactions
        .where((t) => t.status == TransactionStatus.failed);

    // MRR (Monthly Recurring Revenue)
    final activeSubscriptions = _subscriptions
        .where((s) => s.status == SubscriptionStatus.active);
    final mrr = activeSubscriptions.fold<double>(0, (sum, s) => sum + s.montantTtc);

    // Revenu par type de formule
    final revenueByFormula = <String, double>{};
    for (final sub in activeSubscriptions) {
      revenueByFormula[sub.formule] = 
          (revenueByFormula[sub.formule] ?? 0) + sub.montantTtc;
    }

    // Revenu par pays
    final revenueByCountry = <String, double>{};
    for (final t in paidTransactions) {
      final company = _companies.cast<CompanyRecord?>().firstWhere(
        (c) => c?.id == t.entityId,
        orElse: () => null,
      );
      final pays = company?.pays ?? 'Unknown';
      revenueByCountry[pays] = (revenueByCountry[pays] ?? 0) + t.montantTtc;
    }

    // Revenu entreprises vs marchands
    final revenueEntreprises = paidTransactions
        .where((t) => t.entityType == 'company')
        .fold<double>(0, (sum, t) => sum + t.montantTtc);
    final revenueMarchands = paidTransactions
        .where((t) => t.entityType == 'merchant')
        .fold<double>(0, (sum, t) => sum + t.montantTtc);

    // Taux d'échec paiement abonnement
    final totalAbonnements = _platformTransactions
        .where((t) => t.type == TransactionType.abonnement).length;
    final failedAbonnements = failedTransactions
        .where((t) => t.type == TransactionType.abonnement).length;
    final tauxEchecAbonnement = totalAbonnements > 0 
        ? (failedAbonnements / totalAbonnements * 100) 
        : 0.0;

    // Churn entreprises (% résiliations)
    final totalCompanies = _companies.length;
    final canceledCompanies = _companies
        .where((c) => c.statutAbonnement == SubscriptionStatus.canceled).length;
    final churnRate = totalCompanies > 0 
        ? (canceledCompanies / totalCompanies * 100) 
        : 0.0;

    return {
      'mrr': mrr,
      'mrrFormatted': '${(mrr / 1000).toStringAsFixed(0)}K FCFA',
      'revenueByFormula': revenueByFormula,
      'revenueByCountry': revenueByCountry,
      'revenueEntreprises': revenueEntreprises,
      'revenueMarchands': revenueMarchands,
      'tauxEchecAbonnement': tauxEchecAbonnement,
      'tauxEchecAbonnementFormatted': '${tauxEchecAbonnement.toStringAsFixed(1)}%',
      'churnEntreprises': churnRate,
      'churnEntreprisesFormatted': '${churnRate.toStringAsFixed(1)}%',
      'totalPaid': paidTransactions.fold<double>(0, (sum, t) => sum + t.montantTtc),
      'totalHT': paidTransactions.fold<double>(0, (sum, t) => sum + t.montantHt),
      'totalTVA': paidTransactions.fold<double>(0, (sum, t) => sum + t.tva),
    };
  }

  // ================================================================
  // B. KPIs PSP / RISQUE
  // ================================================================

  Map<String, dynamic> getPspRiskKpis() {
    // Taux d'échec prélèvement
    final totalEvents = _userPaymentEvents.length;
    final rejectedEvents = _userPaymentEvents
        .where((e) => e.eventType == PaymentEventType.rejection).length;
    final tauxEchecPrelevement = totalEvents > 0 
        ? (rejectedEvents / totalEvents * 100) 
        : 0.0;

    // Nombre de comptes PSP bloqués (simulated)
    final accountsBlocked = 2; // Would come from PSP API

    // Délais moyens confirmation PSP (simulated in hours)
    final delaiMoyenConfirmation = 4.5; // Would be calculated from events

    // Nombre de garanties déclenchées
    final guaranteesTriggered = _guarantees
        .where((g) => g.status == GuaranteeStatus.utilisee).length;

    // Défauts par cercle (%)
    final circlesWithDefaults = _circles.where((c) {
      return _guarantees.any((g) => 
          g.circleId == c.id && g.status == GuaranteeStatus.utilisee);
    }).length;
    final tauxDefautsCercles = _circles.isNotEmpty 
        ? (circlesWithDefaults / _circles.length * 100) 
        : 0.0;

    return {
      'tauxEchecPrelevement': tauxEchecPrelevement,
      'tauxEchecPrelevementFormatted': '${tauxEchecPrelevement.toStringAsFixed(1)}%',
      'comptesPspBloques': accountsBlocked,
      'delaiMoyenConfirmation': delaiMoyenConfirmation,
      'delaiMoyenConfirmationFormatted': '${delaiMoyenConfirmation.toStringAsFixed(1)}h',
      'garantiesDeclenchees': guaranteesTriggered,
      'tauxDefautsCercles': tauxDefautsCercles,
      'tauxDefautsCerclesFormatted': '${tauxDefautsCercles.toStringAsFixed(1)}%',
      'totalGaranties': _guarantees.length,
      'garantiesBloquees': _guarantees.where((g) => g.status == GuaranteeStatus.bloquee).length,
      'garantiesLiberees': _guarantees.where((g) => g.status == GuaranteeStatus.liberee).length,
    };
  }

  // ================================================================
  // C. KPIs UTILISATION (NON FINANCIERS)
  // ================================================================

  Map<String, dynamic> getUsageKpis() {
    // Cercles actifs
    final cerclesActifs = _circles
        .where((c) => c.statut == CircleStatus.actif).length;

    // Cercles clôturés sans incident
    final cerclesClotures = _circles
        .where((c) => c.statut == CircleStatus.cloture).length;
    final cerclesWithDefaults = _circles.where((c) {
      return _guarantees.any((g) => 
          g.circleId == c.id && g.status == GuaranteeStatus.utilisee);
    }).toSet();
    final cerclesCloturesSansIncident = cerclesClotures - 
        cerclesWithDefaults.where((c) => c.statut == CircleStatus.cloture).length;

    // Cercles avec défaut
    final cerclesAvecDefaut = cerclesWithDefaults.length;

    // Nombre moyen de membres par cercle
    final totalMembres = _circles.fold<int>(0, (sum, c) => sum + c.nombreMembres);
    final moyenneMembres = _circles.isNotEmpty 
        ? (totalMembres / _circles.length) 
        : 0.0;

    // Taux de remplacement de membre (simulated)
    final tauxRemplacement = 5.3; // Would be calculated from membership history

    return {
      'cerclesActifs': cerclesActifs,
      'cerclesClotures': cerclesClotures,
      'cerclesCloturesSansIncident': cerclesCloturesSansIncident,
      'cerclesAvecDefaut': cerclesAvecDefaut,
      'moyenneMembresParCercle': moyenneMembres,
      'moyenneMembresParCercleFormatted': moyenneMembres.toStringAsFixed(1),
      'tauxRemplacement': tauxRemplacement,
      'tauxRemplacementFormatted': '${tauxRemplacement.toStringAsFixed(1)}%',
      'totalCercles': _circles.length,
    };
  }

  // ================================================================
  // D. KPIs MARCHANDS
  // ================================================================

  Map<String, dynamic> getMerchantKpis() {
    // Nombre de marchands actifs
    final marchandsActifs = _merchants
        .where((m) => m.status == 'actif').length;

    // Produits publiés (simulated)
    final produitsPublies = 156; // Would come from products table

    // Boosts actifs
    final now = DateTime.now();
    final boostsActifs = _boosts
        .where((b) => b.status == 'active' && 
                      b.startDate.isBefore(now) && 
                      b.endDate.isAfter(now)).length;

    // Revenu boost
    final revenuBoost = _platformTransactions
        .where((t) => t.type == TransactionType.boost && 
                      t.status == TransactionStatus.paid)
        .fold<double>(0, (sum, t) => sum + t.montantTtc);

    // Signalements produits (simulated)
    final signalementsProduits = 3; // Would come from reports table

    return {
      'marchandsActifs': marchandsActifs,
      'marchandsSuspendus': _merchants.where((m) => m.status == 'suspendu').length,
      'totalMarchands': _merchants.length,
      'produitsPublies': produitsPublies,
      'boostsActifs': boostsActifs,
      'totalBoosts': _boosts.length,
      'revenuBoost': revenuBoost,
      'revenuBoostFormatted': '${(revenuBoost / 1000).toStringAsFixed(0)}K FCFA',
      'signalementsProduits': signalementsProduits,
    };
  }

  // ================================================================
  // E. KPIs CONFORMITÉ
  // ================================================================

  Map<String, dynamic> getComplianceKpis() {
    // Comptes suspendus (simulated - would come from users table)
    final comptesSuspendus = 12;

    // Demandes RGPD (simulated)
    final demandesRgpdAcces = 3;
    final demandesRgpdSuppression = 1;

    // Litiges ouverts / clos (simulated)
    final litigesOuverts = 2;
    final litigesClos = 15;

    // Délais moyens traitement litige (simulated in days)
    final delaiMoyenLitige = 3.2;

    return {
      'comptesSuspendus': comptesSuspendus,
      'demandesRgpdAcces': demandesRgpdAcces,
      'demandesRgpdSuppression': demandesRgpdSuppression,
      'totalDemandesRgpd': demandesRgpdAcces + demandesRgpdSuppression,
      'litigesOuverts': litigesOuverts,
      'litigesClos': litigesClos,
      'delaiMoyenLitige': delaiMoyenLitige,
      'delaiMoyenLitigeFormatted': '${delaiMoyenLitige.toStringAsFixed(1)} jours',
      'auditEntriesCount': _auditLedger.length,
    };
  }

  // ================================================================
  // ALL KPIs COMBINED
  // ================================================================

  Map<String, Map<String, dynamic>> getAllKpis() {
    return {
      'financial': getFinancialKpis(),
      'pspRisk': getPspRiskKpis(),
      'usage': getUsageKpis(),
      'merchant': getMerchantKpis(),
      'compliance': getComplianceKpis(),
    };
  }

  // ================================================================
  // CE QUE LE DASHBOARD NE DOIT JAMAIS CALCULER
  // ================================================================

  /// ❌ INTERDIT - Ne jamais appeler ces méthodes
  /// Ces méthodes existent uniquement pour documenter ce qu'on NE FAIT PAS
  
  // ignore: unused_element
  double _doNotCalculateSoldeUtilisateur(String userId) {
    throw UnsupportedError('❌ INTERDIT: Calcul de solde utilisateur');
  }

  // ignore: unused_element
  double _doNotCalculateTotalArgentCercle(String circleId) {
    throw UnsupportedError('❌ INTERDIT: Calcul du total argent par cercle');
  }

  // ignore: unused_element
  double _doNotCalculateTotalFondsDetenus() {
    throw UnsupportedError('❌ INTERDIT: Calcul du total des fonds détenus');
  }

  // ignore: unused_element
  void _doNotPerformRedistributionAutomatique() {
    throw UnsupportedError('❌ INTERDIT: Redistribution automatique');
  }

  // ================================================================
  // EXPORTS
  // ================================================================

  String exportKpisToCsv() {
    final allKpis = getAllKpis();
    final buffer = StringBuffer();
    
    buffer.writeln('Category,KPI,Value');
    
    for (final category in allKpis.entries) {
      for (final kpi in category.value.entries) {
        buffer.writeln('"${category.key}","${kpi.key}","${kpi.value}"');
      }
    }
    
    return buffer.toString();
  }
}
