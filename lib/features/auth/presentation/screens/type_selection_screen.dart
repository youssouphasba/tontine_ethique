import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tontetic/core/theme/app_theme.dart';

import 'package:tontetic/features/auth/presentation/screens/individual_registration_screen.dart';
import 'package:tontetic/features/auth/presentation/screens/company_registration_screen.dart';

/// Type Selection Screen
/// First step: Choose between Particulier and Entreprise with detailed explanations

class TypeSelectionScreen extends ConsumerWidget {
  const TypeSelectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      // backgroundColor: AppTheme.offWhite,
      appBar: AppBar(
        title: const Text('Créer un compte'),
        // backgroundColor: AppTheme.marineBlue,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Bienvenue sur Tontetic !',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppTheme.marineBlue),
            ),
            const SizedBox(height: 8),
            const Text(
              'Pour commencer, dites-nous qui vous êtes.',
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
            const SizedBox(height: 32),

            // PARTICULIER CARD
            _buildTypeCard(
              context: context,
              title: 'Je suis un Particulier',
              icon: Icons.person,
              color: Colors.blue,
              features: [
                '✅ Rejoindre des tontines familiales ou amicales',
                '✅ Créer des cercles privés',
                '✅ Consulter et discuter gratuitement',
                '✅ Épargne collaborative sans frais cachés',
              ],
              restrictions: [
                '🛡️ Vos données bancaires sont gérées par nos partenaires certifiés',
                '✅ Utilisez vos vraies informations pour la confiance communautaire',
              ],
              onTap: () async {
                final result = await context.push<bool>('/register-individual');
                if (result == true && context.mounted) {
                  if (Navigator.canPop(context)) {
                    Navigator.pop(context, true);
                  }
                }
              },
              onReadMore: () => _showModalitiesDialog(context, isCompany: false),
            ),
            
            const SizedBox(height: 24),

            // ENTREPRISE CARD
            _buildTypeCard(
              context: context,
              title: 'Je suis une Entreprise',
              icon: Icons.business,
              color: Colors.orange,
              features: [
                '✅ Tontines pour vos salariés (avantage social)',
                '✅ Gestion de trésorerie collaborative',
                '✅ Dashboard RH intégré',
                '✅ Facturation professionnelle',
              ],
              restrictions: [
                '⚠️ Numéro SIRET/NINEA requis',
                '⚠️ Représentant légal identifié',
              ],
              onTap: () => context.push('/register-company'),
              onReadMore: () => _showModalitiesDialog(context, isCompany: true),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeCard({
    required BuildContext context,
    required String title,
    required IconData icon,
    required Color color,
    required List<String> features,
    required List<String> restrictions,
    required VoidCallback onTap,
    required VoidCallback onReadMore,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: color.withValues(alpha: 0.2),
                  child: Icon(icon, color: color, size: 30),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Features
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Ce que vous pouvez faire :', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 8),
                ...features.map((f) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(f, style: const TextStyle(fontSize: 13)),
                )),
                const SizedBox(height: 12),
                const Text('À noter :', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.grey)),
                const SizedBox(height: 8),
                ...restrictions.map((r) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(r, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                )),
              ],
            ),
          ),
          
          // Actions
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                TextButton(
                  onPressed: onReadMore,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                  ),
                  child: const Text('📖 Relire les modalités', style: TextStyle(fontSize: 13)),
                ),
                ElevatedButton(
                  onPressed: onTap,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: color,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    elevation: 0,
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Continuer', style: TextStyle(fontSize: 14)),
                      SizedBox(width: 4),
                      Icon(Icons.arrow_forward, size: 16),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showModalitiesDialog(BuildContext context, {required bool isCompany}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        expand: false,
        builder: (_, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                isCompany ? '📋 Modalités Entreprise' : '📋 Modalités Particulier',
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
              
              if (!isCompany) ...[
                _buildModalitySection(
                  '1. Inscription sur la plateforme',
                  'Vous renseignez : prénom, nom, email, téléphone et mot de passe.\n\n'
                  '✅ Utilisez vos vraies informations pour bénéficier de la protection communautaire\n'
                  '✅ Votre Score d\'Honneur se construit sur votre authenticité\n\n'
                  'Nous vérifions votre email et numéro par OTP.',
                ),
                _buildModalitySection(
                  '2. Acceptation légale obligatoire',
                  'Avant d\'accéder à l\'app, vous acceptez :\n'
                  '• CGU de la plateforme\n'
                  '• Politique de confidentialité\n'
                  '• Charte de fonctionnement des tontines\n\n'
                  'Avec horodatage et version du texte.',
                ),
                _buildModalitySection(
                  '3. Mode lecture seule',
                  'À ce stade, vous pouvez :\n'
                  '✅ Consulter des cercles\n'
                  '✅ Discuter\n'
                  '✅ Créer un cercle (sans paiement)\n\n'
                  '❌ Aucun flux financier possible.',
                ),
                _buildModalitySection(
                  '4. Connexion au PSP (externe)',
                  'Pour activer les paiements, vous êtes redirigé vers Wave, Stripe, OM ou PayPal.\n\n'
                  'C\'est le PSP qui :\n'
                  '• Collecte votre identité légale\n'
                  '• Effectue le KYC\n'
                  '• Gère vos moyens de paiement\n\n'
                  '⚠️ Ces données ne transitent JAMAIS par notre app.',
                ),
                _buildModalitySection(
                  '5. Activation financière',
                  'Après signature d\'un contrat de tontine, vous pouvez :\n'
                  '✅ Rejoindre des tontines actives\n'
                  '✅ Effectuer des paiements\n'
                  '✅ Utiliser le wallet',
                ),
              ] else ...[
                _buildModalitySection(
                  'Compte Entreprise',
                  'Fonctionnalités spécifiques :\n'
                  '• Tontines salariales\n'
                  '• Dashboard RH\n'
                  '• Gestion multi-utilisateurs\n'
                  '• Facturation B2B\n\n'
                  'Documents requis :\n'
                  '• SIRET / NINEA\n'
                  '• Identité du représentant légal',
                ),
              ],
              
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('J\'ai compris'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModalitySection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(content, style: const TextStyle(fontSize: 14, height: 1.5)),
          ),
        ],
      ),
    );
  }
}
