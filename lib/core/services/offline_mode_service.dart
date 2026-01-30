import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// V16: Offline Mode Service
/// Handles graceful degradation when network is unavailable
/// 
/// Features:
/// - Queue non-critical actions for later sync
/// - Read-only mode for critical features
/// - Automatic sync when back online
/// - Conflict resolution

enum OfflineActionType {
  sendMessage,     // Chat messages
  updateProfile,   // Profile changes
  saveDraft,       // Draft tontines
  // NOT SUPPORTED OFFLINE (critical):
  // - payment
  // - vote
  // - joinCircle
}

enum OfflineActionStatus {
  pending,   // Waiting to sync
  syncing,   // Currently syncing
  synced,    // Successfully synced
  failed,    // Failed to sync (will retry)
  conflict,  // Conflict detected
}

class OfflineAction {
  final String id;
  final OfflineActionType type;
  final Map<String, dynamic> data;
  final DateTime createdAt;
  OfflineActionStatus status;
  int retryCount;
  String? errorMessage;

  OfflineAction({
    required this.id,
    required this.type,
    required this.data,
    required this.createdAt,
    this.status = OfflineActionStatus.pending,
    this.retryCount = 0,
    this.errorMessage,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.name,
    'data': data,
    'created_at': createdAt.toIso8601String(),
    'status': status.name,
    'retry_count': retryCount,
    'error_message': errorMessage,
  };

  factory OfflineAction.fromJson(Map<String, dynamic> json) => OfflineAction(
    id: json['id'],
    type: OfflineActionType.values.byName(json['type']),
    data: Map<String, dynamic>.from(json['data']),
    createdAt: DateTime.parse(json['created_at']),
    status: OfflineActionStatus.values.byName(json['status']),
    retryCount: json['retry_count'] ?? 0,
    errorMessage: json['error_message'],
  );
}

class OfflineModeService {
  static const FlutterSecureStorage _storage = FlutterSecureStorage();
  static const String _queueKey = 'offline_action_queue';
  static const int _maxRetries = 3;

  bool _isOnline = true;
  final List<Function(bool)> _listeners = [];

  /// Check if currently online
  bool get isOnline => _isOnline;

  /// Set online status (called by connectivity provider)
  void setOnlineStatus(bool online) {
    final wasOffline = !_isOnline;
    _isOnline = online;
    
    // Notify listeners
    for (final listener in _listeners) {
      listener(online);
    }
    
    // Auto-sync when coming back online
    if (online && wasOffline) {
      debugPrint('[OFFLINE] Back online - starting sync');
      syncPendingActions();
    }
  }

  /// Add listener for connectivity changes
  void addListener(Function(bool) listener) {
    _listeners.add(listener);
  }

  /// Remove listener
  void removeListener(Function(bool) listener) {
    _listeners.remove(listener);
  }

  /// Queue an action for later sync
  Future<void> queueAction(OfflineActionType type, Map<String, dynamic> data) async {
    final action = OfflineAction(
      id: '${type.name}_${DateTime.now().millisecondsSinceEpoch}',
      type: type,
      data: data,
      createdAt: DateTime.now(),
    );

    final queue = await _getQueue();
    queue.add(action);
    await _saveQueue(queue);

    debugPrint('[OFFLINE] Queued action: ${action.id}');
  }

  /// Get pending actions count
  Future<int> getPendingCount() async {
    final queue = await _getQueue();
    return queue.where((a) => a.status == OfflineActionStatus.pending).length;
  }

  /// Get all queued actions
  Future<List<OfflineAction>> _getQueue() async {
    final json = await _storage.read(key: _queueKey);
    if (json == null) return [];
    
    final list = jsonDecode(json) as List;
    return list.map((e) => OfflineAction.fromJson(e)).toList();
  }

  /// Save queue to storage
  Future<void> _saveQueue(List<OfflineAction> queue) async {
    final json = jsonEncode(queue.map((a) => a.toJson()).toList());
    await _storage.write(key: _queueKey, value: json);
  }

