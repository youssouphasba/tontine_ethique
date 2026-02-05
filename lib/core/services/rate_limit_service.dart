import 'package:flutter_riverpod/flutter_riverpod.dart';

/// V11.33: Rate Limiting Service
/// Protects API endpoints from abuse (voice synthesis, auth attempts, etc.)
/// Implements a sliding window rate limiter per user/endpoint

class RateLimitService {
  // Configuration: endpoint -> (max requests, window in seconds)
  static const Map<String, RateLimitConfig> _configs = {
    'voice_tts': RateLimitConfig(maxRequests: 5, windowSeconds: 60),      // 5 TTS per minute
    'voice_stt': RateLimitConfig(maxRequests: 10, windowSeconds: 60),     // 10 STT per minute
    'wolof_tts': RateLimitConfig(maxRequests: 5, windowSeconds: 60),      // 5 Wolof per minute
    'auth_login': RateLimitConfig(maxRequests: 5, windowSeconds: 300),    // 5 logins per 5 minutes
    'auth_otp': RateLimitConfig(maxRequests: 3, windowSeconds: 600),      // 3 OTP per 10 minutes
    'payment': RateLimitConfig(maxRequests: 10, windowSeconds: 60),       // 10 payments per minute
  };

  // In-memory storage: endpoint:userId -> list of timestamps
  final Map<String, List<DateTime>> _requestHistory = {};

  /// Check if request is allowed and record it if so
  RateLimitResult checkAndRecord(String endpoint, String userId) {
    final config = _configs[endpoint];
    if (config == null) {
      // Unknown endpoint, allow by default
      return RateLimitResult(allowed: true);
    }

    final key = '$endpoint:$userId';
    final now = DateTime.now();
    final windowStart = now.subtract(Duration(seconds: config.windowSeconds));

    // Initialize or get history
    _requestHistory[key] ??= [];
    
    // Clean old entries outside the window
    _requestHistory[key]!.removeWhere((timestamp) => timestamp.isBefore(windowStart));
    
    final currentCount = _requestHistory[key]!.length;
    
    if (currentCount >= config.maxRequests) {
      // Rate limited
      final oldestRequest = _requestHistory[key]!.first;
      final retryAfter = oldestRequest.add(Duration(seconds: config.windowSeconds)).difference(now);
      
      return RateLimitResult(
        allowed: false,
        remaining: 0,
        retryAfterSeconds: retryAfter.inSeconds,
        message: 'Limite atteinte. Réessayez dans ${retryAfter.inSeconds}s',
      );
    }

    // Allow and record
    _requestHistory[key]!.add(now);
    
    return RateLimitResult(
      allowed: true,
      remaining: config.maxRequests - currentCount - 1,
    );
  }

  /// Check without recording (for UI display)
  int getRemainingRequests(String endpoint, String userId) {
    final config = _configs[endpoint];
    if (config == null) return 999;

    final key = '$endpoint:$userId';
    final now = DateTime.now();
    final windowStart = now.subtract(Duration(seconds: config.windowSeconds));

    _requestHistory[key] ??= [];
    _requestHistory[key]!.removeWhere((timestamp) => timestamp.isBefore(windowStart));

    return config.maxRequests - _requestHistory[key]!.length;
  }

  /// Reset rate limit for a user (admin function)
  void resetUserLimit(String endpoint, String userId) {
    final key = '$endpoint:$userId';
    _requestHistory.remove(key);
  }

  /// Get all active limits (for admin panel)
  Map<String, int> getActiveLimits() {
    final result = <String, int>{};
    for (final key in _requestHistory.keys) {
      if (_requestHistory[key]!.isNotEmpty) {
        result[key] = _requestHistory[key]!.length;
      }
    }
    return result;
  }
}

class RateLimitConfig {
  final int maxRequests;
  final int windowSeconds;

  const RateLimitConfig({
    required this.maxRequests,
    required this.windowSeconds,
  });
}

class RateLimitResult {
  final bool allowed;
  final int remaining;
  final int? retryAfterSeconds;
  final String? message;

  RateLimitResult({
    required this.allowed,
    this.remaining = 0,
    this.retryAfterSeconds,
    this.message,
  });
}

final rateLimitServiceProvider = Provider<RateLimitService>((ref) {
  return RateLimitService();
});
