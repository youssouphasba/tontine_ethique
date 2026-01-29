import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

/// V16: Biometric & PIN Authentication Service
/// Provides quick reconnection via:
/// - Fingerprint (Touch ID)
/// - Face Recognition (Face ID)
/// - 4-digit PIN code
/// 
/// Security: Credentials are stored in secure storage, 
/// biometric auth is handled by OS-level APIs

class BiometricAuthService {
  final LocalAuthentication _localAuth = LocalAuthentication();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  
  // Storage keys
  static const String _keyBiometricEnabled = 'biometric_enabled';
  static const String _keyPinEnabled = 'pin_enabled';
  static const String _keyPinHash = 'pin_hash';
  static const String _keyUserSession = 'user_session_token';
  static const String _keyLastUserId = 'last_user_id';

  // =============== BIOMETRIC METHODS ===============

  /// Check if device supports biometrics
  Future<bool> isBiometricAvailable() async {
    try {
      final canCheckBiometrics = await _localAuth.canCheckBiometrics;
      final isDeviceSupported = await _localAuth.isDeviceSupported();
      return canCheckBiometrics && isDeviceSupported;
    } on PlatformException catch (_) {
      return false;
    }
  }

  /// Get available biometric types on device
  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _localAuth.getAvailableBiometrics();
    } on PlatformException catch (_) {
      return [];
    }
  }

  /// Check if biometric auth is enabled by user
  Future<bool> isBiometricEnabled() async {
    final value = await _secureStorage.read(key: _keyBiometricEnabled);
    return value == 'true';
  }

  /// Enable biometric authentication
  Future<bool> enableBiometric() async {
    if (!await isBiometricAvailable()) return false;
    await _secureStorage.write(key: _keyBiometricEnabled, value: 'true');
    return true;
  }

  /// Disable biometric authentication
  Future<void> disableBiometric() async {
    await _secureStorage.write(key: _keyBiometricEnabled, value: 'false');
  }

  /// Authenticate with biometrics
  Future<BiometricAuthResult> authenticateWithBiometric({
    String reason = 'Authentifiez-vous pour accéder à Tontetic',
  }) async {
    try {
      if (!await isBiometricEnabled()) {
        return BiometricAuthResult(
          success: false,
          error: 'L\'authentification biométrique n\'est pas activée',
        );
      }

      final authenticated = await _localAuth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false, // Allow PIN fallback on device
          useErrorDialogs: true,
        ),
      );

      if (authenticated) {
        return BiometricAuthResult(success: true);
      }
      return BiometricAuthResult(
        success: false,
        error: 'Authentification annulée',
      );
    } on PlatformException catch (e) {
      String errorMessage;
      switch (e.code) {
        case 'NotAvailable':
          errorMessage = 'Biométrie non disponible sur cet appareil';
          break;
        case 'NotEnrolled':
          errorMessage = 'Aucune empreinte/visage enregistré sur l\'appareil';
          break;
        case 'LockedOut':
          errorMessage = 'Trop de tentatives. Réessayez plus tard.';
          break;
        case 'PermanentlyLockedOut':
          errorMessage = 'Authentification verrouillée. Utilisez votre code PIN.';
          break;
        default:
          errorMessage = 'Erreur d\'authentification: ${e.message}';
      }
      return BiometricAuthResult(success: false, error: errorMessage);
    }
  }

  // =============== PIN CODE METHODS ===============

  /// Check if PIN is enabled
  Future<bool> isPinEnabled() async {
    final value = await _secureStorage.read(key: _keyPinEnabled);
    return value == 'true';
  }

  /// Set up a new PIN code
  Future<bool> setupPin(String pin) async {
    if (pin.length != 4 || !RegExp(r'^\d{4}$').hasMatch(pin)) {
      return false;
    }
    
    // Hash the PIN (in production, use bcrypt or argon2)
    final pinHash = _hashPin(pin);
    await _secureStorage.write(key: _keyPinHash, value: pinHash);
    await _secureStorage.write(key: _keyPinEnabled, value: 'true');
    return true;
  }

  /// Verify PIN code
  Future<BiometricAuthResult> verifyPin(String pin) async {
    try {
      final storedHash = await _secureStorage.read(key: _keyPinHash);
      if (storedHash == null) {
        return BiometricAuthResult(
          success: false,
          error: 'Aucun code PIN configuré',
        );
      }

      final inputHash = _hashPin(pin);
      if (inputHash == storedHash) {
        return BiometricAuthResult(success: true);
      }
      return BiometricAuthResult(
        success: false,
        error: 'Code PIN incorrect',
      );
    } catch (e) {
      return BiometricAuthResult(
        success: false,
        error: 'Erreur de vérification: $e',
      );
    }
  }

  /// Change PIN code
  Future<bool> changePin(String oldPin, String newPin) async {
    final verifyResult = await verifyPin(oldPin);
    if (!verifyResult.success) return false;
    return setupPin(newPin);
  }

  /// Disable PIN
  Future<void> disablePin() async {
    await _secureStorage.delete(key: _keyPinHash);
    await _secureStorage.write(key: _keyPinEnabled, value: 'false');
  }

  /// Secure SHA-256 hashing for PIN
  String _hashPin(String pin) {
    // V16.1: Upgraded from simple XOR to SHA-256 with salt
    const salt = 'tontetic_secure_salt_2026';
    final bytes = utf8.encode(pin + salt);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  // =============== SESSION MANAGEMENT ===============

  /// Save session token for quick reconnection
  Future<void> saveSessionToken(String token, String userId) async {
    await _secureStorage.write(key: _keyUserSession, value: token);
    await _secureStorage.write(key: _keyLastUserId, value: userId);
  }

  /// Get saved session token
  Future<String?> getSessionToken() async {
    return await _secureStorage.read(key: _keyUserSession);
  }

  /// Get last logged in user ID
  Future<String?> getLastUserId() async {
    return await _secureStorage.read(key: _keyLastUserId);
  }

  /// Clear all auth data (logout)
  Future<void> clearAuthData() async {
    await _secureStorage.delete(key: _keyUserSession);
    // Keep biometric/PIN preferences
  }

  /// Full reset (clear everything)
  Future<void> fullReset() async {
    await _secureStorage.deleteAll();
  }

  // =============== QUICK AUTH CHECK ===============

  /// Check if user can use quick auth (biometric or PIN)
  Future<QuickAuthStatus> getQuickAuthStatus() async {
    final hasSession = await getSessionToken() != null;
    final biometricEnabled = await isBiometricEnabled();
    final pinEnabled = await isPinEnabled();
    final biometricAvailable = await isBiometricAvailable();

    return QuickAuthStatus(
      hasStoredSession: hasSession,
      biometricEnabled: biometricEnabled && biometricAvailable,
      pinEnabled: pinEnabled,
      availableBiometrics: await getAvailableBiometrics(),
    );
  }
}