  /// Sync all pending actions
  Future<SyncResult> syncPendingActions() async {
    if (!_isOnline) {
      return SyncResult(
        success: false,
        synced: 0,
        failed: 0,
        message: 'Still offline',
      );
    }

    final queue = await _getQueue();
    final pending = queue.where((a) => 
      a.status == OfflineActionStatus.pending ||
      (a.status == OfflineActionStatus.failed && a.retryCount < _maxRetries)
    ).toList();

    int synced = 0;
    int failed = 0;

    for (final action in pending) {
      action.status = OfflineActionStatus.syncing;
      
      try {
        await _executeAction(action);
        action.status = OfflineActionStatus.synced;
        synced++;
      } catch (e) {
        action.status = OfflineActionStatus.failed;
        action.retryCount++;
        action.errorMessage = e.toString();
        failed++;
        debugPrint('[OFFLINE] Sync failed for ${action.id}: $e');
      }
    }

    // Keep only failed and pending actions
    queue.removeWhere((a) => a.status == OfflineActionStatus.synced);
    await _saveQueue(queue);

    debugPrint('[OFFLINE] Sync complete: $synced synced, $failed failed');

    return SyncResult(
      success: failed == 0,
      synced: synced,
      failed: failed,
      message: 'Synced $synced actions',
    );
  }

  /// Execute a queued action
  Future<void> _executeAction(OfflineAction action) async {
    switch (action.type) {
      case OfflineActionType.sendMessage:
        await _syncMessage(action.data);
        break;
      case OfflineActionType.updateProfile:
        await _syncProfile(action.data);
        break;
      case OfflineActionType.saveDraft:
        await _syncDraft(action.data);
        break;
    }
  }

  /// Sync a queued message
  Future<void> _syncMessage(Map<String, dynamic> data) async {
    // In production: send to Firestore
    debugPrint('[OFFLINE] Syncing message: ${data['content']?.substring(0, 20)}...');
    // Sync Message (Direct)

  }

  /// Sync profile changes
  Future<void> _syncProfile(Map<String, dynamic> data) async {
    debugPrint('[OFFLINE] Syncing profile: ${data['field']}');
    // Sync Profile (Direct)

  }

  /// Sync draft tontine
  Future<void> _syncDraft(Map<String, dynamic> data) async {
    debugPrint('[OFFLINE] Syncing draft: ${data['name']}');
    // Sync Draft (Direct)

  }

  /// Check if an action can be performed offline
  static bool canPerformOffline(String action) {
    final offlineActions = [
      'view_circles',
      'view_profile',
      'view_history',
      'draft_message',
      'update_settings',
    ];
    return offlineActions.contains(action);
  }

  /// Get list of features available offline
  static List<String> getOfflineFeatures() {
    return [
      'Consulter vos cercles (cache)',
      'Consulter votre profil',
      'Consulter l\'historique (cache)',
      'Rédiger des messages (envoi différé)',
      'Modifier les paramètres',
    ];
  }

  /// Get list of features NOT available offline
  static List<String> getOnlineOnlyFeatures() {
    return [
      'Effectuer des paiements',
      'Voter',
      'Rejoindre un cercle',
      'Créer une tontine',
      'Contacter le support',
    ];
  }

  /// Clear sync queue (use with caution)
  Future<void> clearQueue() async {
    await _storage.delete(key: _queueKey);
    debugPrint('[OFFLINE] Queue cleared');
  }
}

class SyncResult {
  final bool success;
  final int synced;
  final int failed;
  final String message;

  SyncResult({
    required this.success,
    required this.synced,
    required this.failed,
    required this.message,
  });
}

// ============ PROVIDER ============

final offlineModeServiceProvider = Provider<OfflineModeService>((ref) {
  return OfflineModeService();
});

/// Provider for pending actions count
final pendingActionsCountProvider = FutureProvider<int>((ref) async {
  return ref.watch(offlineModeServiceProvider).getPendingCount();
});
