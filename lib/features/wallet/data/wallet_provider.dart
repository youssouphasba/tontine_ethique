import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tontetic/core/providers/auth_provider.dart';
import 'package:tontetic/core/services/wallet_service.dart';


// Modèle de transaction
class Transaction {
  final String id;
  final String title;
  final double amount;
  final DateTime date;
  final String type; // 'deposit', 'withdrawal', 'tontine_in', 'tontine_out'

  Transaction({
    required this.id,
    required this.title,
    required this.amount,
    required this.date,
    required this.type,
  });
}

// État du portefeuille
class WalletState {
  final double balance;
  final List<Transaction> transactions;

  WalletState({required this.balance, required this.transactions});

  WalletState copyWith({double? balance, List<Transaction>? transactions}) {
    return WalletState(
      balance: balance ?? this.balance,
      transactions: transactions ?? this.transactions,
    );
  }
}

// Notifier

// (Transaction and WalletState stay the same)

/// Service provider for WalletService
final walletServiceProvider = Provider<WalletService>((ref) => WalletService());

class WalletNotifier extends StateNotifier<WalletState> {
  final Ref ref;
  StreamSubscription? _walletSub;
  StreamSubscription? _txSub;

  WalletNotifier(this.ref) : super(WalletState(balance: 0, transactions: [])) {
    _initListeners();
  }

  void _initListeners() {
    final authState = ref.watch(authStateProvider);
    final walletService = ref.read(walletServiceProvider);

    authState.whenData((user) {
      if (user != null) {
        // Écouter le solde
        _walletSub?.cancel();
        _walletSub = walletService.getWalletData(user.uid).listen((data) {
          state = state.copyWith(balance: data['balance']);
        });

        // Écouter les transactions
        _txSub?.cancel();
        _txSub = walletService.getTransactions(user.uid).listen((txs) {
          state = state.copyWith(transactions: txs);
        });
      } else {
        _walletSub?.cancel();
        _txSub?.cancel();
        state = WalletState(balance: 0, transactions: []);
      }
    });
  }

  Future<void> deposit(double amount, String method) async {
    final user = ref.read(authStateProvider).value;
    if (user == null) return;

    await ref.read(walletServiceProvider).addTransaction(
      uid: user.uid,
      title: 'Dépôt $method',
      amount: amount,
      type: 'deposit',
      // tontineId: null for generic deposits
    );
  }

  Future<void> payAdCampaign(double amount, String campaignName) async {
    final user = ref.read(authStateProvider).value;
    if (user == null) return;

    await ref.read(walletServiceProvider).addTransaction(
      uid: user.uid,
      title: 'Campagne Pub: $campaignName',
      amount: -amount,
      type: 'ad_payment',
    );
  }

  Future<bool> lockFunds(double amount, String objective) async {
    final user = ref.read(authStateProvider).value;
    if (user == null) return false;

    if (state.balance < amount) return false;

    await ref.read(walletServiceProvider).addTransaction(
      uid: user.uid,
      title: 'Verrouillage: $objective',
      amount: -amount,
      type: 'fixed_savings',
    );
    return true;
  }

  @override
  void dispose() {
    _walletSub?.cancel();
    _txSub?.cancel();
    super.dispose();
  }
}

final walletProvider = StateNotifierProvider<WalletNotifier, WalletState>((ref) {
  return WalletNotifier(ref);
});

