import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tontetic/core/providers/user_provider.dart';
import 'package:tontetic/core/services/stripe_service.dart';

class ConnectSuccessScreen extends ConsumerStatefulWidget {
  const ConnectSuccessScreen({super.key});

  @override
  ConsumerState<ConnectSuccessScreen> createState() => _ConnectSuccessScreenState();
}

class _ConnectSuccessScreenState extends ConsumerState<ConnectSuccessScreen> {
  @override
  void initState() {
    super.initState();
    _finalizeConnect();
  }

  Future<void> _finalizeConnect() async {
    // 1. Force refresh of Stripe Connect status
    final user = ref.read(userProvider);
    if (user.stripeConnectAccountId != null) {
      try {
        final status = await StripeService.getConnectAccountStatus(
          accountId: user.stripeConnectAccountId!,
        );
        
        if (status['detailsSubmitted'] == true) {
          ref.read(userProvider.notifier).updateStripeConnectOnboardingComplete(true);
        }
      } catch (e) {
        debugPrint('Error verifying connect status: $e');
      }
    }

    if (mounted) {
      // 2. Show success feedback
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Compte Stripe Connect validé !'), backgroundColor: Colors.green),
      );
      
      // 3. Return to previous screen (LegalCommitment) or Close
      // If we were launched via Deep Link, we might need to go somewhere specific.
      // But typically, we just want to close this "Success" page and let the underlying page (if preserved) show.
      // However, Deep Link usually replaces the stack or pushes on top.
      
      // If we can pop, we pop. If not, we go to CreateTontine or Dashboard.
      if (context.canPop()) {
        context.pop();
      } else {
        // If we came from outside (cold start), we probably want to go to Dashboard or Create Tontine
        // But the user was in the middle of creating a tontine... restoring that state is hard if app was killed.
        // For now, let's redirect to Dashboard with a message.
        context.go('/dashboard');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Finalisation de la connexion Stripe...'),
          ],
        ),
      ),
    );
  }
}
