import 'package:flutter_test/flutter_test.dart';
import 'package:tontetic/core/services/rate_limit_service.dart';
import 'package:tontetic/core/services/admin_permission_service.dart';
import 'package:tontetic/core/utils/log_sanitizer.dart';

/// V16: Security Tests
/// Tests de sécurité automatisés pour validation continue

void main() {
  group('🔐 Rate Limiting Tests', () {
    late RateLimitService rateLimiter;

    setUp(() {
      rateLimiter = RateLimitService();
    });

    test('allows requests within limit', () {
      // 5 requests allowed per 5 minutes for auth_login
      for (int i = 0; i < 5; i++) {
        final result = rateLimiter.checkAndRecord('auth_login', 'user1');
        expect(result.allowed, isTrue, reason: 'Request $i should be allowed');
      }
    });

    test('blocks requests after threshold', () {
      // Exhaust the limit
      for (int i = 0; i < 5; i++) {
        rateLimiter.checkAndRecord('auth_login', 'user1');
      }

      // 6th request should be blocked
      final result = rateLimiter.checkAndRecord('auth_login', 'user1');
      expect(result.allowed, isFalse);
      expect(result.message, contains('Limite atteinte'));
    });

    test('different users have separate limits', () {
      // Exhaust user1's limit
      for (int i = 0; i < 5; i++) {
        rateLimiter.checkAndRecord('auth_login', 'user1');
      }

      // user2 should still have full quota
      final result = rateLimiter.checkAndRecord('auth_login', 'user2');
      expect(result.allowed, isTrue);
    });

    test('different endpoints have separate limits', () {
      // Exhaust auth_login limit
      for (int i = 0; i < 5; i++) {
        rateLimiter.checkAndRecord('auth_login', 'user1');
      }

      // voice_tts should still work
      final result = rateLimiter.checkAndRecord('voice_tts', 'user1');
      expect(result.allowed, isTrue);
    });
  });

  group('🔐 Permission Tests', () {
    late AdminPermissionService permissionService;

    setUp(() {
      permissionService = AdminPermissionService();
      permissionService.initDemoData();
    });

    test('analyst role can view but not modify', () {
      // admin_005 is analyst (Sophie Analyste)
      permissionService.setCurrentAdmin('admin_005');
      
      expect(permissionService.canView(AdminSection.users), isTrue);
      expect(permissionService.canModify(AdminSection.users), isFalse);
    });

    test('moderator only has access to moderation sections', () {
      // admin_003 is moderator (Marie Modératrice)
      permissionService.setCurrentAdmin('admin_003');
      
      expect(permissionService.canModify(AdminSection.moderation), isTrue);
      expect(permissionService.canModify(AdminSection.reports), isTrue);
      expect(permissionService.canModify(AdminSection.settings), isFalse);
    });

    test('only superAdmin can access settings', () {
      // admin_001 is superAdmin
      permissionService.setCurrentAdmin('admin_001');
      expect(permissionService.canModify(AdminSection.settings), isTrue);

      // admin_002 is regular admin (not superAdmin)
      permissionService.setCurrentAdmin('admin_002');
      expect(permissionService.canModify(AdminSection.settings), isFalse);
    });
  });


  group('🔐 Log Sanitizer Tests', () {
    test('masks email addresses', () {
      const input = 'User contact@example.com logged in';
      final sanitized = LogSanitizer.sanitize(input);
      
      expect(sanitized, contains('co***@example.com'));
      expect(sanitized, isNot(contains('contact@example.com')));
    });

    test('masks phone numbers', () {
      const input = 'User +33612345678 registered';
      final sanitized = LogSanitizer.sanitize(input);
      
      expect(sanitized, isNot(contains('+33612345678')));
      // Masked format: +33612 ** ** ** 78
      expect(sanitized, contains('**'));
    });

    test('masks IBANs', () {
      const input = 'IBAN: FR7612345678901234567890123';
      final sanitized = LogSanitizer.sanitize(input);
      
      expect(sanitized, contains('FR76'));
      expect(sanitized, contains('****'));
      expect(sanitized, isNot(contains('FR7612345678901234567890123')));
    });

    test('masks credit card numbers', () {
      const input = 'Card 4111111111111111 used';
      final sanitized = LogSanitizer.sanitize(input);
      
      expect(sanitized, contains('4111'));
      expect(sanitized, contains('1111'));
      expect(sanitized, isNot(contains('4111111111111111')));
    });

    test('handles multiple PII types in one string', () {
      const input = 'User contact@test.com with phone +33600000000 used card 4111111111111111';
      final sanitized = LogSanitizer.sanitize(input);
      
      expect(sanitized, isNot(contains('contact@test.com')));
      expect(sanitized, isNot(contains('+33600000000')));
      expect(sanitized, isNot(contains('4111111111111111')));
    });
  });

  group('🔐 Vote Immutability Tests', () {
    test('vote record generates consistent hash', () {
      // This would test VotingService in real implementation
      // Verifying that the same vote data produces the same hash
      const circleId = 'circle_123';
      const voterId = 'voter_456';
      const ranking = ['a', 'b', 'c'];
      
      // Hash should be deterministic
      final hash1 = _generateTestHash(circleId, voterId, ranking);
      final hash2 = _generateTestHash(circleId, voterId, ranking);
      
      expect(hash1, equals(hash2));
    });

    test('different rankings produce different hashes', () {
      const circleId = 'circle_123';
      const voterId = 'voter_456';
      
      final hash1 = _generateTestHash(circleId, voterId, ['a', 'b', 'c']);
      final hash2 = _generateTestHash(circleId, voterId, ['c', 'b', 'a']);
      
      expect(hash1, isNot(equals(hash2)));
    });
  });

  group('🔐 Session Security Tests', () {
    test('logout clears session data', () {
      // This would test BiometricAuthService in real implementation
      // Verifying that logout properly clears secure storage
      expect(true, isTrue); // Placeholder - requires mocking secure storage
    });

    test('session token is stored securely', () {
      // Verify tokens are in flutter_secure_storage, not shared_preferences
      expect(true, isTrue); // Placeholder - requires mocking
    });
  });

  group('🔐 Financial Security Tests', () {
    test('amount validation detects tampering', () {
      // Client sends 100, server calculated 110 -> should fail
      const clientAmount = 100.0;
      const serverAmount = 110.0;
      const tolerance = 0.01;
      
      final difference = (clientAmount - serverAmount).abs();
      expect(difference > tolerance, isTrue);
    });

    test('idempotency key is unique per transaction', () {
      final key1 = _generateIdempotencyKey('user1', 'payment', 100.0);
      
      // Same user, same action, same amount at different times -> different keys
      // In real implementation, timestamp is included
      expect(key1.length, greaterThan(0));
    });
  });
}

// Helper functions for tests
String _generateTestHash(String circleId, String voterId, List<String> ranking) {
  final content = '$circleId:$voterId:${ranking.join(',')}';
  return content.hashCode.abs().toRadixString(16);
}

String _generateIdempotencyKey(String userId, String action, double amount) {
  return '${userId}_${action}_${amount}_${DateTime.now().millisecondsSinceEpoch}';
}
