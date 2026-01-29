import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:tontetic/core/providers/user_provider.dart'; - UNUSED
import 'package:tontetic/core/theme/app_theme.dart';
import 'package:tontetic/features/onboarding/presentation/screens/onboarding_screen.dart';
import 'package:tontetic/features/dashboard/presentation/screens/dashboard_screen.dart';

class LandingScreen extends ConsumerWidget {
  const LandingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppTheme.marineBlue,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              // Logo
              const Icon(Icons.savings, size: 80, color: AppTheme.gold),
              const SizedBox(height: 24),
              const Text(
                'Tontetic',
                style: TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'La Tontine 2.0. Sécurisée. Intelligente.',
                style: TextStyle(color: Colors.white70, fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const Spacer(),
              
              // Actions
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    // Reset user to Guest just in case
                    // Go to Onboarding/Login
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const OnboardingScreen()));
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.gold,
                    foregroundColor: AppTheme.marineBlue,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('COMMENCER (CONNEXION)'),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () {
                    // Set Guest Mode
                    // We don't change state here to keep it simple, just navigate
                    // But ideally we should set a flag in provider
                    // ref.read(userProvider.notifier).setGuestMode(); // Optional
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const DashboardScreen(initialIndex: 1)));
                  },
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.white),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('EXPLORER EN INVITÉ'),
                ),
              ),
              const SizedBox(height: 16),
              
              // Demo button removed for production
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
