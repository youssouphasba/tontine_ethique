import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:encrypt/encrypt.dart' as enc_lib;
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// V16: Message Encryption Service
/// End-to-end encryption for circle messages
/// 
/// Features:
/// - Per-circle encryption keys
/// - AES-256-CBC encryption
/// - Key derivation from shared secret
/// - Message integrity verification

class MessageEncryptionService {
  static const FlutterSecureStorage _storage = FlutterSecureStorage();
  
  /// Derive a circle-specific encryption key
  static enc_lib.Key _deriveCircleKey(String circleId, String sharedSecret) {
    final keyMaterial = '$circleId:$sharedSecret:tontetic_e2e_v1';
    final keyBytes = sha256.convert(utf8.encode(keyMaterial)).bytes;
    return enc_lib.Key(Uint8List.fromList(keyBytes));
  }

  /// Generate secure random bytes
  static Uint8List _generateSecureRandomBytes(int length) {
    final random = Random.secure();
    return Uint8List.fromList(List.generate(length, (_) => random.nextInt(256)));
  }

  /// Generate a shared secret for a circle (called once at circle creation)
  static Future<String> generateCircleSecret(String circleId) async {
    final randomBytes = _generateSecureRandomBytes(32);
    final secret = base64.encode(randomBytes);
    
    // Store locally
    await _storage.write(key: 'circle_secret_$circleId', value: secret);
    
    return secret;
  }

  /// Get circle secret (should be distributed to members securely)
  static Future<String?> getCircleSecret(String circleId) async {
    return await _storage.read(key: 'circle_secret_$circleId');
  }

  /// Set circle secret (when joining a circle)
  static Future<void> setCircleSecret(String circleId, String secret) async {
    await _storage.write(key: 'circle_secret_$circleId', value: secret);
  }

  /// Encrypt a message for a circle
  static Future<EncryptedMessage> encrypt({
    required String message,
    required String circleId,
    required String senderId,
  }) async {
    final secret = await getCircleSecret(circleId);
    if (secret == null) {
      throw Exception('Circle secret not found. Cannot encrypt message.');
    }

    final key = _deriveCircleKey(circleId, secret);
    final iv = enc_lib.IV(_generateSecureRandomBytes(16));
    final encrypter = enc_lib.Encrypter(enc_lib.AES(key, mode: enc_lib.AESMode.cbc));
    
    // Add metadata for integrity
    final metadata = {
      'sender': senderId.hashCode.toString(),
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
    final payload = jsonEncode({'message': message, 'meta': metadata});
    
    final encrypted = encrypter.encrypt(payload, iv: iv);
    
    // Generate HMAC for integrity
    final hmacKey = sha256.convert(utf8.encode('hmac_$secret')).bytes;
    final hmac = Hmac(sha256, hmacKey);
    final digest = hmac.convert(utf8.encode('${iv.base64}:${encrypted.base64}'));

    return EncryptedMessage(
      ciphertext: encrypted.base64,
      iv: iv.base64,
      hmac: digest.toString(),
      version: 1,
    );
  }

  /// Decrypt a message
  static Future<DecryptedMessage> decrypt({
    required EncryptedMessage encryptedMessage,
    required String circleId,
  }) async {
    final secret = await getCircleSecret(circleId);
    if (secret == null) {
      throw Exception('Circle secret not found. Cannot decrypt message.');
    }

    // Verify HMAC first
    final hmacKey = sha256.convert(utf8.encode('hmac_$secret')).bytes;
    final hmac = Hmac(sha256, hmacKey);
    final expectedDigest = hmac.convert(
      utf8.encode('${encryptedMessage.iv}:${encryptedMessage.ciphertext}')
    );
    
    if (expectedDigest.toString() != encryptedMessage.hmac) {
      throw MessageTamperedException('Message integrity check failed');
    }

    final key = _deriveCircleKey(circleId, secret);
    final iv = enc_lib.IV.fromBase64(encryptedMessage.iv);
    final encrypter = enc_lib.Encrypter(enc_lib.AES(key, mode: enc_lib.AESMode.cbc));
    
    final decrypted = encrypter.decrypt64(encryptedMessage.ciphertext, iv: iv);
    final payload = jsonDecode(decrypted);

    return DecryptedMessage(
      message: payload['message'],
      senderHash: payload['meta']['sender'],
      timestamp: DateTime.fromMillisecondsSinceEpoch(payload['meta']['timestamp']),
      isVerified: true,
    );
  }

  /// Check if encryption is available for a circle
  static Future<bool> isEncryptionAvailable(String circleId) async {
    final secret = await getCircleSecret(circleId);
    return secret != null;
  }

  /// Clear encryption keys (on leave circle)
  static Future<void> clearCircleSecret(String circleId) async {
    await _storage.delete(key: 'circle_secret_$circleId');
  }
}

// ============ DATA CLASSES ============

class EncryptedMessage {
  final String ciphertext;
  final String iv;
  final String hmac;
  final int version;

  EncryptedMessage({
    required this.ciphertext,
    required this.iv,
    required this.hmac,
    required this.version,
  });

  Map<String, dynamic> toJson() => {
    'ciphertext': ciphertext,
    'iv': iv,
    'hmac': hmac,
    'version': version,
  };

  factory EncryptedMessage.fromJson(Map<String, dynamic> json) => EncryptedMessage(
    ciphertext: json['ciphertext'],
    iv: json['iv'],
    hmac: json['hmac'],
    version: json['version'],
  );

  /// Serialize for storage/transmission
  String serialize() => base64.encode(utf8.encode(jsonEncode(toJson())));

  /// Deserialize from storage/transmission
  static EncryptedMessage deserialize(String data) {
    final json = jsonDecode(utf8.decode(base64.decode(data)));
    return EncryptedMessage.fromJson(json);
  }
}

class DecryptedMessage {
  final String message;
  final String senderHash;
  final DateTime timestamp;
  final bool isVerified;

  DecryptedMessage({
    required this.message,
    required this.senderHash,
    required this.timestamp,
    required this.isVerified,
  });
}

class MessageTamperedException implements Exception {
  final String message;
  MessageTamperedException(this.message);
  
  @override
  String toString() => 'MessageTamperedException: $message';
}

// ============ PROVIDER ============

final messageEncryptionServiceProvider = Provider<MessageEncryptionService>((ref) {
  return MessageEncryptionService();
});
