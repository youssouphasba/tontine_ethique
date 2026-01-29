import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tontetic/core/providers/auth_provider.dart';
import 'package:tontetic/features/auth/presentation/screens/auth_screen.dart';

/// Service managing the Guest Mode timer and restrictions.
class GuestModeService {
  final Ref _ref;
  Timer? _timer;
  
  // 1 Minute in seconds
  static const int kGuestTimeLimit = 60; 

  GuestModeService(this._ref);

  void startTimer(BuildContext context) {
    debugPrint('[GUEST] ⏱️ Démarrage du timer invité (60s)');
    _timer?.cancel();
    
    _timer = Timer(const Duration(seconds: kGuestTimeLimit), () {
      debugPrint('[GUEST] 🛑 Temps écoulé !');
      showForceAuthDialog(context, reason: "Le temps de découverte est écoulé.");
    });
  }

  void stopTimer() {
    _timer?.cancel();
  }

  /// Checks if action is allowed. If not, shows blocking dialog.
  /// Returns TRUE if allowed, FALSE if blocked.
  bool checkActionAllowed(BuildContext context, String actionName) {
    // If not guest, always allowed
    final isGuest = _ref.read(isGuestModeProvider);
    if (!isGuest) return true;

    debugPrint('[GUEST] 🚫 Action bloquée: $actionName');
    showForceAuthDialog(context, reason: "Créez un compte pour accéder à : $actionName");
    return false;
  }

  Future<void> showForceAuthDialog(BuildContext context, {required String reason}) async {
    // Prevent multiple dialogs
    stopTimer(); 

    await showDialog(
      context: context,
      barrierDismissible: false, // BLOCKING
      builder: (ctx) => PopScope(
        canPop: false, // BLOCKING BACK BUTTON
        child: AlertDialog(
          title: const Text('Mode Invité Terminé'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_clock, size: 48, color: Colors.orange),
              const SizedBox(height: 16),
              Text(reason, textAlign: TextAlign.center),
              const SizedBox(height: 8),
              const Text(
                'Pour continuer à utiliser Tontetic et sécuriser votre argent, vous devez vous connecter.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.of(ctx).pop(); // Close dialog
                // Navigate to Auth
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const AuthScreen()),
                  (route) => false,
                );
                // Reset guest state handled by AuthWrapper usually, but good to be explicit
                _ref.read(isGuestModeProvider.notifier).state = false;
              },
              child: const Text('Créer un compte / Se connecter'),
            ),
          ],
        ),
      ),
    );
  }
}

final guestModeServiceProvider = Provider<GuestModeService>((ref) {
  return GuestModeService(ref);
});
