import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// V11.33: Webhook Logging Service
/// Records all incoming webhook events from payment providers (Stripe, Wave)
/// Essential for debugging payment issues and audit trails

enum WebhookProvider { stripe, wave, orangeMoney }
enum WebhookStatus { received, verified, rejected, processed, error }

class WebhookLogEntry {
  final String id;
  final WebhookProvider provider;
  final String eventType;
  final DateTime timestamp;
  final WebhookStatus status;
  final String? transactionId;
  final String? userId;
  final double? amount;
  final String? currency;
  final String? rawPayload;
  final String? errorMessage;
  final String? ipAddress;
  final bool signatureValid;

  WebhookLogEntry({
    required this.id,
    required this.provider,
    required this.eventType,
    required this.timestamp,
    required this.status,
    this.transactionId,
    this.userId,
    this.amount,
    this.currency,
    this.rawPayload,
    this.errorMessage,
    this.ipAddress,
    this.signatureValid = false,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'provider': provider.name,
    'event_type': eventType,
    'timestamp': timestamp.toIso8601String(),
    'status': status.name,
    'transaction_id': transactionId,
    'user_id': userId,
    'amount': amount,
    'currency': currency,
    'raw_payload': rawPayload,
    'error_message': errorMessage,
    'ip_address': ipAddress,
    'signature_valid': signatureValid,
  };
}

class WebhookLogService {
  // In production, this would write to Firestore table `webhook_logs`
  final List<WebhookLogEntry> _logs = [];

  /// Log an incoming webhook
  String logWebhook({
    required WebhookProvider provider,
    required String eventType,
    required WebhookStatus status,
    required bool signatureValid,
    String? transactionId,
    String? userId,
    double? amount,
    String? currency,
    String? rawPayload,
    String? errorMessage,
    String? ipAddress,
  }) {
    final id = 'WH_${DateTime.now().millisecondsSinceEpoch}';
    
    final entry = WebhookLogEntry(
      id: id,
      provider: provider,
      eventType: eventType,
      timestamp: DateTime.now(),
      status: status,
      transactionId: transactionId,
      userId: userId,
      amount: amount,
      currency: currency,
      rawPayload: _truncatePayload(rawPayload),
      errorMessage: errorMessage,
      ipAddress: ipAddress,
      signatureValid: signatureValid,
    );

    _logs.insert(0, entry);
    
    // Keep only last 1000 logs in memory
    if (_logs.length > 1000) {
      _logs.removeRange(1000, _logs.length);
    }

    // Log to console for debugging
    debugPrint('[WEBHOOK LOG] ${provider.name} | $eventType | ${status.name} | sig=${signatureValid ? '✓' : '✗'}');

    // Note: Production persistence happens via Cloud Functions webhook handlers
    // that write directly to Firestore collection 'webhook_logs'

    return id;
  }

  /// Truncate large payloads to save storage
  String? _truncatePayload(String? payload) {
    if (payload == null) return null;
    if (payload.length <= 1000) return payload;
    return '${payload.substring(0, 1000)}... [TRUNCATED]';
  }

  /// Get recent logs (for admin panel)
  List<WebhookLogEntry> getRecentLogs({int limit = 50}) {
    return _logs.take(limit).toList();
  }

  /// Get logs for a specific transaction
  List<WebhookLogEntry> getLogsForTransaction(String transactionId) {
    return _logs.where((log) => log.transactionId == transactionId).toList();
  }

  /// Get logs for a specific user
  List<WebhookLogEntry> getLogsForUser(String userId) {
    return _logs.where((log) => log.userId == userId).toList();
  }

  /// Get failed webhooks (for debugging)
  List<WebhookLogEntry> getFailedWebhooks() {
    return _logs.where((log) => 
      log.status == WebhookStatus.rejected || 
      log.status == WebhookStatus.error ||
      !log.signatureValid
    ).toList();
  }

  /// Summary statistics (for dashboard)
  Map<String, dynamic> getStats() {
    final now = DateTime.now();
    final last24h = _logs.where((log) => 
      log.timestamp.isAfter(now.subtract(const Duration(hours: 24)))
    ).toList();

    return {
      'total_24h': last24h.length,
      'verified_24h': last24h.where((l) => l.signatureValid).length,
      'rejected_24h': last24h.where((l) => l.status == WebhookStatus.rejected).length,
      'stripe_24h': last24h.where((l) => l.provider == WebhookProvider.stripe).length,
      'wave_24h': last24h.where((l) => l.provider == WebhookProvider.wave).length,
    };
  }
}

final webhookLogServiceProvider = Provider<WebhookLogService>((ref) {
  return WebhookLogService();
});
