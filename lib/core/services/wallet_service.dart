import 'package:cloud_firestore/cloud_firestore.dart' hide Transaction;

import 'package:tontetic/features/wallet/data/wallet_provider.dart';

/// Service pour gérer le portefeuille et les transactions dans Firestore
class WalletService {
  late final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Récupérer le solde et les transactions d'un utilisateur
  Stream<Map<String, dynamic>> getWalletData(String uid) {
    return _db.collection('users').doc(uid).snapshots().map((doc) {
      final data = doc.data();
      return {
        'balance': (data?['balance'] ?? 0).toDouble(),
      };
    });
  }

  /// Récupérer l'historique des transactions
  Stream<List<Transaction>> getTransactions(String uid) {
    return _db
        .collection('users')
        .doc(uid)
        .collection('transactions')
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => _mapDocToTransaction(doc))
            .toList());
  }

  /// Effectuer un dépôt (Simulé pour la démo, mais enregistré)
  Future<void> addTransaction({
    required String uid,
    required String title,
    required double amount,
    required String type,
  }) async {
    final batch = _db.batch();
    final userRef = _db.collection('users').doc(uid);
    final txRef = userRef.collection('transactions').doc();

    // 1. Enregistrer la transaction
    batch.set(txRef, {
      'id': txRef.id,
      'title': title,
      'amount': amount,
      'type': type,
      'date': FieldValue.serverTimestamp(),
    });

    // 2. Mettre à jour le solde (Incrément ou Décrément selon le type)
    // Pour simplifier, on passe le montant signé (+ pour dépôt, - pour retrait)
    batch.update(userRef, {
      'balance': FieldValue.increment(amount),
    });

    await batch.commit();
  }

  Transaction _mapDocToTransaction(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Transaction(
      id: doc.id,
      title: data['title'] ?? '',
      amount: (data['amount'] ?? 0).toDouble(),
      date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      type: data['type'] ?? 'deposit',
    );
  }
}
