import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tontetic/core/providers/user_provider.dart';
import 'package:tontetic/core/theme/app_theme.dart';
import 'package:tontetic/features/dashboard/presentation/screens/dashboard_screen.dart';

class PendingApprovalScreen extends ConsumerWidget {
  const PendingApprovalScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(userProvider).status;

    // Auto-redirect if validated (Realtime simulation check)
    if (status == AccountStatus.verified) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
         Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const DashboardScreen()));
      });
    }

    return Scaffold(
      body: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(32),
        decoration: const BoxDecoration(
          color: AppTheme.marineBlue,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.hourglass_top, color: AppTheme.gold, size: 80),
            const SizedBox(height: 32),
            const Text(
              'Compte en attente de validation',
              style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            const Text(
              'Vos documents et informations sont en cours d\'analyse par nos administrateurs (Délai moyen: 2h).',
              style: TextStyle(color: Colors.white70, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 48),
              // Demo validation removed for production
          ],
        ),
      ),
    );
  }
}
