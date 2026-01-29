import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tontetic/core/theme/app_theme.dart';
import 'package:tontetic/core/providers/localization_provider.dart';

class LegalWolofScreen extends ConsumerWidget {
  const LegalWolofScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(localizationProvider);
    
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.translate('legal_wolof_title')),
        backgroundColor: AppTheme.marineBlue,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Image/Icon
            Center(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.gold.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.gavel, size: 40, color: AppTheme.gold),
              ),
            ),
            const SizedBox(height: 32),
            
            // Section 1: Role of Tontetic
            _buildLegalSection(
              title: l10n.translate('role_title'),
              content: l10n.translate('role_content'),
              icon: Icons.account_balance_outlined,
            ),
            
            const SizedBox(height: 24),
            
            // Section 2: Honor Score
            _buildLegalSection(
              title: l10n.translate('honor_score_legal_title'),
              content: l10n.translate('honor_score_legal_content'),
              icon: Icons.star_outline,
            ),
            
            const SizedBox(height: 24),

            // Section 3: Voice Privacy (NEW)
            _buildLegalSection(
              title: 'Lë dëgg ci sa Voice 🎙️',
              content: 'Boo bëggé wax ak Tontii, dañuy jël micro bi. Waaye bul tiit : sa voice duñ ko téye fenn. Bo waxé ba paré ñu bind ko, dañuy fat (supprimer) audio bi lééwi. Duñu gardé sa voice duñ ko denc.',
              icon: Icons.mic_none,
            ),
            
            const SizedBox(height: 32),
            
            // Call to Action / Comfort Message
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.marineBlue.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.marineBlue.withValues(alpha: 0.1)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.security, color: AppTheme.marineBlue, size: 24),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Tontetic: Kaarange ak Koolute rekk rekk !',
                      style: TextStyle(
                        fontStyle: FontStyle.italic,
                        color: AppTheme.marineBlue,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 32),
            
            // Legal Primacy Disclaimer (CRITICAL)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                l10n.translate('legal_primacy'),
                style: const TextStyle(fontSize: 10, color: Colors.grey, fontStyle: FontStyle.italic),
                textAlign: TextAlign.center,
              ),
            ),

            const SizedBox(height: 40),
            
            // Standard Footer Note
            const Center(
              child: Text(
                '© 2026 Tontetic Tech. Tous droits réservés.',
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegalSection({required String title, required String content, required IconData icon}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 20, color: AppTheme.marineBlue),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.marineBlue,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          content,
          style: const TextStyle(
            fontSize: 15,
            color: Colors.black87,
            height: 1.6,
          ),
        ),
        const Divider(height: 32),
      ],
    );
  }
}
