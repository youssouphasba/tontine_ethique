import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';

/// V16: Persistent Audit Service
/// Stores all critical actions to Firestore for legal compliance
/// 
/// Features:
/// - Immutable logs (append-only)
/// - Tamper detection via hash chain
/// - Automatic data sanitization
/// - GDPR-compliant (no raw PII in logs)
/// - MIGRATED TO FIRESTORE

enum AuditSeverity {
  debug,    // Dev only
  info,     // Normal operations
  warning,  // Potential issues
  error,    // Errors
  critical, // Security incidents
}

enum AuditCategory {
  auth,           // Login, logout, password changes
  financial,      // Payments, transfers, guarantees
  circle,         // Tontine creation, modifications
  vote,           // Voting actions
  moderation,     // Content moderation
  admin,          // Admin actions
  user,           // Profile changes
  security,       // Security events
  gdpr,           // Data export, deletion
  system,         // System events
}

class AuditEntry {
  final String id;
  final String action;
  final AuditCategory category;
  final String userIdHash; // Hashed for privacy
  final String? targetId;
  final Map<String, dynamic> data;
  final AuditSeverity severity;
  final DateTime timestamp;
  final String previousHash; // For tamper detection
  final String hash;

  AuditEntry({
    required this.id,
    required this.action,
    required this.category,
    required this.userIdHash,
    this.targetId,
    required this.data,
    required this.severity,
    required this.timestamp,
    required this.previousHash,
    required this.hash,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'action': action,
    'category': category.name,
    'user_id_hash': userIdHash,
    'target_id': targetId,
    'data': data,
    'severity': severity.name,
    'timestamp': timestamp.toIso8601String(),
    'previous_hash': previousHash,
    'hash': hash,
  };

  factory AuditEntry.fromJson(Map<String, dynamic> json) => AuditEntry(
    id: json['id'],
    action: json['action'],
    category: AuditCategory.values.byName(json['category']),
    userIdHash: json['user_id_hash'],
    targetId: json['target_id'],
    data: json['data'] ?? {},
    severity: AuditSeverity.values.byName(json['severity']),
    timestamp: DateTime.parse(json['timestamp']),
    previousHash: json['previous_hash'],
    hash: json['hash'],
  );
}

class PersistentAuditService {
  final FirebaseFirestore _firestore;
  String _lastHash = 'genesis';

  PersistentAuditService() : _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _collection => 
      _firestore.collection('audit_logs');

  /// Hash user ID for privacy (GDPR compliance)
  String _hashUserId(String userId) {
    final bytes = utf8.encode('salt_tontetic_$userId');
    return sha256.convert(bytes).toString().substring(0, 16);
  }

  /// Generate hash for tamper detection
  String _generateHash(String action, String userHash, String data, String previousHash) {
    final content = '$action:$userHash:$data:$previousHash:${DateTime.now().millisecondsSinceEpoch}';
    return sha256.convert(utf8.encode(content)).toString();
  }

  /// Sanitize data to remove PII
  Map<String, dynamic> _sanitizeData(Map<String, dynamic> data) {
    final sanitized = <String, dynamic>{};
    
    for (final entry in data.entries) {
      final key = entry.key;
      var value = entry.value;
      
      if (value is String) {
        // Mask emails
        if (key.contains('email') || value.contains('@')) {
          final parts = value.split('@');
          if (parts.length == 2) {
            value = '${parts[0].substring(0, 2)}***@${parts[1]}';
          }
        }
        // Mask phone numbers
        if (key.contains('phone') || RegExp(r'^\+?\d{10,}$').hasMatch(value)) {
          value = '${value.substring(0, 4)}***${value.substring(value.length - 2)}';
        }
        // Mask IBANs
        if (key.contains('iban') || value.length > 15 && value.startsWith(RegExp(r'[A-Z]{2}'))) {
          value = '${value.substring(0, 4)}****${value.substring(value.length - 4)}';
        }
      }
      
      sanitized[key] = value;
    }
    
    return sanitized;
  }

