import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

/// Wave Payment Service (Zone FCFA - Sénégal, Mali, CI...)
/// Status: PRODUCTION READY (Via Cloud Functions)
class WaveService {
  // URL des Cloud Functions (Similaire à StripeService)
  static const String _functionsBaseUrl = 
      'https://europe-west1-tontetic-admin.cloudfunctions.net';
      
  // Client-side is always "configured" to talk to backend
  bool get isConfigured => true; 

  /// Initiate Payment (Cotisation)
  /// Calls Cloud Function to start Wave checkout
  Future<Map<String, dynamic>> initiatePayment({
    required String phoneNumber,
    required double amount,
    required String reference, // e.g. "cotisation_cercle_123"
  }) async {
    // In prod, this calls query the backend
    if (!isConfigured) {
      return {'success': false, 'error': 'Wave configuration missing'};
    }

    try {
      // Call Cloud Function to keep API Keys secure
      // The Cloud Function will talk to generic Wave API
      final response = await http.post(
        Uri.parse('$_functionsBaseUrl/waveCheckout'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'amount': amount,
          'currency': 'XOF',
          'mobile': phoneNumber,
          'client_reference': reference,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['checkout_url'] != null) {
         return {
          'success': true,
          'transactionId': data['id'], // Wave Transaction ID
          'checkoutUrl': data['checkout_url'],
          'status': 'pending', 
        };
      } else {
        return {
          'success': false, 
          'error': data['message'] ?? 'Erreur lors du paiement Wave'
        };
      }
    } catch (e) {
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  /// Payout to Winner (Disbursement)
  /// Calls Cloud Function to execute payout
  Future<Map<String, dynamic>> payout({
    required String recipientPhone,
    required double amount,
    required String reference,
  }) async {
    if (!isConfigured) {
       return {'success': false, 'error': 'Wave configuration missing'};
    }

    try {
      final response = await http.post(
        Uri.parse('$_functionsBaseUrl/wavePayout'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'amount': amount,
          'currency': 'XOF',
          'mobile': recipientPhone,
          'client_reference': reference,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'transactionId': data['id'],
          'status': data['payment_status'] ?? 'pending',
        };
      } else {
        return {
          'success': false,
          'error': data['message'] ?? 'Erreur lors du virement Wave'
        };
      }
    } catch (e) {
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  /// Check Transaction Status
  Future<String> getTransactionStatus(String transactionId) async {
    try {
      final response = await http.get(
        Uri.parse('$_functionsBaseUrl/waveTransactionStatus?id=$transactionId'),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['payment_status'] ?? 'unknown';
      }
      return 'error';
    } catch (_) {
      return 'error';
    }
  }

  /// V11.32: Real HMAC-SHA256 Webhook Signature Verification
  bool verifyWebhookSignature(String payload, String receivedSignature) {
    final webhookSecret = dotenv.env['WAVE_WEBHOOK_SECRET'] ?? '';
    if (webhookSecret.isEmpty || webhookSecret.contains('your_')) {
      return false;
    }

    // Compute HMAC-SHA256 of payload with secret
    final key = utf8.encode(webhookSecret);
    final payloadBytes = utf8.encode(payload);
    final hmacSha256 = Hmac(sha256, key);
    final computedSignature = hmacSha256.convert(payloadBytes).toString();

    // Compare signatures (timing-safe comparison)
    return _secureCompare(computedSignature, receivedSignature);
  }

  /// Timing-safe string comparison to prevent timing attacks
  bool _secureCompare(String a, String b) {
    if (a.length != b.length) return false;
    int result = 0;
    for (int i = 0; i < a.length; i++) {
      result |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return result == 0;
  }
}

final waveServiceProvider = Provider<WaveService>((ref) {
  return WaveService();
});
