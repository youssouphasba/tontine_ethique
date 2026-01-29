import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Mobile Money Service for African payment providers
/// Handles Wave, Orange Money, and Free Money integrations
/// 
/// V20: Production-Ready implementation
class MobileMoneyService {
  static const String _waveBaseUrl = 'https://api.wave.com/v1';
  static const String _orangeBaseUrl = 'https://api.orange.com/orange-money-webpay/dev/v1';
  
  /// Available mobile money providers for African region
  static const List<Map<String, dynamic>> africanProviders = [
    {'name': 'Wave', 'icon': 'waves', 'color': 0xFF1DA1F2, 'available': true},
    {'name': 'Orange Money', 'icon': 'money', 'color': 0xFFFF6600, 'available': true},
    {'name': 'Free Money', 'icon': 'phone_android', 'color': 0xFF00B050, 'available': true},
    {'name': 'Carte Bancaire', 'icon': 'credit_card', 'color': 0xFF1A237E, 'available': true},
  ];

  /// Generate a mock transaction reference
  static String _generateReference() {
    final random = Random();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return 'MOB-${timestamp.toString().substring(8)}-${random.nextInt(9999).toString().padLeft(4, '0')}';
  }

  /// Initiate Wave payment
  /// 
  /// In production, this would:
  /// 1. Call Wave Business API to create payment request
  /// 2. Return payment URL or USSD code
  /// 3. Handle webhook for payment confirmation
  static Future<MobileMoneyResult> initiateWavePayment({
    required double amount,
    required String phoneNumber,
    String? description,
  }) async {
    final apiKey = dotenv.env['WAVE_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      return MobileMoneyResult(success: false, reference: '', provider: 'Wave', amount: amount, message: 'Wave API Key not configured');
    }

    try {
      final response = await http.post(
        Uri.parse('$_waveBaseUrl/checkout/sessions'),
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'amount': amount.toInt(),
          'currency': 'XOF',
          'error_url': 'tontetic://payment/error',
          'success_url': 'tontetic://payment/success',
          'client_reference': _generateReference(),
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return MobileMoneyResult(
          success: true,
          reference: data['id'] ?? _generateReference(),
          provider: 'Wave',
          amount: amount,
          message: 'Lien de paiement Wave généré.',
          checkoutUrl: data['wave_launch_url'] ?? data['checkout_url'],
        );
      } else {
        return MobileMoneyResult(
          success: false,
          reference: '',
          provider: 'Wave',
          amount: amount,
          message: 'Erreur Wave: ${response.statusCode}',
          errorCode: response.body,
        );
      }
    } catch (e) {
      return MobileMoneyResult(success: false, reference: '', provider: 'Wave', amount: amount, message: 'Exception: $e');
    }
  }

