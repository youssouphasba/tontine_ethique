import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';

/// V16: AI Conversation Logging Service
/// Logs AI (Tontii) conversations for compliance and safety monitoring
/// 
/// Features:
/// - Anonymous conversation logging
/// - Financial content detection
/// - Safety alert triggers
/// - No personal data stored
/// - MIGRATED TO FIRESTORE

class AIConversationLogEntry {
  final String id;
  final String userIdHash; // Anonymized
  final int promptLength;
  final int responseLength;
  final bool containsFinancialContent;
  final bool containsLegalAdvice;
  final bool triggeredSafetyAlert;
  final DateTime timestamp;
  final String? category;

  AIConversationLogEntry({
    required this.id,
    required this.userIdHash,
    required this.promptLength,
    required this.responseLength,
    required this.containsFinancialContent,
    required this.containsLegalAdvice,
    required this.triggeredSafetyAlert,
    required this.timestamp,
    this.category,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'user_id_hash': userIdHash,
    'prompt_length': promptLength,
    'response_length': responseLength,
    'contains_financial_content': containsFinancialContent,
    'contains_legal_advice': containsLegalAdvice,
    'triggered_safety_alert': triggeredSafetyAlert,
    'timestamp': timestamp.toIso8601String(),
    'category': category,
  };

  factory AIConversationLogEntry.fromJson(Map<String, dynamic> json) => AIConversationLogEntry(
    id: json['id'],
    userIdHash: json['user_id_hash'],
    promptLength: json['prompt_length'],
    responseLength: json['response_length'],
    containsFinancialContent: json['contains_financial_content'],
    containsLegalAdvice: json['contains_legal_advice'],
    triggeredSafetyAlert: json['triggered_safety_alert'],
    timestamp: DateTime.parse(json['timestamp']),
    category: json['category'],
  );
}

class AIConversationLoggingService {
  final FirebaseFirestore _firestore;

  AIConversationLoggingService() : _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _logsCollection => 
      _firestore.collection('ai_conversation_logs');

  CollectionReference<Map<String, dynamic>> get _alertsCollection => 
      _firestore.collection('admin_alerts');

  // Financial keywords to detect
  static const List<String> _financialKeywords = [
    'investir',
    'placement',
    'rendement',
    'gagner de l\'argent',
    'forex',
    'crypto',
    'bitcoin',
    'bourse',
    'actions',
    'dividendes',
    'intérêts',
    'crédit',
    'prêt bancaire',
    'assurance vie',
  ];

  // Legal advice keywords to detect
  static const List<String> _legalKeywords = [
    'avocat',
    'procès',
    'tribunal',
    'plainte',
    'poursuite',
    'loi',
    'article de loi',
    'juridique',
    'légal',
    'contrat',
    'responsabilité',
    'dommages et intérêts',
  ];

  // Safety alert triggers
  static const List<String> _safetyTriggers = [
    'suicide',
    'violence',
    'arnaque',
    'escroquerie',
    'blanchiment',
    'fraude',
    'illégal',
  ];

  /// Log an AI conversation
  Future<void> logConversation({
    required String userId,
    required String prompt,
    required String response,
  }) async {
    final now = DateTime.now();
    final userHash = _hashUserId(userId);
    
    final containsFinancial = _detectFinancialContent(prompt + response);
    final containsLegal = _detectLegalAdvice(prompt + response);
    final triggeredSafety = _detectSafetyTrigger(prompt);
    
    // Determine category
    String? category;
    if (prompt.toLowerCase().contains('tontine')) {
      category = 'tontine';
    } else if (prompt.toLowerCase().contains('compte') || prompt.toLowerCase().contains('abonnement')) {
      category = 'account';
    } else if (prompt.toLowerCase().contains('aide') || prompt.toLowerCase().contains('comment')) {
      category = 'help';
    }

    final entry = AIConversationLogEntry(
      id: 'ai_${now.millisecondsSinceEpoch}',
      userIdHash: userHash,
      promptLength: prompt.length,
      responseLength: response.length,
      containsFinancialContent: containsFinancial,
      containsLegalAdvice: containsLegal,
      triggeredSafetyAlert: triggeredSafety,
      timestamp: now,
      category: category,
    );

    try {
      await _logsCollection.doc(entry.id).set(entry.toJson());
      
      // If safety alert, notify admin
      if (triggeredSafety) {
        await _notifyAdmin(userId, prompt.substring(0, prompt.length.clamp(0, 100)));
      }
      
      if (kDebugMode) {
        debugPrint('[AI-LOG] Conversation logged: ${entry.id}');
      }
    } catch (e) {
      debugPrint('[AI-LOG] Error logging conversation: $e');
    }
  }

