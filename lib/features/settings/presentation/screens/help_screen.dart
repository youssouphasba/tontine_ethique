import 'package:flutter/material.dart';
import 'package:tontetic/core/theme/app_theme.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Aide & Tutoriels'), backgroundColor: Theme.of(context).brightness == Brightness.dark ? Colors.black : AppTheme.marineBlue),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildHelpCard(
            context,
            '🎯 Comment ça marche ?',
            'Tontetic digitalise la tontine traditionnelle. Vous cotisez chaque mois, et à tour de rôle, un membre récupère la totalité du pot ("la main") pour financer son projet. Sans aucun intérêt.',
          ),
          _buildHelpCard(
            context,
            '🛡️ La Garantie Solidaire',
            'Pour protéger le cercle, chaque membre signe un mandat. En cas de défaut de paiement, la garantie est activée pour couvrir la mensualité manquante et ne pas pénaliser le groupe.',
          ),
          _buildHelpCard(
            context,
            '🏆 Le Score d\'Honneur',
            'Votre fiabilité est récompensée. Payer à l\'heure augmente votre score (max 100). Un score élevé ouvre l\'accès à des cercles plus importants (Premium).',
          ),
           _buildHelpCard(
            context,
            '💼 Espace Employeur & Marchand',
            'Les entreprises peuvent créer des tontines bonifiées pour leurs salariés. Les marchands certifiés peuvent recevoir des paiements directs des membres.',
          ),
        ],
      ),
    );
  }

  Widget _buildHelpCard(BuildContext context, String title, String content) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Theme.of(context).brightness == Brightness.dark ? AppTheme.gold : AppTheme.marineBlue)),
            const SizedBox(height: 8),
            Text(content, style: TextStyle(height: 1.5, color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.black87)),
          ],
        ),
      ),
    );
  }
}