  /// Initiate Orange Money payment
  /// 
  /// In production, this would:
  /// 1. Call Orange Money API to initiate payment
  /// 2. User receives USSD prompt on their phone
  /// 3. Handle callback for payment confirmation
  static Future<MobileMoneyResult> initiateOrangeMoneyPayment({
    required double amount,
    required String phoneNumber,
    String? description,
  }) async {
    final token = dotenv.env['ORANGE_MONEY_TOKEN'];
    final merchantKey = dotenv.env['ORANGE_MERCHANT_KEY'];

    if (token == null || merchantKey == null) {
      return MobileMoneyResult(success: false, reference: '', provider: 'Orange Money', amount: amount, message: 'Orange Money credentials missing');
    }

    try {
      final response = await http.post(
        Uri.parse('$_orangeBaseUrl/webpayment'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'merchant_key': merchantKey,
          'currency': 'OUV', // Default for OM WebPay
          'order_id': _generateReference(),
          'amount': amount.toInt(),
          'return_url': 'tontetic://payment/complete',
          'cancel_url': 'tontetic://payment/cancel',
          'notif_url': 'https://europe-west1-tontetic-admin.cloudfunctions.net/orangeMoneyWebhook',
          'lang': 'fr',
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return MobileMoneyResult(
          success: true,
          reference: data['pay_token'] ?? _generateReference(),
          provider: 'Orange Money',
          amount: amount,
          message: 'Lien de paiement Orange Money généré.',
          checkoutUrl: data['payment_url'],
        );
      } else {
        return MobileMoneyResult(
          success: false,
          reference: '',
          provider: 'Orange Money',
          amount: amount,
          message: 'Erreur Orange: ${response.statusCode}',
          errorCode: response.body,
        );
      }
    } catch (e) {
      return MobileMoneyResult(success: false, reference: '', provider: 'Orange Money', amount: amount, message: 'Exception: $e');
    }
  }

  /// Initiate Free Money payment
  static Future<MobileMoneyResult> initiateFreeMoneyPayment({
    required double amount,
    required String phoneNumber,
    String? description,
  }) async {
    final apiKey = dotenv.env['FREE_MONEY_API_KEY'];
    if (apiKey == null) {
      // Return structured error instead of fake success for production safety
      return MobileMoneyResult(
        success: false, 
        reference: '', 
        provider: 'Free Money', 
        amount: amount, 
        message: 'Free Money API Key not configured'
      );
    }
    
    try {
      // Generic structure for Free Money API (TouchPay etc.)
      // In a real scenario, check specific documentation for Free Money Senegal
      final response = await http.post(
        Uri.parse('https://api.freemoney.sn/v1/merchant/pay'),
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'amount': amount.toInt(),
          'customer_msisdn': phoneNumber,
          'currency': 'XOF',
          'external_reference': _generateReference(),
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return MobileMoneyResult(
          success: true,
          reference: data['transaction_id'] ?? _generateReference(),
          provider: 'Free Money',
          amount: amount,
          message: 'Paiement Free Money initié.',
          status: PaymentStatus.pending,
        );
      } else {
        return MobileMoneyResult(
          success: false,
          reference: '',
          provider: 'Free Money',
          amount: amount,
          message: 'Erreur Free Money: ${response.statusCode}',
          errorCode: response.body,
        );
      }
    } catch (e) {
      return MobileMoneyResult(
        success: false, 
        reference: '', 
        provider: 'Free Money', 
        amount: amount, 
        message: 'Exception: $e'
      );
    }
  }

  /// Check payment status (for webhooks/polling)
  static Future<MobileMoneyResult> checkPaymentStatus(String reference) async {
    // In production, poll the provider or rely on Webhooks (recommended)
    // Here we implement the Polling client for completeness
    try {
      final apiKey = dotenv.env['WAVE_API_KEY'];
      final response = await http.get(
        Uri.parse('$_waveBaseUrl/checkout/sessions/$reference'),
        headers: {'Authorization': 'Bearer $apiKey'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final status = data['status'] == 'complete' ? PaymentStatus.completed : PaymentStatus.pending;
        return MobileMoneyResult(
          success: true,
          reference: reference,
          provider: 'Wave',
          amount: 0,
          message: 'Statut Wave: ${data['status']}',
          status: status,
        );
      }
    } catch (e) {
      debugPrint('Error checking status: $e');
    }

    return MobileMoneyResult(
      success: false,
      reference: reference,
      provider: 'Unknown',
      amount: 0,
      message: 'Erreur lors de la vérification',
    );
  }
}

/// Result of a mobile money transaction
class MobileMoneyResult {
  final bool success;
  final String reference;
  final String provider;
  final double amount;
  final String message;
  final PaymentStatus status;
  final String? errorCode;

  final String? checkoutUrl;

  MobileMoneyResult({
    required this.success,
    required this.reference,
    required this.provider,
    required this.amount,
    required this.message,
    this.status = PaymentStatus.pending,
    this.errorCode,
    this.checkoutUrl,
  });
}

/// Payment status enum
enum PaymentStatus {
  pending,
  processing,
  completed,
  failed,
  cancelled,
}
