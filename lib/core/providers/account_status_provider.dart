import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Account Status Provider
/// Manages the user's account activation level according to compliance rules
/// 
/// Flow:
/// 1. readOnly - Can browse, chat, create circles (no payments)
/// 2. pspPending - PSP connection initiated
/// 3. pspConnected - PSP verified, KYC done externally
/// 4. financialActive - Contract signed, payments enabled

enum AccountStatus {
  /// User registered on platform, no PSP connected
  /// Can: browse circles, chat, create circles without payments
  /// Cannot: join active tontines, use wallet, make payments
  readOnly,
  
  /// User initiated PSP connection, waiting for callback
  pspPending,
  
  /// PSP connected and KYC verified (externally)
  /// Can: view wallet balance (from PSP)
  /// Cannot: make payments until contract signed
  pspConnected,
  
  /// Contract signed, full financial access
  /// Can: all features including payments
  financialActive,
}

class AccountState {
  final AccountStatus status;
  final String? pspUserId;
  final String? pspProvider; // 'wave', 'stripe', 'om', 'paypal'
  final bool kycVerified;
  final DateTime? pspConnectedAt;
  final DateTime? financialActivatedAt;
  final List<String> signedContracts; // List of signed contract IDs

  AccountState({
    this.status = AccountStatus.readOnly,
    this.pspUserId,
    this.pspProvider,
    this.kycVerified = false,
    this.pspConnectedAt,
    this.financialActivatedAt,
    this.signedContracts = const [],
  });

  bool get canAccessWallet => status == AccountStatus.pspConnected || status == AccountStatus.financialActive;
  bool get canMakePayments => status == AccountStatus.financialActive;
  bool get canJoinActiveTontine => status == AccountStatus.financialActive;
  bool get needsPspConnection => status == AccountStatus.readOnly;

  AccountState copyWith({
    AccountStatus? status,
    String? pspUserId,
    String? pspProvider,
    bool? kycVerified,
    DateTime? pspConnectedAt,
    DateTime? financialActivatedAt,
    List<String>? signedContracts,
  }) {
    return AccountState(
      status: status ?? this.status,
      pspUserId: pspUserId ?? this.pspUserId,
      pspProvider: pspProvider ?? this.pspProvider,
      kycVerified: kycVerified ?? this.kycVerified,
      pspConnectedAt: pspConnectedAt ?? this.pspConnectedAt,
      financialActivatedAt: financialActivatedAt ?? this.financialActivatedAt,
      signedContracts: signedContracts ?? this.signedContracts,
    );
  }
}

class AccountNotifier extends StateNotifier<AccountState> {
  AccountNotifier() : super(AccountState());

  /// Called after PSP redirect callback
  void onPspConnected({
    required String pspUserId,
    required String pspProvider,
    required bool kycVerified,
  }) {
    if (kycVerified) {
      state = state.copyWith(
        status: AccountStatus.pspConnected,
        pspUserId: pspUserId,
        pspProvider: pspProvider,
        kycVerified: true,
        pspConnectedAt: DateTime.now(),
      );
      debugPrint('[Account] PSP connected: $pspProvider, User: $pspUserId');
    } else {
      // KYC failed at PSP level
      debugPrint('[Account] PSP KYC failed');
    }
  }

  /// Start PSP connection flow
  void initiatePspConnection(String provider) {
    state = state.copyWith(
      status: AccountStatus.pspPending,
      pspProvider: provider,
    );
    debugPrint('[Account] Initiating PSP connection: $provider');
  }

  /// Called after signing a tontine contract
  void onContractSigned(String contractId) {
    state = state.copyWith(
      status: AccountStatus.financialActive,
      financialActivatedAt: DateTime.now(),
      signedContracts: [...state.signedContracts, contractId],
    );
    debugPrint('[Account] Contract signed: $contractId, Financial mode activated');
  }

  /// Reset to read-only (e.g., PSP disconnected)
  void resetToReadOnly() {
    state = AccountState();
  }
}

final accountStatusProvider = StateNotifierProvider<AccountNotifier, AccountState>((ref) {
  return AccountNotifier();
});
