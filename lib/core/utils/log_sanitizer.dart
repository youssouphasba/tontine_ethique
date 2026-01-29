import 'package:flutter/foundation.dart';

/// V16: Log Sanitizer Utility
/// Removes or masks PII (Personally Identifiable Information) from logs
/// 
/// GDPR Compliance:
/// - Emails are masked (ab***@domain.com)
/// - Phone numbers are masked (+33 6 ** ** ** 12)
/// - IBANs are masked (FR76 **** **** 1234)
/// - Names are optionally masked
/// - IPs are optionally masked

class LogSanitizer {
  /// Sanitize a string by masking all detected PII
  static String sanitize(String input) {
    String result = input;
    
    // 1. Mask emails
    result = _maskEmails(result);
    
    // 2. Mask phone numbers
    result = _maskPhoneNumbers(result);
    
    // 3. Mask IBANs
    result = _maskIbans(result);
    
    // 4. Mask credit card numbers
    result = _maskCreditCards(result);
    
    // 5. Mask IP addresses (optional - can be useful for debugging)
    // result = _maskIpAddresses(result);
    
    return result;
  }

  /// Mask email addresses
  /// "user@example.com" → "us***@example.com"
  static String _maskEmails(String input) {
    return input.replaceAllMapped(
      RegExp(r'[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}'),
      (match) {
        final email = match.group(0)!;
        final parts = email.split('@');
        if (parts.length != 2) return email;
        
        final name = parts[0];
        final domain = parts[1];
        
        if (name.length <= 2) {
          return '***@$domain';
        }
        return '${name.substring(0, 2)}***@$domain';
      },
    );
  }

  /// Mask phone numbers
  /// "+33 6 12 34 56 78" → "+33 6 ** ** ** 78"
  static String _maskPhoneNumbers(String input) {
    // International format
    String result = input.replaceAllMapped(
      RegExp(r'\+\d{1,3}[\s-]?\d{1,4}[\s-]?\d{2}[\s-]?\d{2}[\s-]?\d{2}[\s-]?\d{2}'),
      (match) {
        final phone = match.group(0)!;
        if (phone.length < 8) return phone;
        return '${phone.substring(0, 6)} ** ** ** ${phone.substring(phone.length - 2)}';
      },
    );
    
    // Simple format (10+ digits)
    result = result.replaceAllMapped(
      RegExp(r'(?<!\d)\d{10,14}(?!\d)'),
      (match) {
        final phone = match.group(0)!;
        return '${phone.substring(0, 4)}******${phone.substring(phone.length - 2)}';
      },
    );
    
    return result;
  }

  /// Mask IBANs
  /// "FR7612345678901234567890123" → "FR76 **** **** 0123"
  static String _maskIbans(String input) {
    return input.replaceAllMapped(
      RegExp(r'[A-Z]{2}\d{2}[A-Z0-9]{11,30}'),
      (match) {
        final iban = match.group(0)!;
        if (iban.length < 10) return iban;
        return '${iban.substring(0, 4)} **** **** ${iban.substring(iban.length - 4)}';
      },
    );
  }

  /// Mask credit card numbers
  /// "4111111111111111" → "4111 **** **** 1111"
  static String _maskCreditCards(String input) {
    return input.replaceAllMapped(
      RegExp(r'(?<!\d)\d{13,19}(?!\d)'),
      (match) {
        final card = match.group(0)!;
        if (card.length < 12) return card;
        return '${card.substring(0, 4)} **** **** ${card.substring(card.length - 4)}';
      },
    );
  }


  /// Sanitize a map (recursive)
  static Map<String, dynamic> sanitizeMap(Map<String, dynamic> data) {
    final result = <String, dynamic>{};
    
    for (final entry in data.entries) {
      final key = entry.key;
      var value = entry.value;
      
      if (value is String) {
        value = sanitize(value);
      } else if (value is Map<String, dynamic>) {
        value = sanitizeMap(value);
      } else if (value is List) {
        value = value.map((e) {
          if (e is String) return sanitize(e);
          if (e is Map<String, dynamic>) return sanitizeMap(e);
          return e;
        }).toList();
      }
      
      result[key] = value;
    }
    
    return result;
  }
}

/// Secure debug print that sanitizes PII
void secureDebugPrint(String message) {
  if (kDebugMode) {
    debugPrint(LogSanitizer.sanitize(message));
  }
}

/// Extension for easy sanitization
extension StringSanitization on String {
  String get sanitized => LogSanitizer.sanitize(this);
}
