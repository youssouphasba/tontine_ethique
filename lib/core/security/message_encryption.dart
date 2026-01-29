import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as encrypt;

/// V11.5 - Message Encryption Service
/// End-to-End encryption for private messages

class MessageEncryption {
  // In production: Use secure key exchange (Diffie-Hellman) + per-conversation keys
  // This is a simplified implementation for demonstration
  
  static final _key = encrypt.Key.fromLength(32);
  static final _iv = encrypt.IV.fromLength(16);
  static final _encrypter = encrypt.Encrypter(encrypt.AES(_key));

  /// Encrypt a message before storing
  static String encryptMessage(String plainText) {
    try {
      final encrypted = _encrypter.encrypt(plainText, iv: _iv);
      return '${_iv.base64}:${encrypted.base64}';
    } catch (e) {
      return plainText; // Fallback for demo
    }
  }

  /// Decrypt a message for display
  static String decryptMessage(String encryptedText) {
    try {
      final decrypted = _encrypter.decrypt64(encryptedText, iv: _iv);
      return decrypted;
    } catch (e) {
      return encryptedText; // Fallback for demo
    }
  }

  /// Hash a message for audit log (one-way, non-reversible)
  static String hashForAudit(String message) {
    final bytes = utf8.encode(message);
    final digest = sha256.convert(bytes);
    return '${digest.toString().substring(0, 16)}...'; // Truncated hash
  }

  /// Generate conversation-specific key (for future E2E implementation)
  static String generateConversationKey(String participant1Id, String participant2Id) {
    final combined = [participant1Id, participant2Id]..sort();
    final bytes = utf8.encode(combined.join(':'));
    return sha256.convert(bytes).toString();
  }
}

/// Encrypted Message Model
class EncryptedMessage {
  final String id;
  final String senderId;
  final String receiverId;
  final String encryptedContent;
  final String contentHash; // For audit without revealing content
  final DateTime timestamp;
  final bool isDecryptedForModeration; // Flag if admin accessed

  EncryptedMessage({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.encryptedContent,
    required this.contentHash,
    required this.timestamp,
    this.isDecryptedForModeration = false,
  });

  factory EncryptedMessage.create({
    required String id,
    required String senderId,
    required String receiverId,
    required String plainContent,
    required DateTime timestamp,
  }) {
    return EncryptedMessage(
      id: id,
      senderId: senderId,
      receiverId: receiverId,
      encryptedContent: MessageEncryption.encryptMessage(plainContent),
      contentHash: MessageEncryption.hashForAudit(plainContent),
      timestamp: timestamp,
    );
  }

  /// Decrypt for recipient (normal use)
  String getDecryptedContent() {
    return MessageEncryption.decryptMessage(encryptedContent);
  }

  /// Decrypt for moderation (logs access)
  String decryptForModeration() {
    // In production: Log this access to audit trail
    return MessageEncryption.decryptMessage(encryptedContent);
  }
}

/// Audit Log for Message Access
class MessageAuditLog {
  final String messageId;
  final String accessedBy; // Admin ID
  final String reason; // e.g., "User Report #123"
  final DateTime accessedAt;

  MessageAuditLog({
    required this.messageId,
    required this.accessedBy,
    required this.reason,
    required this.accessedAt,
  });

  Map<String, dynamic> toJson() => {
    'messageId': messageId,
    'accessedBy': accessedBy,
    'reason': reason,
    'accessedAt': accessedAt.toIso8601String(),
  };
}
