import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// V14: Admin State Management - PRODUCTION VERSION
/// All stats are fetched from Firestore - no hardcoded data

class AdminStats {
  final int totalUsers;
  final int totalCircles;
  final int activeCircles;
  final double totalTransactionVolume;
  final int pendingModerations;
  final int resolvedDisputes;
  final List<Map<String, dynamic>> recentActions;

  AdminStats({
    this.totalUsers = 0,
    this.totalCircles = 0,
    this.activeCircles = 0,
    this.totalTransactionVolume = 0,
    this.pendingModerations = 0,
    this.resolvedDisputes = 0,
    this.recentActions = const [],
  });

  AdminStats copyWith({
    int? totalUsers,
    int? totalCircles,
    int? activeCircles,
    double? totalTransactionVolume,
    int? pendingModerations,
    int? resolvedDisputes,
    List<Map<String, dynamic>>? recentActions,
  }) {
    return AdminStats(
      totalUsers: totalUsers ?? this.totalUsers,
      totalCircles: totalCircles ?? this.totalCircles,
      activeCircles: activeCircles ?? this.activeCircles,
      totalTransactionVolume: totalTransactionVolume ?? this.totalTransactionVolume,
      pendingModerations: pendingModerations ?? this.pendingModerations,
      resolvedDisputes: resolvedDisputes ?? this.resolvedDisputes,
      recentActions: recentActions ?? this.recentActions,
    );
  }
}

/// Fetches admin stats from REAL Firestore data
class AdminStatsNotifier extends StateNotifier<AsyncValue<AdminStats>> {
  final FirebaseFirestore _firestore;

  AdminStatsNotifier(this._firestore) : super(const AsyncValue.loading()) {
    _loadStats();
  }

  Future<void> _loadStats() async {
    try {
      // Fetch real counts from Firestore
      final usersCount = await _firestore.collection('users').count().get();
      final tontinesCount = await _firestore.collection('tontines').count().get();
      final activeTontinesCount = await _firestore
          .collection('tontines')
          .where('status', isEqualTo: 'active')
          .count()
          .get();
      final pendingTickets = await _firestore
          .collection('support_tickets')
          .where('status', whereIn: ['open', 'pendingAdmin'])
          .count()
          .get();
      final resolvedTickets = await _firestore
          .collection('support_tickets')
          .where('status', isEqualTo: 'resolved')
          .count()
          .get();

      // Fetch recent admin actions
      final actionsSnapshot = await _firestore
          .collection('audit_logs')
          .orderBy('timestamp', descending: true)
          .limit(10)
          .get();
      
      final recentActions = actionsSnapshot.docs
          .map((doc) => {'id': doc.id, ...doc.data()})
          .toList();

      state = AsyncValue.data(AdminStats(
        totalUsers: usersCount.count ?? 0,
        totalCircles: tontinesCount.count ?? 0,
        activeCircles: activeTontinesCount.count ?? 0,
        totalTransactionVolume: 0, // Requires Cloud Function aggregation
        pendingModerations: pendingTickets.count ?? 0,
        resolvedDisputes: resolvedTickets.count ?? 0,
        recentActions: recentActions,
      ));
    } catch (e) {
      debugPrint('[AdminStats] Error loading stats: $e');
      state = AsyncValue.error(e, StackTrace.current);
    }
  }

  /// Refresh stats from Firestore
  Future<void> refresh() async {
    state = const AsyncValue.loading();
    await _loadStats();
  }

  /// Log admin action to Firestore
  Future<void> logAction(String type, String targetId, String details, String adminUid) async {
    try {
      await _firestore.collection('audit_logs').add({
        'type': type,
        'targetId': targetId,
        'details': details,
        'performedBy': adminUid,
        'timestamp': FieldValue.serverTimestamp(),
      });
      // Refresh stats after logging
      await refresh();
    } catch (e) {
      debugPrint('[AdminStats] Error logging action: $e');
    }
  }
}

/// Provider for admin stats - REAL Firestore data
final adminStatsNotifierProvider = StateNotifierProvider<AdminStatsNotifier, AsyncValue<AdminStats>>((ref) {
  return AdminStatsNotifier(FirebaseFirestore.instance);
});

/// Legacy provider alias for backwards compatibility
final adminProvider = adminStatsNotifierProvider;
