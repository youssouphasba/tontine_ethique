import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AdminDashboardStats {
  final int totalUsers;
  final int activeTontines;
  final int pendingTickets;
  final double totalVolumeCents; // Mocked or Aggregated

  AdminDashboardStats({
    required this.totalUsers,
    required this.activeTontines,
    required this.pendingTickets,
    this.totalVolumeCents = 0,
  });
}

class AdminService {
  final FirebaseFirestore _firestore;

  AdminService(this._firestore);

  /// Récupère les stats globales (Utilise Count Aggregations pour la performance)
  Future<AdminDashboardStats> getStats() async {
    try {
      final usersCount = await _firestore.collection('users').count().get();
      final tontinesCount = await _firestore.collection('tontines').count().get();
      // On suppose une collection 'support_tickets'
      final ticketsCount = await _firestore.collection('support_tickets')
          .where('status', isEqualTo: 'open')
          .count()
          .get();

      return AdminDashboardStats(
        totalUsers: usersCount.count ?? 0,
        activeTontines: tontinesCount.count ?? 0,
        pendingTickets: ticketsCount.count ?? 0,
        totalVolumeCents: 0, // Placeholder: Nécessite Cloud Function 'aggregateStats' pour calculer le volume réel
      );
    } catch (e) {
      debugPrint('Admin Stats Error: $e');
      return AdminDashboardStats(totalUsers: 0, activeTontines: 0, pendingTickets: 0);
    }
  }

  /// Récupère les derniers messages de support
  Stream<List<Map<String, dynamic>>> getSupportMessages() {
    return _firestore.collection('support_tickets')
        .orderBy('createdAt', descending: true)
        .limit(20)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => {
              'id': doc.id,
              ...doc.data(),
            }).toList());
  }

  /// Récupère la liste des Plans (Abonnements)
  Stream<List<Map<String, dynamic>>> getPlans() {
    return _firestore.collection('plans')
        .orderBy('priceCents') // Tri par prix
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => {
              'id': doc.id,
              ...doc.data(),
            }).toList());
  }

  /// Met à jour la configuration d'un Plan (Prix, Limites...)
  Future<void> updatePlan(String planId, Map<String, dynamic> data) async {
    await _firestore.collection('plans').doc(planId).update(data);
    await _logAction('UPDATE_PLAN', 'Plan $planId updated', data);
  }

  /// Logs administrative actions for audit
  Future<void> _logAction(String action, String details, Map<String, dynamic> metadata) async {
    // Get real admin UID from Firebase Auth
    final adminUid = FirebaseAuth.instance.currentUser?.uid ?? 'unknown_admin';
    
    await _firestore.collection('audit_logs').add({
      'action': action,
      'details': details,
      'metadata': metadata,
      'timestamp': FieldValue.serverTimestamp(),
      'performedBy': adminUid,
    });
  }

  /// Envoie une newsletter globale (Via collection 'broadcasts' écoutée par les clients ou Cloud Function)
  Future<void> sendGlobalNewsletter(String title, String body) async {
    await _firestore.collection('broadcasts').add({
      'title': title,
      'body': body,
      'createdAt': FieldValue.serverTimestamp(),
      'target': 'all',
      'sentBy': 'admin_dashboard'
    });
  }

  /// List Users (Real Time)
  Stream<List<Map<String, dynamic>>> getUsers() {
    return _firestore.collection('users')
      // .orderBy('createdAt', descending: true) // Ensure indexes exist
      .limit(50)
      .snapshots()
      .map((s) => s.docs.map((d) => {'id': d.id, ...d.data()}).toList());
  }

  /// List Audit Logs
  Stream<List<Map<String, dynamic>>> getAuditLogs() {
    return _firestore.collection('audit_logs')
      .orderBy('timestamp', descending: true)
      .limit(50)
      .snapshots()
      .map((s) => s.docs.map((d) => {'id': d.id, ...d.data()}).toList());
  }
  
  /// List Transactions
  Stream<List<Map<String, dynamic>>> getTransactions() {
    return _firestore.collection('transactions')
      //.orderBy('createdAt', descending: true)
      .limit(20)
      .snapshots()
      .map((s) => s.docs.map((d) => {'id': d.id, ...d.data()}).toList());
  }


}

final adminServiceProvider = Provider<AdminService>((ref) {
  return AdminService(FirebaseFirestore.instance);
});

final adminStatsProvider = FutureProvider<AdminDashboardStats>((ref) async {
  return ref.watch(adminServiceProvider).getStats();
});

final supportMessagesProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  return ref.watch(adminServiceProvider).getSupportMessages();
});

final adminUsersProvider = StreamProvider((ref) => ref.watch(adminServiceProvider).getUsers());
final adminAuditLogsProvider = StreamProvider((ref) => ref.watch(adminServiceProvider).getAuditLogs());
final adminTransactionsProvider = StreamProvider((ref) => ref.watch(adminServiceProvider).getTransactions());