// =============== DATA CLASSES ===============

class BiometricAuthResult {
  final bool success;
  final String? error;

  BiometricAuthResult({required this.success, this.error});
}

class QuickAuthStatus {
  final bool hasStoredSession;
  final bool biometricEnabled;
  final bool pinEnabled;
  final List<BiometricType> availableBiometrics;

  QuickAuthStatus({
    required this.hasStoredSession,
    required this.biometricEnabled,
    required this.pinEnabled,
    required this.availableBiometrics,
  });

  bool get canUseQuickAuth => hasStoredSession && (biometricEnabled || pinEnabled);
  
  bool get hasFaceId => availableBiometrics.contains(BiometricType.face);
  bool get hasFingerprint => availableBiometrics.contains(BiometricType.fingerprint);
  
  String get biometricLabel {
    if (hasFaceId) return 'Face ID';
    if (hasFingerprint) return 'Empreinte digitale';
    return 'Biométrie';
  }
  
  IconData get biometricIcon {
    if (hasFaceId) return Icons.face;
    if (hasFingerprint) return Icons.fingerprint;
    return Icons.security;
  }
}

// =============== PROVIDERS ===============

final biometricAuthServiceProvider = Provider<BiometricAuthService>((ref) {
  return BiometricAuthService();
});

final quickAuthStatusProvider = FutureProvider<QuickAuthStatus>((ref) async {
  return ref.watch(biometricAuthServiceProvider).getQuickAuthStatus();
});
