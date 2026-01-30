import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tontetic/core/theme/app_theme.dart';
import 'package:tontetic/core/providers/auth_provider.dart';
import 'package:go_router/go_router.dart';
import 'package:tontetic/features/auth/presentation/screens/pending_approval_screen.dart';
import 'dart:async';

class OtpVerificationScreen extends ConsumerStatefulWidget {
  const OtpVerificationScreen({super.key});

  @override
  ConsumerState<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends ConsumerState<OtpVerificationScreen> {
  final _codeController = TextEditingController();
  int _timeLeft = 60;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_timeLeft > 0) {
        setState(() => _timeLeft--);
      } else {
        _timer?.cancel();
      }
    });
  }

  void _verify() async {
    final code = _codeController.text;
    if (code.length < 4) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Veuillez entrer le code complet')));
      return;
    }

    setState(() => _timeLeft = 0); // Stop timer visually

    try {
      // Real OTP Validation via authServiceProvider
      final authService = ref.read(authServiceProvider);
      final result = await authService.validateOtp(code);
      
      if (result.success && mounted) {
        // Use GoRouter to navigate to pending approval
        // This avoids race conditions with Auth State changes since we whitelisted the route
        GoRouter.of(context).go('/pending-approval');
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.error ?? 'Code invalide'), backgroundColor: Colors.red)
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur de vérification : $e'), backgroundColor: Colors.red)
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Vérification'), backgroundColor: AppTheme.marineBlue),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const Icon(Icons.lock_clock, size: 80, color: AppTheme.gold),
            const SizedBox(height: 24),
            Text(
              'Code de sécurité', 
              style: TextStyle(
                fontSize: 20, 
                fontWeight: FontWeight.bold,
                color: Theme.of(context).brightness == Brightness.dark ? AppTheme.gold : Colors.black87,
              ),
            ),
            Text(
              'Un code OTP a été envoyé à votre numéro.', 
              textAlign: TextAlign.center,
              style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.black54),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _codeController,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 24, 
                letterSpacing: 8,
                color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87,
              ),
              decoration: InputDecoration(
                hintText: '----', 
                hintStyle: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.white24 : Colors.grey),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _verify,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).brightness == Brightness.dark ? AppTheme.gold : AppTheme.marineBlue, 
                  foregroundColor: Theme.of(context).brightness == Brightness.dark ? AppTheme.marineBlue : Colors.white,
                  padding: const EdgeInsets.all(16),
                ),
                child: const Text('Vérifier', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              _timeLeft > 0 ? 'Code expire dans ${_timeLeft}s' : 'Code expiré',
              style: TextStyle(color: _timeLeft > 0 ? Colors.grey : AppTheme.errorRed, fontWeight: FontWeight.bold),
            ),
            if (_timeLeft == 0)
              TextButton(onPressed: () { setState(() => _timeLeft = 60); _startTimer(); }, child: const Text('Renvoyer le code')),
              
            const Spacer(),
            TextButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Support Chat ouvert...')));
              },
              icon: const Icon(Icons.help_outline),
              label: const Text('Besoin d\'aide ?'),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
