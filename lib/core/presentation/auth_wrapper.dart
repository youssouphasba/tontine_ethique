import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../providers/user_provider.dart';
import '../services/encryption_service.dart';
import '../../features/auth/presentation/screens/type_selection_screen.dart';
import '../../features/dashboard/presentation/screens/dashboard_screen.dart';
import '../../features/onboarding/presentation/screens/onboarding_screen.dart';

class AuthWrapper extends ConsumerWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final userState = ref.watch(userProvider);
    final isGuestMode = ref.watch(isGuestModeProvider);
    
    // Guest Mode takes priority
    if (isGuestMode) {
      debugPrint('AUTH_WRAPPER: Guest Mode active. Showing DashboardScreen');
      return const DashboardScreen();
    }

    return authState.when(
      data: (user) {
        debugPrint('AUTH_WRAPPER: User state changed - user: ${user?.uid ?? "null"}, email: ${user?.email ?? "no email"}');
        if (user != null) {
          // Encryption Check (Non-blocking)
          E2EEncryptionService.ensureKeysExist(user.uid);

          // V22: Remove forced redirection to TypeSelectionScreen. 
          // Let the user see the Dashboard even with a guest status.
          // Dashboard features will show appropriate blockers/prompts.
          debugPrint('AUTH_WRAPPER: User authenticated. Showing DashboardScreen (status: ${userState.status})');
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
        debugPrint('AUTH_WRAPPER: Error in auth state: $error');
        return const OnboardingScreen();
      },
    );
  }
}
