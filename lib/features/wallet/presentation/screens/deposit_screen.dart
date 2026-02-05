import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tontetic/core/theme/app_theme.dart';
import 'package:tontetic/core/providers/user_provider.dart';
import 'package:tontetic/core/providers/localization_provider.dart';
import 'package:tontetic/core/models/user_model.dart';
import 'package:tontetic/core/services/wolof_audio_service.dart';
import 'package:tontetic/core/services/mobile_money_service.dart';
import 'package:tontetic/core/services/stripe_service.dart';

/// Écran de Crédit Mobile Money - Afrique uniquement
/// Permet de créditer son compte via Wave, Orange Money, Free Money ou Carte
class DepositScreen extends ConsumerStatefulWidget {
  const DepositScreen({super.key});

  @override
  ConsumerState<DepositScreen> createState() => _DepositScreenState();
}

class _DepositScreenState extends ConsumerState<DepositScreen> {
  final _amountController = TextEditingController();
  String _selectedMethod = 'Wave';
  bool _isProcessing = false;
  bool _isSuccess = false;
  String _successMessage = '';

  final double _fixedFee = 200; // Frais fixes FCFA

  // Helper getter for localization
  LocalizationState get l10n => ref.read(localizationProvider);

  // Méthodes de paiement pour l'Afrique uniquement
  final List<Map<String, dynamic>> _methods = [
    {'name': 'Wave', 'icon': Icons.waves, 'color': const Color(0xFF1DA1F2)},
    {'name': 'Orange Money', 'icon': Icons.phone_android, 'color': Colors.orange},
    {'name': 'Free Money', 'icon': Icons.smartphone, 'color': const Color(0xFF00B050)},
    {'name': 'Carte Bancaire', 'icon': Icons.credit_card, 'color': AppTheme.marineBlue},
  ];

