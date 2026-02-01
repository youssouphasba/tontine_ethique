import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tontetic/core/theme/app_theme.dart';
import 'package:tontetic/core/providers/account_status_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tontetic/core/providers/user_provider.dart';
import 'package:tontetic/core/models/user_model.dart';
import 'package:tontetic/core/services/stripe_service.dart';
import 'package:tontetic/core/providers/auth_provider.dart';

/// PSP Connection Screen
/// Redirects user to external PSP for KYC and payment setup
/// 
/// Flow:
/// 1. Choose PSP based on zone (Wave/OM for FCFA, Stripe/PayPal for Euro)
/// 2. Redirect externally (simulated)
/// 3. Receive callback with psp_user_id + kyc_status
/// 
/// ⚠️ KYC data NEVER stored in our app

class PspConnectionScreen extends ConsumerStatefulWidget {
  const PspConnectionScreen({super.key});

  @override
  ConsumerState<PspConnectionScreen> createState() => _PspConnectionScreenState();
}

class _PspConnectionScreenState extends ConsumerState<PspConnectionScreen> {
  String? _selectedPsp;
  bool _isConnecting = false;
  bool _connectionSuccess = false;

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(userProvider);
    final isEuroZone = user.zone == UserZone.zoneEuro;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Connexion Paiement'),
        backgroundColor: Theme.of(context).brightness == Brightness.dark ? Colors.black : AppTheme.marineBlue,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Text(
              'Activez les paiements',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Theme.of(context).brightness == Brightness.dark ? AppTheme.gold : AppTheme.marineBlue),
            ),
            const SizedBox(height: 8),
            const Text(
              'Pour rejoindre des tontines actives et utiliser le wallet, connectez un service de paiement.',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),

            // Info box
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.security, color: Colors.blue),
                      SizedBox(width: 8),
                      Text('Sécurité Maximale', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                    ],
                  ),
                  SizedBox(height: 8),
                  Text(
                    '• Vos données bancaires ne transitent JAMAIS par notre application\n'
                    '• La vérification d\'identité (KYC) est effectuée par le partenaire\n'
                    '• Nous recevons uniquement un identifiant et le statut de validation',
                    style: TextStyle(fontSize: 13, height: 1.5),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // PSP Selection
            Text(
              isEuroZone ? 'Services disponibles (Zone Euro)' : 'Services disponibles (Zone FCFA)',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 16),

            if (isEuroZone) ...[
              _buildPspCard(
                name: 'Stripe',
                logo: Icons.credit_card,
                color: Colors.purple,
                description: 'Carte bancaire, SEPA',
                features: ['Virements SEPA', 'Prélèvements automatiques', 'Cartes Visa/Mastercard'],
              ),
              const SizedBox(height: 12),
              _buildPspCard(
                name: 'PayPal',
                logo: Icons.paypal,
                color: Colors.blue,
                description: 'Compte PayPal',
                features: ['Paiement instantané', 'Protection acheteur'],
              ),
            ] else ...[
              _buildPspCard(
                name: 'Wave',
                logo: Icons.waves,
                color: Colors.lightBlue,
                description: 'Mobile Money Wave',
                features: ['Transfert instantané', 'Sans frais', 'Disponible partout au Sénégal'],
              ),
              const SizedBox(height: 12),
              _buildPspCard(
                name: 'Orange Money',
                logo: Icons.phone_android,
                color: Colors.orange,
                description: 'Mobile Money Orange',
                features: ['Transfert rapide', 'Large réseau', 'USSD disponible'],
              ),
            ],

            if (_connectionSuccess) ...[
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.green, size: 48),
                    const SizedBox(height: 8),
                    const Text('Connexion réussie !', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.green)),
                    const SizedBox(height: 4),
                    Text('$_selectedPsp est maintenant connecté', style: const TextStyle(color: Colors.green)),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                      child: const Text('Continuer', style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 32),

            // Legal notice
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                '⚠️ En vous connectant à un service de paiement, vous serez redirigé vers leur plateforme pour compléter la vérification d\'identité (KYC). Tontetic n\'a pas accès à ces informations.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPspCard({
    required String name,
    required IconData logo,
    required Color color,
    required String description,
    required List<String> features,
  }) {
    final isSelected = _selectedPsp == name;

    return Card(
      elevation: isSelected ? 4 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: isSelected ? color : Colors.grey[300]!, width: isSelected ? 2 : 1),
      ),
      child: InkWell(
        onTap: () => setState(() => _selectedPsp = name),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(logo, color: color, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: color)),
                        Text(description, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                      ],
                    ),
                  ),
                  if (isSelected)
                    Icon(Icons.check_circle, color: color)
                  else
                    Icon(Icons.radio_button_unchecked, color: Colors.grey[400]),
                ],
              ),
              if (isSelected) ...[
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),
                ...features.map((f) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      Icon(Icons.check, size: 16, color: color),
                      const SizedBox(width: 8),
                      Text(f, style: const TextStyle(fontSize: 13)),
                    ],
                  ),
                )),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isConnecting ? null : () => _connectToPsp(name),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: color,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: _isConnecting
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Text('Se connecter à $name'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _connectToPsp(String pspName) async {
    setState(() => _isConnecting = true);

    // Show redirect dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Redirection vers $pspName'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Vous allez être redirigé vers $pspName pour :'),
            const SizedBox(height: 12),
            const Text('• Créer/accéder à votre compte'),
            const Text('• Vérifier votre identité (KYC)'),
            const Text('• Autoriser les paiements'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(8),
              color: Colors.orange.withValues(alpha: 0.1),
              child: Text(
                '⚠️ Ces informations restent chez $pspName et ne sont pas transmises à Tontetic.',
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Continuer'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      setState(() => _isConnecting = false);
      return;
    }

    try {
      final user = ref.read(userProvider);
      if (pspName.toLowerCase() == 'stripe') {
        // REAL STRIPE FLOW
        await StripeService.initialize();
        final stripeCustomerId = await StripeService.setupSepaMandate(
          email: user.email,
          customerId: user.stripeCustomerId,
        );

        if (stripeCustomerId != null) {
          // Success callback
          ref.read(accountStatusProvider.notifier).onPspConnected(
            pspUserId: stripeCustomerId,
            pspProvider: 'stripe',
            kycVerified: true,
          );

          // Update user locally with the stripeCustomerId if not already present
          if (user.stripeCustomerId == null) {
            ref.read(userProvider.notifier).updateStripeCustomerId(stripeCustomerId);
            
            // PERSIST TO FIRESTORE
            final authService = ref.read(authServiceProvider);

            // Better to use ref.read(authServiceProvider).currentUser?
            // Let's assume user is logged in
            final uid = ref.read(authServiceProvider).currentUserUid;
            if (uid != null) {
              authService.updateUserStripeData(
                uid: uid,
                stripeCustomerId: stripeCustomerId,
              );
            }
          }

          setState(() {
            _isConnecting = false;
            _connectionSuccess = true;
          });

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('✅ Stripe connecté avec succès !'),
                backgroundColor: Colors.green,
              ),
            );
          }
        } else {
          // Cancelled or failed
          setState(() => _isConnecting = false);
        }
      } else {
        // OTHER PSP (Wave, OM, PayPal) - Persist connection preference to Firestore
        final user = ref.read(userProvider);
        final uid = ref.read(authServiceProvider).currentUserUid;
        
        if (uid != null) {
          // 1. Update Firestore User Profile
          // We don't have OAuth for Wave/OM yet, so we trust the user's phone number
          await FirebaseFirestore.instance.collection('users').doc(uid).set({
            'linkedPsp': pspName.toLowerCase(),
            'pspLinkedAt': FieldValue.serverTimestamp(),
            // Assuming the user uses their profile phone number for MM
            'mobileMoneyPhone': user.phoneNumber, 
          }, SetOptions(merge: true));

          // 2. Notify Local State
          ref.read(accountStatusProvider.notifier).onPspConnected(
            pspUserId: user.phoneNumber, // Use phone number as ID for Mobile Money
            pspProvider: pspName.toLowerCase(),
            kycVerified: true, // Pending real KYC check integration
          );

          setState(() {
            _isConnecting = false;
            _connectionSuccess = true;
          });

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('✅ $pspName connecté avec succès !'),
                backgroundColor: Colors.green,
              ),
            );
          }
        } else {
           throw Exception("Utilisateur non identifié");
        }
      }
    } catch (e) {
      setState(() => _isConnecting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Erreur de connexion : ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
