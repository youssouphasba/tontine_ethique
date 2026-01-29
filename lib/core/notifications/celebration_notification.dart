import 'package:flutter/material.dart';
import 'package:tontetic/core/theme/app_theme.dart';

class CelebrationNotification {
  static void show(BuildContext context, String winnerName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.marineBlue,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.celebration, size: 60, color: AppTheme.gold),
            const SizedBox(height: 16),
            const Text(
              'Félicitations !',
              style: TextStyle(color: AppTheme.gold, fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              'C’est au tour de $winnerName de réaliser son projet aujourd\'hui ! 🎊',
              style: const TextStyle(color: Colors.white, fontSize: 16),
              textAlign: TextAlign.center,
            ),
             const SizedBox(height: 24),
             ElevatedButton(
               onPressed: () => Navigator.pop(context),
               style: ElevatedButton.styleFrom(backgroundColor: AppTheme.gold, foregroundColor: AppTheme.marineBlue),
               child: const Text('Envoyer des vœux'),
             )
          ],
        ),
      ),
    );
  }
}