  /// Hash user ID for anonymization
  String _hashUserId(String userId) {
    final bytes = utf8.encode('tontetic_ai_$userId');
    return sha256.convert(bytes).toString().substring(0, 16);
  }

  /// Detect financial content
  bool _detectFinancialContent(String text) {
    final lower = text.toLowerCase();
    return _financialKeywords.any((keyword) => lower.contains(keyword));
  }

  /// Detect legal advice
  bool _detectLegalAdvice(String text) {
    final lower = text.toLowerCase();
    return _legalKeywords.any((keyword) => lower.contains(keyword));
  }

  /// Detect safety triggers
  bool _detectSafetyTrigger(String text) {
    final lower = text.toLowerCase();
    return _safetyTriggers.any((trigger) => lower.contains(trigger));
  }

  /// Notify admin of safety concern
  Future<void> _notifyAdmin(String userId, String excerpt) async {
    await _alertsCollection.add({
      'type': 'ai_safety',
      'severity': 'high',
      'message': 'AI safety trigger detected',
      'data': {'user_id_hash': _hashUserId(userId), 'excerpt_length': excerpt.length},
      'created_at': DateTime.now().toIso8601String(),
      'is_resolved': false,
    });
    
    debugPrint('[AI-LOG] Safety alert sent to admin');
  }

  /// Get statistics for admin dashboard
  Future<Map<String, dynamic>> getStatistics({int lastDays = 7}) async {
    final since = DateTime.now().subtract(Duration(days: lastDays));
    
    final snapshot = await _logsCollection
        .where('timestamp', isGreaterThanOrEqualTo: since.toIso8601String())
        .get();

    final logs = snapshot.docs.map((d) => d.data()).toList();
    
    return {
      'total_conversations': logs.length,
      'financial_content_count': logs.where((l) => l['contains_financial_content'] == true).length,
      'legal_advice_count': logs.where((l) => l['contains_legal_advice'] == true).length,
      'safety_alerts': logs.where((l) => l['triggered_safety_alert'] == true).length,
      'categories': _groupByCategory(logs),
      'avg_prompt_length': logs.isEmpty ? 0 : 
          logs.map((l) => l['prompt_length'] as int).reduce((a, b) => a + b) ~/ logs.length,
    };
  }

  Map<String, int> _groupByCategory(List logs) {
    final result = <String, int>{};
    for (final log in logs) {
      final category = log['category'] as String? ?? 'other';
      result[category] = (result[category] ?? 0) + 1;
    }
    return result;
  }

  /// Export logs for compliance audit
  Future<String> exportLogs({
    required DateTime from,
    required DateTime to,
  }) async {
    final snapshot = await _logsCollection
        .where('timestamp', isGreaterThanOrEqualTo: from.toIso8601String())
        .where('timestamp', isLessThanOrEqualTo: to.toIso8601String())
        .orderBy('timestamp', descending: false)
        .get();

    final entries = snapshot.docs.map((d) => d.data()).toList();

    return const JsonEncoder.withIndent('  ').convert({
      'export_date': DateTime.now().toIso8601String(),
      'from': from.toIso8601String(),
      'to': to.toIso8601String(),
      'total_entries': entries.length,
      'entries': entries,
    });
  }
}

// ============ PROVIDER ============

final aiConversationLoggingServiceProvider = Provider<AIConversationLoggingService>((ref) {
  return AIConversationLoggingService();
});
