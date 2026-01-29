import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tontetic/core/services/auth_service.dart';

/// Provider pour le service d'authentification
final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});

/// Stream provider pour suivre l'état de l'utilisateur Firebase
final authStateProvider = StreamProvider((ref) {
  return ref.watch(authServiceProvider).userStream;
});

/// Provider pour le mode invité (État local)
final isGuestModeProvider = StateProvider<bool>((ref) => false);