  @override
  void initState() {
    super.initState();
    ref.read(wolofAudioServiceProvider).wakeUp();
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _processDeposit() async {
    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.translate('error_invalid_amount'))),
      );
      return;
    }

    final phone = ref.read(userProvider).phoneNumber;

    // Confirmation Dialog
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.translate('confirm_transaction')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSummaryRow(l10n.translate('amount_label'), ref.read(userProvider.notifier).formatContent(amount)),
            _buildSummaryRow(l10n.translate('transaction_fee'), ref.read(userProvider.notifier).formatContent(_fixedFee)),
            const Divider(),
            _buildSummaryRow(l10n.translate('total_debited'), ref.read(userProvider.notifier).formatContent(amount + _fixedFee), isBold: true),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.translate('notification_info').replaceAll('@method', _selectedMethod),
                      style: TextStyle(fontSize: 12, color: Colors.blue.shade700),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.translate('cancel'))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.marineBlue),
            child: Text(l10n.translate('confirm'), style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isProcessing = true);

    // Appel API selon le provider
    MobileMoneyResult result;
    switch (_selectedMethod) {
      case 'Wave':
        result = await MobileMoneyService.initiateWavePayment(
          amount: amount,
          phoneNumber: phone,
          description: 'Crédit Tontetic',
        );
        break;
      case 'Orange Money':
        result = await MobileMoneyService.initiateOrangeMoneyPayment(
          amount: amount,
          phoneNumber: phone,
          description: 'Crédit Tontetic',
        );
        break;
      case 'Free Money':
        result = await MobileMoneyService.initiateFreeMoneyPayment(
          amount: amount,
          phoneNumber: phone,
          description: 'Crédit Tontetic',
        );
        break;
      case 'Carte Bancaire':
        try {
          final stripeSuccess = await StripeService.processPayment(
            amountCents: (amount * 100).toInt(),
            currency: ref.read(userProvider).zone == UserZone.zoneEuro ? 'eur' : 'xof',
            description: 'Crédit Tontetic',
          );
          result = MobileMoneyResult(
            success: stripeSuccess,
            reference: 'STRIPE-${DateTime.now().millisecondsSinceEpoch}',
            provider: 'Stripe',
            amount: amount,
            message: stripeSuccess ? 'Paiement par carte réussi.' : 'Paiement annulé ou échoué.',
          );
        } catch (e) {
          result = MobileMoneyResult(
            success: false,
            reference: 'STRIPE-ERROR',
            provider: 'Stripe',
            amount: amount,
            message: 'Erreur Stripe: $e',
          );
        }
        break;
      default:
        result = MobileMoneyResult(
          success: false,
          reference: 'UNKNOWN',
          provider: 'Inconnu',
          amount: amount,
          message: 'Méthode de paiement non supportée.',
        );
    }

    if (result.success) {
      // SÉCURITÉ : Ne jamais mettre à jour le solde côté client pour les paiements réels.
      // Le Webhook Stripe (ou Mobile Money) s'occupera de créditer le compte via Cloud Functions.
      // On informe juste l'utilisateur.
      debugPrint('Paiement initié avec succès. Attente du webhook...');
    }

    if (mounted) {
      setState(() {
        _isProcessing = false;
        _isSuccess = result.success;
        _successMessage = result.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isSuccess) {
      return _buildSuccessScreen();
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.translate('deposit_title')),
        backgroundColor: AppTheme.marineBlue,
        foregroundColor: Colors.white,
      ),
      body: _isProcessing ? _buildProcessingScreen() : _buildFormScreen(),
    );
  }

  Widget _buildFormScreen() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.translate('deposit_amount_q'),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _amountController,
            keyboardType: TextInputType.number,
            style: TextStyle(
              fontSize: 24, 
              color: Theme.of(context).brightness == Brightness.dark ? AppTheme.gold : AppTheme.marineBlue, 
              fontWeight: FontWeight.bold
            ),
            decoration: InputDecoration(
              suffixText: ref.read(userProvider).currencySymbol,
              border: const OutlineInputBorder(),
              hintText: 'Ex: 10000',
            ),
          ),
          const SizedBox(height: 32),
          
          Text(
            l10n.translate('choose_payment_method'),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          ..._methods.map((method) => _buildMethodRadio(method)),

          const SizedBox(height: 32),
          
          // Résumé
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1E1E1E) : Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Theme.of(context).brightness == Brightness.dark ? Colors.white12 : Colors.grey[300]!),
            ),
            child: Column(
              children: [
                _buildSummaryRow(l10n.translate('amount_label'), _amountController.text.isEmpty ? '-' : ref.read(userProvider.notifier).formatContent(double.tryParse(_amountController.text)!)),
                const SizedBox(height: 8),
                _buildSummaryRow(l10n.translate('service_fees'), ref.read(userProvider.notifier).formatContent(_fixedFee)),
                const Divider(),
                _buildSummaryRow(
                  l10n.translate('total_label'), 
                  _amountController.text.isEmpty ? '-' : ref.read(userProvider.notifier).formatContent((double.tryParse(_amountController.text)!) + _fixedFee), 
                  isBold: true,
                  color: Theme.of(context).brightness == Brightness.dark ? AppTheme.gold : AppTheme.marineBlue,
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.translate('operator_fees_notice'),
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          ),

          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _processDeposit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.marineBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: Text(l10n.translate('pay_with').replaceAll('@method', _selectedMethod), style: const TextStyle(fontSize: 18)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMethodRadio(Map<String, dynamic> method) {
    final isSelected = _selectedMethod == method['name'];
    return InkWell(
      onTap: () => setState(() => _selectedMethod = method['name']),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected ? AppTheme.gold : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
          color: isSelected ? AppTheme.gold.withValues(alpha: 0.05) : Colors.white,
        ),
        child: Row(
          children: [
            Icon(method['icon'], color: method['color']),
            const SizedBox(width: 16),
            Text(
              method['name'], 
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87,
              )
            ),
            const Spacer(),
            if (isSelected) 
              Icon(Icons.check_circle, color: Theme.of(context).brightness == Brightness.dark ? AppTheme.gold : AppTheme.marineBlue),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isBold = false, Color? color}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label, 
          style: TextStyle(
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            color: color ?? (Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.black87),
          ),
        ),
        Text(
          value, 
          style: TextStyle(
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            color: color ?? (Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black),
          ),
        ),
      ],
    );
  }

  Widget _buildProcessingScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: AppTheme.gold),
          const SizedBox(height: 24),
          Text(l10n.translate('connecting_to').replaceAll('@method', _selectedMethod), style: TextStyle(fontSize: 18, color: Theme.of(context).brightness == Brightness.dark ? AppTheme.gold : AppTheme.marineBlue)),
          const SizedBox(height: 8),
          Text(l10n.translate('please_wait'), style: const TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildSuccessScreen() {
    return Scaffold(
      backgroundColor: AppTheme.marineBlue,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.check_circle, color: AppTheme.gold, size: 80),
              const SizedBox(height: 32),
              Text(
                l10n.translate('payment_initiated'),
                style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                _successMessage,
                style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),
              
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Text(l10n.translate('amount_label'), style: TextStyle(color: Colors.grey[600])),
                    const SizedBox(height: 8),
                    Text(
                      ref.read(userProvider.notifier).formatContent(double.tryParse(_amountController.text)!),
                      style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AppTheme.marineBlue),
                    ),
                    const Divider(height: 32),
                    _buildTicketRow(l10n.translate('ticket_method'), _selectedMethod),
                    _buildTicketRow(l10n.translate('ticket_date'), '${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}'),
                  ],
                ),
              ),
              
              const SizedBox(height: 48),
              OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white),
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                ),
                child: Text(l10n.translate('return_to_wallet')),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTicketRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
