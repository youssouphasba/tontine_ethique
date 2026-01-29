import 'package:flutter_dotenv/flutter_dotenv.dart';

/// V11.32 - Secure Payment Configuration
/// All secrets are now loaded from .env file
/// NEVER commit .env to Git - use .env.example as template

class PaymentConfig {
  // WAVE (Business API)
  static String get waveMerchantId => dotenv.env['WAVE_MERCHANT_ID'] ?? '';
  static String get waveApiKey => dotenv.env['WAVE_API_KEY'] ?? '';
  static String get waveWebhookSecret => dotenv.env['WAVE_WEBHOOK_SECRET'] ?? '';

  // ORANGE MONEY (Web Payment)
  static String get omMerchantKey => dotenv.env['OM_MERCHANT_KEY'] ?? '';
  static String get omMerchantPin => dotenv.env['OM_MERCHANT_PIN'] ?? '';

  // STRIPE (International Card Payments)
  static String get stripePublishableKey => dotenv.env['STRIPE_PUBLISHABLE_KEY'] ?? '';
  static String get stripeSecretKey => dotenv.env['STRIPE_SECRET_KEY'] ?? '';
  static String get stripeWebhookSecret => dotenv.env['STRIPE_WEBHOOK_SECRET'] ?? '';

  // Escrow Account (Technical account receiving funds)
  static String get escrowAccountId => dotenv.env['ESCROW_ACCOUNT_ID'] ?? '';

  // Validation helpers
  static bool get isWaveConfigured => 
    waveMerchantId.isNotEmpty && 
    waveApiKey.isNotEmpty && 
    !waveApiKey.contains('your_');

  static bool get isStripeConfigured => 
    stripePublishableKey.isNotEmpty && 
    stripeSecretKey.isNotEmpty &&
    !stripePublishableKey.contains('your_');

  static bool get isOrangeMoneyConfigured => 
    omMerchantKey.isNotEmpty && 
    !omMerchantKey.contains('your_');
}
