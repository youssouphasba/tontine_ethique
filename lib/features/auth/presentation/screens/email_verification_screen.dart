import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tontetic/core/theme/app_theme.dart';
import 'package:tontetic/core/providers/auth_provider.dart';
import 'dart:async';

/// Écran bloquant tant que l'email n'est pas vérifié (RGPD compliance)
class EmailVerificationScreen extends ConsumerStatefulWidget {
  const EmailVerificationScreen({super.key});

  @override
  ConsumerState<EmailVerificationScreen> createState() => _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends ConsumerState<EmailVerificationScreen> {
  Timer? _checkTimer;
  bool _isResending = false;
  int _cooldown = 0;
  Timer? _cooldownTimer;

  @override
  void initState() {
    super.initState();
    // Vérifier périodiquement si l'email a été vérifié
    _startVerificationCheck();
  }

  @override
  void dispose() {
    _checkTimer?.cancel();
    _cooldownTimer?.cancel();
    super.dispose();
  }

  void _startVerificationCheck() {
    _checkTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      await _checkEmailVerified();
    });
  }

  Future<void> _checkEmailVerified() async {
    final authService = ref.read(authServiceProvider);
    await authService.refreshUser();

    final user = ref.read(authStateProvider).value;
    if (user != null && user.emailVerified) {
      _checkTimer?.cancel();
      if (mounted) {
        // Email vérifié, rediriger vers le dashboard
        context.go('/');
      }
    }
  }

  Future<void> _resendEmail() async {
    if (_cooldown > 0) return;

    setState(() => _isResending = true);

    final authService = ref.read(authServiceProvider);
    final result = await authService.sendEmailVerification();

    setState(() {
      _isResending = false;
      if (result.success) {
        _cooldown = 60;
        _startCooldown();
      }
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.success
            ? 'Email de vérification envoyé !'
            : result.error ?? 'Erreur lors de l\'envoi'),
          backgroundColor: result.success ? Colors.green : Colors.red,
        ),
      );
    }
  }

  void _startCooldown() {
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_cooldown > 0) {
        setState(() => _cooldown--);
      } else {
        _cooldownTimer?.cancel();
      }
    });
  }

  Future<void> _signOut() async {
    final authService = ref.read(authServiceProvider);
    await authService.signOut();
    if (mounted) {
      context.go('/onboarding');
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).value;
    final email = user?.email ?? 'votre adresse email';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icône
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppTheme.marineBlue.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.mark_email_unread_outlined,
                  size: 80,
                  color: AppTheme.marineBlue,
                ),
              ),
              const SizedBox(height: 32),

              // Titre
              Text(
                'Vérifiez votre email',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : AppTheme.marineBlue,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),

              // Description
              Text(
                'Un email de vérification a été envoyé à :',
                style: TextStyle(
                  fontSize: 16,
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),

              // Email
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.gold.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  email,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.gold,
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Instructions
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white10 : Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    _buildStep('1', 'Ouvrez votre boîte mail'),
                    const SizedBox(height: 12),
                    _buildStep('2', 'Cliquez sur le lien de vérification'),
                    const SizedBox(height: 12),
                    _buildStep('3', 'Revenez ici, vous serez connecté automatiquement'),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Bouton renvoyer
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: (_isResending || _cooldown > 0) ? null : _resendEmail,
                  icon: _isResending
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.refresh),
                  label: Text(_cooldown > 0
                    ? 'Renvoyer dans ${_cooldown}s'
                    : 'Renvoyer l\'email'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.marineBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Lien déconnexion
              TextButton(
                onPressed: _signOut,
                child: Text(
                  'Utiliser une autre adresse email',
                  style: TextStyle(
                    color: isDark ? Colors.white70 : Colors.grey[600],
                  ),
                ),
              ),

              const Spacer(),

              // Note RGPD
              Text(
                'La vérification de votre email est obligatoire pour accéder à l\'application (RGPD Art. 7)',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white38 : Colors.black38,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStep(String number, String text) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: const BoxDecoration(
            color: AppTheme.marineBlue,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              number,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(text, style: const TextStyle(fontSize: 14)),
      ],
    );
  }
}
