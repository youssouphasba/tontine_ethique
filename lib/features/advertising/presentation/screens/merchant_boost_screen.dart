import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tontetic/core/theme/app_theme.dart';
import 'package:tontetic/core/services/merchant_account_service.dart';
import 'package:tontetic/core/services/stripe_service.dart';

/// Écran pour booster un produit marchand
class MerchantBoostScreen extends ConsumerStatefulWidget {
  final String productId;
  final String productName;

  const MerchantBoostScreen({
    super.key,
    required this.productId,
    required this.productName,
  });

  @override
  ConsumerState<MerchantBoostScreen> createState() => _MerchantBoostScreenState();
}

class _MerchantBoostScreenState extends ConsumerState<MerchantBoostScreen> {
  BoostOption? _selectedOption;
  bool _isProcessing = false;

  Future<void> _processBoost() async {
    if (_selectedOption == null) return;

    setState(() => _isProcessing = true);

    try {
      final stripeSuccess = await StripeService.processPayment(
        amountCents: (_selectedOption!.price * 100).toInt(),
        currency: 'eur',
        description: 'Boost: ${_selectedOption!.name} - ${widget.productName}',
      );

      if (stripeSuccess && mounted) {
        _showSuccessDialog();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors du paiement : $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.rocket_launch, color: Colors.green),
            SizedBox(width: 8),
            Text('Boost activé !'),
          ],
        ),
        content: Text(
          'Votre produit "${widget.productName}" sera mis en avant pendant ${_selectedOption!.durationDays} jour${_selectedOption!.durationDays > 1 ? 's' : ''}.',
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context, true);
            },
            child: const Text('Super !'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final merchantState = ref.watch(merchantAccountProvider);
    final isVerifie = merchantState.isVerifie;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Booster mon produit'),
        backgroundColor: AppTheme.marineBlue,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header produit
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.marineBlue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.inventory_2, color: AppTheme.marineBlue, size: 40),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.productName,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const Text(
                          'Augmentez sa visibilité',
                          style: TextStyle(color: Colors.grey, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Explication
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Le boost est une prestation publicitaire. Il augmente la visibilité de votre produit auprès des utilisateurs.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Options de boost
            const Text('Choisissez votre boost', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),

            ...BoostOption.availableOptions.map((option) {
              // Homepage feature only for Vérifié accounts
              if (option.isHomepageFeature && !isVerifie) {
                return _buildDisabledBoostCard(option);
              }
              return _buildBoostCard(option);
            }),

            const SizedBox(height: 24),

            // Récapitulatif
            if (_selectedOption != null) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Boost sélectionné', style: TextStyle(fontWeight: FontWeight.bold)),
                        Text(_selectedOption!.name),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Durée'),
                        Text('${_selectedOption!.durationDays} jour${_selectedOption!.durationDays > 1 ? 's' : ''}'),
                      ],
                    ),
                    const Divider(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Total', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                        Text(
                          '${_selectedOption!.price.toStringAsFixed(2)} €',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppTheme.marineBlue),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),

            // Bouton paiement
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _selectedOption == null || _isProcessing ? null : _processBoost,
                icon: _isProcessing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.rocket_launch),
                label: Text(_isProcessing 
                    ? 'Paiement en cours...' 
                    : _selectedOption == null 
                        ? 'Sélectionnez un boost'
                        : 'PAYER ${_selectedOption!.price.toStringAsFixed(2)} €'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _selectedOption != null ? AppTheme.marineBlue : Colors.grey,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Mention légale
            const Center(
              child: Text(
                'Paiement sécurisé via Stripe. Prestation publicitaire.',
                style: TextStyle(color: Colors.grey, fontSize: 11),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBoostCard(BoostOption option) {
    final isSelected = _selectedOption?.id == option.id;

    return GestureDetector(
      onTap: () => setState(() => _selectedOption = option),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.gold.withValues(alpha: 0.2) : Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppTheme.gold : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [BoxShadow(color: AppTheme.gold.withValues(alpha: 0.2), blurRadius: 8)]
              : null,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: option.isHomepageFeature ? Colors.purple : AppTheme.marineBlue,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                option.isHomepageFeature ? Icons.star : Icons.trending_up,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(option.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                      if (option.isHomepageFeature) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.purple,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text('PREMIUM', style: TextStyle(color: Colors.white, fontSize: 9)),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(option.description, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${option.price.toStringAsFixed(2)} €',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.marineBlue),
                ),
                Text(
                  '${option.durationDays}j',
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
                Radio<String>(
                  value: option.id,
                  // ignore: deprecated_member_use
                  groupValue: _selectedOption?.id,
                  // ignore: deprecated_member_use
                  onChanged: (value) => setState(() => _selectedOption = option),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDisabledBoostCard(BoostOption option) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade400,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.lock, color: Colors.white),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(option.name, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey.shade600)),
                const SizedBox(height: 4),
                const Text(
                  'Réservé aux comptes Vérifiés',
                  style: TextStyle(fontSize: 12, color: Colors.orange, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          Text(
            '${option.price.toStringAsFixed(2)} €',
            style: TextStyle(color: Colors.grey.shade400, fontSize: 16),
          ),
        ],
      ),
    );
  }
}
