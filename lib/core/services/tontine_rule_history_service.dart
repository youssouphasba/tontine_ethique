import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// V16: Tontine Rule History Service
// Trace les changements de configuration des cercles
/// 
/// Features:
/// - Immutable rule versioning
/// - Change tracking with reason
/// - Rule comparison between versions
/// - Legal export for disputes
/// - MIGRATED TO FIRESTORE (Jan 2026)

class TontineRuleVersion {
  final String id;
  final String circleId;
  final int version;
  final Map<String, dynamic> rules;
  final DateTime changedAt;
  final String changedBy;
  final String changeReason;
  final String hash;

  TontineRuleVersion({
    required this.id,
    required this.circleId,
    required this.version,
    required this.rules,
    required this.changedAt,
    required this.changedBy,
    required this.changeReason,
    required this.hash,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'circle_id': circleId,
    'version': version,
    'rules': rules,
    'changed_at': changedAt.toIso8601String(),
    'changed_by': changedBy,
    'change_reason': changeReason,
    'hash': hash,
  };

  factory TontineRuleVersion.fromJson(Map<String, dynamic> json) => TontineRuleVersion(
    id: json['id'],
    circleId: json['circle_id'],
    version: json['version'],
    rules: Map<String, dynamic>.from(json['rules']),
    changedAt: DateTime.parse(json['changed_at']),
    changedBy: json['changed_by'],
    changeReason: json['change_reason'],
    hash: json['hash'],
  );
}

class RuleDifference {
  final String field;
  final dynamic oldValue;
  final dynamic newValue;

  RuleDifference({
    required this.field,
    required this.oldValue,
    required this.newValue,
  });
}

class TontineRuleHistoryService {
  final FirebaseFirestore _firestore;

  TontineRuleHistoryService() : _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _collection => 
      _firestore.collection('tontine_rule_history');

  /// Record a new rule version
  Future<TontineRuleVersion> recordRuleChange({
    required String circleId,
    required Map<String, dynamic> newRules,
    required String changedBy,
    required String reason,
    Map<String, dynamic>? previousRules,
  }) async {
    // Get current version number
    final lastVersion = await getLatestVersion(circleId);
    final newVersion = (lastVersion?.version ?? 0) + 1;

    // Generate hash for integrity
    final hash = _generateHash(circleId, newVersion, newRules);

    final id = '${circleId}_v$newVersion';
    final ruleVersion = TontineRuleVersion(
      id: id,
      circleId: circleId,
      version: newVersion,
      rules: newRules,
      changedAt: DateTime.now(),
      changedBy: changedBy,
      changeReason: reason,
      hash: hash,
    );

    await _collection.doc(id).set(ruleVersion.toJson());

    debugPrint('[RULE-HISTORY] Circle $circleId: v$newVersion saved - $reason');

    return ruleVersion;
  }

  /// Get latest rule version for a circle
  Future<TontineRuleVersion?> getLatestVersion(String circleId) async {
    final snapshot = await _collection
        .where('circle_id', isEqualTo: circleId)
        .orderBy('version', descending: true)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return null;
    return TontineRuleVersion.fromJson(snapshot.docs.first.data());
  }

  /// Get all versions for a circle
  Future<List<TontineRuleVersion>> getAllVersions(String circleId) async {
    final snapshot = await _collection
        .where('circle_id', isEqualTo: circleId)
        .orderBy('version', descending: true)
        .get();

    return snapshot.docs
        .map((e) => TontineRuleVersion.fromJson(e.data()))
        .toList();
  }

  /// Get a specific version
  Future<TontineRuleVersion?> getVersion(String circleId, int version) async {
    final snapshot = await _collection
        .where('circle_id', isEqualTo: circleId)
        .where('version', isEqualTo: version)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return null;
    return TontineRuleVersion.fromJson(snapshot.docs.first.data());
  }

  /// Compare two versions and return differences
  // Logic remains same as localized comparison
  List<RuleDifference> compareVersions(
    TontineRuleVersion older,
    TontineRuleVersion newer,
  ) {
    final differences = <RuleDifference>[];

    // Check all fields in newer version
    for (final key in newer.rules.keys) {
      final newValue = newer.rules[key];
      final oldValue = older.rules[key];

      if (newValue != oldValue) {
        differences.add(RuleDifference(
          field: key,
          oldValue: oldValue,
          newValue: newValue,
        ));
      }
    }

    // Check for removed fields
    for (final key in older.rules.keys) {
      if (!newer.rules.containsKey(key)) {
        differences.add(RuleDifference(
          field: key,
          oldValue: older.rules[key],
          newValue: null,
        ));
      }
    }

    return differences;
  }

  /// Check if rules can still be modified (before activation)
  Future<bool> canModifyRules(String circleId) async {
    final latest = await getLatestVersion(circleId);
    if (latest == null) return true;

    // Check if circle is in draft status
    final circleStatus = latest.rules['status'];
    return circleStatus == 'draft' || circleStatus == 'pending';
  }

  /// Export rule history for legal purposes
  Future<String> exportHistory(String circleId) async {
    final versions = await getAllVersions(circleId);
    
    final export = {
      'circle_id': circleId,
      'export_date': DateTime.now().toIso8601String(),
      'total_versions': versions.length,
      'versions': versions.map((v) => {
        'version': v.version,
        'changed_at': v.changedAt.toIso8601String(),
        'changed_by': v.changedBy,
        'reason': v.changeReason,
        'rules': v.rules,
        'hash': v.hash,
      }).toList(),
    };

    return const JsonEncoder.withIndent('  ').convert(export);
  }

  /// Generate hash for integrity verification
  String _generateHash(String circleId, int version, Map<String, dynamic> rules) {
    final content = '$circleId:$version:${jsonEncode(rules)}';
    // Simple hash for demo - use SHA256 in production
    return content.hashCode.abs().toRadixString(16);
  }

  /// Verify rule integrity
  Future<bool> verifyIntegrity(String circleId) async {
    final versions = await getAllVersions(circleId);
    
    for (final version in versions) {
      final expectedHash = _generateHash(circleId, version.version, version.rules);
      if (expectedHash != version.hash) {
        debugPrint('[RULE-HISTORY] Integrity check FAILED for $circleId v${version.version}');
        return false;
      }
    }
    
    return true;
  }
}

// ============ PROVIDER ============

final tontineRuleHistoryServiceProvider = Provider<TontineRuleHistoryService>((ref) {
  return TontineRuleHistoryService();
});
