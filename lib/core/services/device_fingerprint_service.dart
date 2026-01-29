import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:crypto/crypto.dart';

/// V16: Device Fingerprint Service
/// Protects against session hijacking by fingerprinting devices
/// 
/// Security features:
/// - Unique device fingerprint generation
/// - Session binding to device
/// - Automatic invalidation on device change
/// - Trust score for known devices

class DeviceFingerprintService {
  static const FlutterSecureStorage _storage = FlutterSecureStorage();
  static const String _fingerprintKey = 'device_fingerprint';
  static const String _trustedDevicesKey = 'trusted_devices';

  /// Generate a unique fingerprint for this device
  static Future<String> generateFingerprint() async {
    final deviceInfo = DeviceInfoPlugin();
    String rawData = '';

    try {
      if (kIsWeb) {
        // Web: Limited fingerprinting
        rawData = 'web:${DateTime.now().millisecondsSinceEpoch}';
      } else if (defaultTargetPlatform == TargetPlatform.android) {
        final android = await deviceInfo.androidInfo;
        rawData = [
          android.id,
          android.model,
          android.brand,
          android.device,
          android.hardware,
          android.product,
          android.fingerprint,
        ].join(':');
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        final ios = await deviceInfo.iosInfo;
        rawData = [
          ios.identifierForVendor ?? 'unknown',
          ios.model,
          ios.name,
          ios.systemName,
          ios.systemVersion,
        ].join(':');
      } else {
        // Desktop
        rawData = 'desktop:${defaultTargetPlatform.name}:unknown_host';
      }
    } catch (e) {
      debugPrint('[FINGERPRINT] Error getting device info: $e');
      rawData = 'fallback:${DateTime.now().millisecondsSinceEpoch}';
    }

    // Add salt and hash
    final saltedData = 'tontetic_fp_salt_$rawData';
    final bytes = utf8.encode(saltedData);
    final digest = sha256.convert(bytes);
    
    return digest.toString();
  }

  /// Store fingerprint at login
  static Future<void> storeFingerprint() async {
    final fingerprint = await generateFingerprint();
    await _storage.write(key: _fingerprintKey, value: fingerprint);
    debugPrint('[FINGERPRINT] Stored: ${fingerprint.substring(0, 8)}...');
  }

  /// Get stored fingerprint
  static Future<String?> getStoredFingerprint() async {
    return await _storage.read(key: _fingerprintKey);
  }

  /// Validate current session against stored fingerprint
  static Future<FingerprintValidationResult> validateSession() async {
    final storedFingerprint = await getStoredFingerprint();
    
    if (storedFingerprint == null) {
      return FingerprintValidationResult(
        isValid: false,
        reason: 'No fingerprint stored',
        requiresReauth: true,
      );
    }

    final currentFingerprint = await generateFingerprint();
    
    if (currentFingerprint == storedFingerprint) {
      return FingerprintValidationResult(
        isValid: true,
        reason: 'Device matches',
      );
    }

    // Check if device is in trusted list
    final isTrusted = await isDeviceTrusted(currentFingerprint);
    if (isTrusted) {
      return FingerprintValidationResult(
        isValid: true,
        reason: 'Device in trusted list',
        isNewDevice: true,
      );
    }

    // Device mismatch - potential hijacking
    return FingerprintValidationResult(
      isValid: false,
      reason: 'Device fingerprint mismatch',
      requiresReauth: true,
      securityAlert: true,
    );
  }

  /// Check if device is in trusted list
  static Future<bool> isDeviceTrusted(String fingerprint) async {
    final trustedJson = await _storage.read(key: _trustedDevicesKey);
    if (trustedJson == null) return false;
    
    final trusted = List<String>.from(jsonDecode(trustedJson));
    return trusted.contains(fingerprint);
  }

  /// Add current device to trusted list
  static Future<void> trustCurrentDevice() async {
    final fingerprint = await generateFingerprint();
    await trustDevice(fingerprint);
  }

  /// Add a device to trusted list
  static Future<void> trustDevice(String fingerprint) async {
    final trustedJson = await _storage.read(key: _trustedDevicesKey);
    final trusted = trustedJson != null 
        ? List<String>.from(jsonDecode(trustedJson))
        : <String>[];
    
    if (!trusted.contains(fingerprint)) {
      trusted.add(fingerprint);
      // Keep only last 5 trusted devices
      if (trusted.length > 5) {
        trusted.removeAt(0);
      }
      await _storage.write(key: _trustedDevicesKey, value: jsonEncode(trusted));
    }
  }

  /// Remove device from trusted list
  static Future<void> untrustDevice(String fingerprint) async {
    final trustedJson = await _storage.read(key: _trustedDevicesKey);
    if (trustedJson == null) return;
    
    final trusted = List<String>.from(jsonDecode(trustedJson));
    trusted.remove(fingerprint);
    await _storage.write(key: _trustedDevicesKey, value: jsonEncode(trusted));
  }

  /// Clear all fingerprint data (on logout)
  static Future<void> clearFingerprint() async {
    await _storage.delete(key: _fingerprintKey);
  }

  /// Get device info for display (non-sensitive)
  static Future<DeviceDisplayInfo> getDeviceDisplayInfo() async {
    final deviceInfo = DeviceInfoPlugin();
    
    try {
      if (kIsWeb) {
         return DeviceDisplayInfo(name: 'Web Browser', type: 'Web', osVersion: 'Browser');
      }
      if (defaultTargetPlatform == TargetPlatform.android) {
        final android = await deviceInfo.androidInfo;
        return DeviceDisplayInfo(
          name: '${android.brand} ${android.model}',
          type: 'Android',
          osVersion: 'Android ${android.version.release}',
        );
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        final ios = await deviceInfo.iosInfo;
        return DeviceDisplayInfo(
          name: ios.name,
          type: ios.model,
          osVersion: '${ios.systemName} ${ios.systemVersion}',
        );
      }
    } catch (_) {}
    
    return DeviceDisplayInfo(
      name: 'Appareil inconnu',
      type: defaultTargetPlatform.name,
      osVersion: '',
    );
  }
}

// ============ DATA CLASSES ============

class FingerprintValidationResult {
  final bool isValid;
  final String reason;
  final bool requiresReauth;
  final bool securityAlert;
  final bool isNewDevice;

  FingerprintValidationResult({
    required this.isValid,
    required this.reason,
    this.requiresReauth = false,
    this.securityAlert = false,
    this.isNewDevice = false,
  });
}

class DeviceDisplayInfo {
  final String name;
  final String type;
  final String osVersion;

  DeviceDisplayInfo({
    required this.name,
    required this.type,
    required this.osVersion,
  });
}

// ============ PROVIDER ============

final deviceFingerprintProvider = Provider<DeviceFingerprintService>((ref) {
  return DeviceFingerprintService();
});

/// Provider for session validation
final sessionValidationProvider = FutureProvider<FingerprintValidationResult>((ref) async {
  return DeviceFingerprintService.validateSession();
});
