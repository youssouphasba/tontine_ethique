import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../providers/user_provider.dart';
import '../services/encryption_service.dart';
import '../../features/dashboard/presentation/screens/dashboard_screen.dart';
import '../../features/onboarding/presentation/screens/onboarding_screen.dart';
import '../../features/auth/presentation/screens/email_verification_screen.dart';

class AuthWrapper extends ConsumerWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    // Watch userProvider to trigger rebuild on user data changes (Riverpod pattern)
    ref.watch(userProvider);
    final isGuestMode = ref.watch(isGuestModeProvider);

    // Guest Mode takes priority
    if (isGuestMode) {
      debugPrint('AUTH_WRAPPER: Guest Mode active. Showing DashboardScreen');
      return const DashboardScreen();
    }

    return authState.when(
      data: (user) {
        debugPrint('AUTH_WRAPPER: User state changed - uid: ${user?.uid != null ? "***" : "null"}');
        if (user != null) {
          // RGPD Compliance: Bloquer l'accès si l'email n'est pas vérifié
          // Exception: comptes créés via téléphone uniquement (pas d'email)
          if (user.email != null && user.email!.isNotEmpty && !user.emailVerified) {
            debugPrint('AUTH_WRAPPER: Email not verified, showing verification screen');
            return const EmailVerificationScreen();
          }

          // Encryption Check (Non-blocking)
          E2EEncryptionService.ensureKeysExist(user.uid);

          debugPrint('AUTH_WRAPPER: User authenticated and verified. Showing DashboardScreen');
          return const DashboardScreen();
        }
        debugPrint('AUTH_WRAPPER: No user, showing OnboardingScreen');
        return const OnboardingScreen();
      },
      loading: () {
        debugPrint('AUTH_WRAPPER: Loading auth state...');
        return const Scaffold(
          body: Center(
            child: CircularProgressIndicator(),
          ),
        );
      },
      error: (error, stack) {
        debugPrint('AUTH_WRAPPER: Error in auth state');
        return const OnboardingScreen();
      },
    );
  }
}
