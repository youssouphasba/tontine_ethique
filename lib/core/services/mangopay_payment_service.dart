import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Service de paiement pour les tontines via Mangopay
///
/// Ce service orchestre le flux de paiement complet :
/// 1. PayIn (SEPA DD) : Prélèvement sur le compte bancaire du membre
/// 2. Transfer : Wallet membre → Wallet bénéficiaire
/// 3. PayOut (SEPA CT) : Wallet bénéficiaire → IBAN bénéficiaire
///
/// Tous les fonds transitent par Mangopay (EMI licencié).
/// Tontetic n'est qu'un orchestrateur technique.
class MangopayPaymentService {
  static const String _functionsBaseUrl =
      'https://europe-west1-tontetic-admin.cloudfunctions.net';

  /// Singleton
  static final MangopayPaymentService _instance = MangopayPaymentService._internal();
  factory MangopayPaymentService() => _instance;
  MangopayPaymentService._internal();

  // ============================================================
  // PAYIN - Prélèvement SEPA Direct Debit
  // ============================================================

  /// Crée un prélèvement SEPA sur le compte bancaire du membre
  /// Les fonds arrivent sur le wallet du membre
  ///
  /// Délais :
  /// - Premier prélèvement : J+5
  /// - Prélèvements récurrents : J+1
  Future<PaymentResult> createPayIn({
    required String odooUserId,
    required String mandateId,
    required String walletId,
    required int amountCents, // Montant en centimes
    required String currency,
    required String tontineId,
    required int cycleNumber,
  }) async {
    try {
      debugPrint('[Mangopay] Creating PayIn: $amountCents cents for tontine $tontineId');

      final response = await http.post(
        Uri.parse('$_functionsBaseUrl/mangopayCreatePayIn'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userId': odooUserId,
          'mandateId': mandateId,
          'creditedWalletId': walletId,
          'amount': amountCents,
          'currency': currency,
          'statementDescriptor': 'TONTETIC-$tontineId',
          'metadata': {
            'tontineId': tontineId,
            'cycleNumber': cycleNumber,
            'type': 'CONTRIBUTION',
          },
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        debugPrint('[Mangopay] ✅ PayIn created: ${data['payInId']} - Status: ${data['status']}');
        return PaymentResult.success(
          transactionId: data['payInId'],
          status: _parseStatus(data['status']),
          executionDate: data['executionDate'],
        );
      } else {
        final error = jsonDecode(response.body);
        debugPrint('[Mangopay] ❌ PayIn error: ${error['error']}');
        return PaymentResult.failure(error['error'] ?? 'Erreur prélèvement');
      }
    } catch (e) {
      debugPrint('[Mangopay] ❌ PayIn exception: $e');
      return PaymentResult.failure('Erreur de connexion: $e');
    }
  }

  // ============================================================
  // TRANSFER - Wallet vers Wallet
  // ============================================================

  /// Transfère des fonds d'un wallet vers un autre
  /// Utilisé pour consolider les contributions vers le bénéficiaire
  ///
  /// Délai : Instantané
  /// Coût : Gratuit
  Future<PaymentResult> createTransfer({
    required String debitedWalletId,
    required String creditedWalletId,
    required int amountCents,
    required String currency,
    required String tontineId,
    required int cycleNumber,
    required String contributorUserId,
    required String beneficiaryUserId,
  }) async {
    try {
      debugPrint('[Mangopay] Creating Transfer: $amountCents cents');

      final response = await http.post(
        Uri.parse('$_functionsBaseUrl/mangopayCreateTransfer'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'debitedWalletId': debitedWalletId,
          'creditedWalletId': creditedWalletId,
          'amount': amountCents,
          'currency': currency,
          'metadata': {
            'tontineId': tontineId,
            'cycleNumber': cycleNumber,
            'fromUserId': contributorUserId,
            'toUserId': beneficiaryUserId,
            'type': 'CONSOLIDATION',
          },
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        debugPrint('[Mangopay] ✅ Transfer created: ${data['transferId']}');
        return PaymentResult.success(
          transactionId: data['transferId'],
          status: _parseStatus(data['status']),
        );
      } else {
        final error = jsonDecode(response.body);
        return PaymentResult.failure(error['error'] ?? 'Erreur transfert');
      }
    } catch (e) {
      return PaymentResult.failure('Erreur: $e');
    }
  }

  // ============================================================
  // PAYOUT - Vers compte bancaire
  // ============================================================

  /// Effectue un payout vers le compte bancaire du bénéficiaire
  /// C'est l'étape finale : le bénéficiaire reçoit le pot sur son IBAN
  ///
  /// Délai : J+1 à J+2 (SEPA Credit Transfer)
  /// Coût : 0,10€
  Future<PaymentResult> createPayOut({
    required String mangopayUserId,
    required String walletId,
    required String bankAccountId,
    required int amountCents,
    required String currency,
    required String tontineId,
    required int cycleNumber,
  }) async {
    try {
      debugPrint('[Mangopay] Creating PayOut: $amountCents cents to bank account');

      final response = await http.post(
        Uri.parse('$_functionsBaseUrl/mangopayCreatePayOut'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'mangopayUserId': mangopayUserId,
          'debitedWalletId': walletId,
          'bankAccountId': bankAccountId,
          'amount': amountCents,
          'currency': currency,
          'bankWireRef': 'TONTETIC-POT-$tontineId-C$cycleNumber',
          'metadata': {
            'tontineId': tontineId,
            'cycleNumber': cycleNumber,
            'type': 'POT_PAYOUT',
          },
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        debugPrint('[Mangopay] ✅ PayOut created: ${data['payOutId']}');
        return PaymentResult.success(
          transactionId: data['payOutId'],
          status: _parseStatus(data['status']),
          executionDate: data['executionDate'],
        );
      } else {
        final error = jsonDecode(response.body);
        return PaymentResult.failure(error['error'] ?? 'Erreur payout');
      }
    } catch (e) {
      return PaymentResult.failure('Erreur: $e');
    }
  }

  // ============================================================
  // ORCHESTRATION TONTINE
  // ============================================================

  /// Exécute un cycle complet de tontine
  /// 1. Prélève tous les membres (PayIn)
  /// 2. Consolide vers le wallet du bénéficiaire (Transfers)
  /// 3. Payout vers l'IBAN du bénéficiaire (PayOut)
  ///
  /// Cette fonction est appelée par une Cloud Function programmée
  Future<TontineCycleResult> executeTontineCycle({
    required String tontineId,
    required int cycleNumber,
    required List<TontineContributor> contributors,
    required TontineBeneficiary beneficiary,
    required int contributionAmountCents,
    required String currency,
    required bool absorbFees, // true si abonné premium
  }) async {
    try {
      debugPrint('[Mangopay] Executing tontine cycle $cycleNumber for $tontineId');

      final response = await http.post(
        Uri.parse('$_functionsBaseUrl/mangopayExecuteTontineCycle'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'tontineId': tontineId,
          'cycleNumber': cycleNumber,
          'contributors': contributors.map((c) => c.toJson()).toList(),
          'beneficiary': beneficiary.toJson(),
          'contributionAmount': contributionAmountCents,
          'currency': currency,
          'absorbFees': absorbFees,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        debugPrint('[Mangopay] ✅ Cycle initiated: ${data['cycleId']}');
        return TontineCycleResult(
          success: true,
          cycleId: data['cycleId'],
          payInsCreated: data['payInsCreated'] ?? 0,
          totalAmount: data['totalAmount'] ?? 0,
          estimatedPayoutDate: data['estimatedPayoutDate'],
        );
      } else {
        final error = jsonDecode(response.body);
        return TontineCycleResult(
          success: false,
          error: error['error'] ?? 'Erreur cycle',
        );
      }
    } catch (e) {
      return TontineCycleResult(success: false, error: 'Erreur: $e');
    }
  }

  /// Récupère le statut d'un cycle de tontine
  Future<TontineCycleStatus?> getCycleStatus({
    required String tontineId,
    required int cycleNumber,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$_functionsBaseUrl/mangopayGetCycleStatus?tontineId=$tontineId&cycle=$cycleNumber'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return TontineCycleStatus.fromJson(data);
      }
    } catch (e) {
      debugPrint('[Mangopay] Error getting cycle status: $e');
    }
    return null;
  }

  PaymentStatus _parseStatus(String? status) {
    switch (status?.toUpperCase()) {
      case 'SUCCEEDED':
        return PaymentStatus.succeeded;
      case 'CREATED':
        return PaymentStatus.pending;
      case 'FAILED':
        return PaymentStatus.failed;
      default:
        return PaymentStatus.pending;
    }
  }
}

// ============================================================
// MODELS
// ============================================================

enum PaymentStatus { pending, succeeded, failed }

class PaymentResult {
  final bool isSuccess;
  final String? transactionId;
  final PaymentStatus? status;
  final String? executionDate;
  final String? error;

  PaymentResult._({
    required this.isSuccess,
    this.transactionId,
    this.status,
    this.executionDate,
    this.error,
  });

  factory PaymentResult.success({
    required String transactionId,
    required PaymentStatus status,
    String? executionDate,
  }) =>
      PaymentResult._(
        isSuccess: true,
        transactionId: transactionId,
        status: status,
        executionDate: executionDate,
      );

  factory PaymentResult.failure(String error) =>
      PaymentResult._(isSuccess: false, error: error);
}

class TontineContributor {
  final String odooUserId;
  final String mangopayUserId;
  final String walletId;
  final String mandateId;

  TontineContributor({
    required this.odooUserId,
    required this.mangopayUserId,
    required this.walletId,
    required this.mandateId,
  });

  Map<String, dynamic> toJson() => {
        'userId': odooUserId,
        'mangopayUserId': mangopayUserId,
        'walletId': walletId,
        'mandateId': mandateId,
      };
}

class TontineBeneficiary {
  final String odooUserId;
  final String mangopayUserId;
  final String walletId;
  final String bankAccountId;

  TontineBeneficiary({
    required this.odooUserId,
    required this.mangopayUserId,
    required this.walletId,
    required this.bankAccountId,
  });

  Map<String, dynamic> toJson() => {
        'userId': odooUserId,
        'mangopayUserId': mangopayUserId,
        'walletId': walletId,
        'bankAccountId': bankAccountId,
      };
}

class TontineCycleResult {
  final bool success;
  final String? cycleId;
  final int payInsCreated;
  final int totalAmount;
  final String? estimatedPayoutDate;
  final String? error;

  TontineCycleResult({
    required this.success,
    this.cycleId,
    this.payInsCreated = 0,
    this.totalAmount = 0,
    this.estimatedPayoutDate,
    this.error,
  });
}

class TontineCycleStatus {
  final String tontineId;
  final int cycleNumber;
  final String status; // COLLECTING, CONSOLIDATING, PAYING_OUT, COMPLETED, FAILED
  final int payInsCompleted;
  final int payInsTotal;
  final int transfersCompleted;
  final bool payOutCompleted;
  final String? payOutId;
  final String? estimatedCompletionDate;

  TontineCycleStatus({
    required this.tontineId,
    required this.cycleNumber,
    required this.status,
    required this.payInsCompleted,
    required this.payInsTotal,
    required this.transfersCompleted,
    required this.payOutCompleted,
    this.payOutId,
    this.estimatedCompletionDate,
  });

  double get progress {
    if (status == 'COMPLETED') return 1.0;
    final total = payInsTotal + payInsTotal + 1; // payins + transfers + payout
    final completed = payInsCompleted + transfersCompleted + (payOutCompleted ? 1 : 0);
    return completed / total;
  }

  factory TontineCycleStatus.fromJson(Map<String, dynamic> json) => TontineCycleStatus(
        tontineId: json['tontineId'],
        cycleNumber: json['cycleNumber'],
        status: json['status'],
        payInsCompleted: json['payInsCompleted'] ?? 0,
        payInsTotal: json['payInsTotal'] ?? 0,
        transfersCompleted: json['transfersCompleted'] ?? 0,
        payOutCompleted: json['payOutCompleted'] ?? false,
        payOutId: json['payOutId'],
        estimatedCompletionDate: json['estimatedCompletionDate'],
      );
}
