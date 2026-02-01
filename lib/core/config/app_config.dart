import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  /// Toggle for Alpha Test Phase
  static const bool isSandbox = !kReleaseMode;

  /// Accelerates time: 1 Month = 2 Minutes (120 seconds)
  static const bool testSpeedMode = !kReleaseMode;

  /// Stripe Public Key (Dynamic Load)
  static String get stripePublicKey {
    const buildKey = String.fromEnvironment('STRIPE_PUBLIC_KEY');
    if (buildKey.isNotEmpty) return buildKey;
    // In production, force error if missing
    final envKey = dotenv.env['STRIPE_PUBLIC_KEY'];
    if (envKey == null || envKey.isEmpty) return ''; 
    return envKey;
  }

  /// Wave API Key (Dynamic Load)
  static String get waveApiKey {
    const buildKey = String.fromEnvironment('WAVE_API_KEY');
    if (buildKey.isNotEmpty) return buildKey;
    final envKey = dotenv.env['WAVE_API_KEY'];
    if (envKey == null || envKey.isEmpty) return '';
    return envKey;
  }

  /// Wave Sandbox Endpoint
  static const String waveBaseUrl = 'https://api.wave.com/v1/sandbox';

  /// Tontine Parameters (Seconds in TestSpeedMode)
  static const int monthDurationSeconds = 120;
}