  /// Log an action to persistent storage
  Future<void> log({
    required String action,
    required AuditCategory category,
    required String userId,
    String? targetId,
    Map<String, dynamic> data = const {},
    AuditSeverity severity = AuditSeverity.info,
  }) async {
    final userHash = _hashUserId(userId);
    final sanitizedData = _sanitizeData(data);
    final hash = _generateHash(action, userHash, jsonEncode(sanitizedData), _lastHash);
    
    final entry = AuditEntry(
      id: '${DateTime.now().millisecondsSinceEpoch}_${hash.substring(0, 8)}',
      action: action,
      category: category,
      userIdHash: userHash,
      targetId: targetId,
      data: sanitizedData,
      severity: severity,
      timestamp: DateTime.now(),
      previousHash: _lastHash,
      hash: hash,
    );

    try {
      // V17: Write to Firestore for Back Office visibility
      await _collection.doc(entry.id).set(entry.toJson());
      
      _lastHash = hash;
      
      // Also log locally for debugging
      if (kDebugMode) {
        debugPrint('[AUDIT] ${entry.action} | ${entry.category.name} | ${entry.severity.name}');
      }
    } catch (e) {
      // Fallback to local logging if Firestore fails
      debugPrint('[AUDIT-FALLBACK-ERR] $e');
      debugPrint('[AUDIT-FALLBACK] ${entry.toJson()}');
    }
  }

  // ============ CONVENIENCE METHODS ============

  /// Log authentication event
  Future<void> logAuth(String userId, String action, {Map<String, dynamic>? extra}) async {
    await log(
      action: action,
      category: AuditCategory.auth,
      userId: userId,
      data: extra ?? {},
    );
  }

  /// Log financial transaction
  Future<void> logFinancial({
    required String userId,
    required String action,
    required double amount,
    required String currency,
    String? circleId,
  }) async {
    await log(
      action: action,
      category: AuditCategory.financial,
      userId: userId,
      targetId: circleId,
      data: {'amount': amount, 'currency': currency},
      severity: AuditSeverity.info,
    );
  }

  /// Log voting action
  Future<void> logVote({
    required String voterId,
    required String circleId,
    required bool anonymous,
  }) async {
    await log(
      action: 'VOTE_SUBMITTED',
      category: AuditCategory.vote,
      userId: voterId,
      targetId: circleId,
      data: {'anonymous': anonymous},
    );
  }

  /// Log security event
  Future<void> logSecurity({
    required String userId,
    required String action,
    required Map<String, dynamic> details,
    AuditSeverity severity = AuditSeverity.warning,
  }) async {
    await log(
      action: action,
      category: AuditCategory.security,
      userId: userId,
      data: details,
      severity: severity,
    );
  }

  /// Log GDPR action
  Future<void> logGDPR({
    required String userId,
    required String action,
  }) async {
    await log(
      action: action,
      category: AuditCategory.gdpr,
      userId: userId,
    );
  }

  // ============ QUERY METHODS ============

  /// Get logs for a specific user (admin only)
  Future<List<AuditEntry>> getLogsForUser(String userId, {int limit = 100}) async {
    final userHash = _hashUserId(userId);
    final snapshot = await _collection
        .where('user_id_hash', isEqualTo: userHash)
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .get();
    
    return snapshot.docs.map((e) => AuditEntry.fromJson(e.data())).toList();
  }

  /// Get logs by category
  Future<List<AuditEntry>> getLogsByCategory(AuditCategory category, {int limit = 100}) async {
    final snapshot = await _collection
        .where('category', isEqualTo: category.name)
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .get();
    
    return snapshot.docs.map((e) => AuditEntry.fromJson(e.data())).toList();
  }

  /// Export logs for legal compliance
  Future<String> exportLogs({
    DateTime? from,
    DateTime? to,
    AuditCategory? category,
  }) async {
    Query<Map<String, dynamic>> query = _collection;
    
    if (from != null) {
      query = query.where('timestamp', isGreaterThanOrEqualTo: from.toIso8601String());
    }
    if (to != null) {
      query = query.where('timestamp', isLessThanOrEqualTo: to.toIso8601String());
    }
    if (category != null) {
      query = query.where('category', isEqualTo: category.name);
    }
    
    final snapshot = await query.orderBy('timestamp', descending: false).get();
    final entries = snapshot.docs.map((d) => d.data()).toList();

    return const JsonEncoder.withIndent('  ').convert(entries);
  }

  /// Verify log chain integrity
  Future<bool> verifyIntegrity({int lastNEntries = 100}) async {
    final snapshot = await _collection
        .orderBy('timestamp', descending: true)
        .limit(lastNEntries)
        .get();
    
    final logs = snapshot.docs.map((e) => AuditEntry.fromJson(e.data())).toList();
    
    for (int i = 0; i < logs.length - 1; i++) {
      if (logs[i].previousHash != logs[i + 1].hash) {
        debugPrint('[AUDIT-ALERT] Chain integrity broken at ${logs[i].id}');
        return false;
      }
    }
    
    return true;
  }
}

// ============ PROVIDER ============

final persistentAuditServiceProvider = Provider<PersistentAuditService>((ref) {
  return PersistentAuditService();
});
