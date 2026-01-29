import 'dart:developer' as dev;

class AuditEntry {
  final String circleId;
  final double grossCollected;
  final double pspFees;
  final double tonteticFraisFixes; // Frais techniques Tontetic
  final double netToWinner;
  final double guaranteeFundContribution;
  final DateTime timestamp;

  AuditEntry({
    required this.circleId,
    required this.grossCollected,
    required this.pspFees,
    required this.tonteticFraisFixes,
    required this.netToWinner,
    required this.guaranteeFundContribution,
    required this.timestamp,
  });

  @override
  String toString() {
    return '[AUDIT] ${timestamp.toIso8601String()} | Circle: $circleId | Gross: $grossCollected | Fees: $pspFees | Net: $netToWinner | Amanah: $guaranteeFundContribution';
  }
}

class AuditLogService {
  static final List<AuditEntry> _history = [];

  static void logCycle({
    required String circleId,
    required double gross,
    double pspFeePercent = 0.02, // Simuler 2% de frais PSP
    double tonteticFixedFee = 500, // 500 F ou ~1€ par participant (simulé sur le total)
  }) {
    final pspFees = gross * pspFeePercent;
    final guarantee = gross * 1.0; // Amanah 100% (1 cotisation)
    final fraisFixes = tonteticFixedFee; // Somme perçue par l'éditeur
    final net = gross - pspFees - guarantee - fraisFixes;

    final entry = AuditEntry(
      circleId: circleId,
      grossCollected: gross,
      pspFees: pspFees,
      tonteticFraisFixes: fraisFixes,
      netToWinner: net,
      guaranteeFundContribution: guarantee,
      timestamp: DateTime.now(),
    );

    _history.add(entry);
    dev.log(entry.toString());
  }

  static List<AuditEntry> get history => List.unmodifiable(_history);
  
  static double getTotalGuarantee() => _history.fold(0, (sum, e) => sum + e.guaranteeFundContribution);
  static double getTotalFixedFees() => _history.fold(0, (sum, e) => sum + e.tonteticFraisFixes);

  static void logAmanahWithdrawal(String circleId, double amount) {
    dev.log('🔴 [AMANAH] Prélèvement exceptionnel de $amount F pour le cercle $circleId');
    // On pourrait ajouter une entrée spécifique dans l'historique avec montant négatif
    _history.add(AuditEntry(
      circleId: circleId,
      grossCollected: 0,
      pspFees: 0,
      tonteticFraisFixes: 0,
      netToWinner: 0, // Ce n'est pas un gain pour le gagnant (c'est une couverture)
      guaranteeFundContribution: -amount,
      timestamp: DateTime.now(),
    ));
  }
}
