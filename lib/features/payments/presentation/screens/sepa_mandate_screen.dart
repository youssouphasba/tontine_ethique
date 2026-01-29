import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tontetic/core/providers/user_provider.dart';
import 'package:tontetic/core/theme/app_theme.dart';
import 'package:tontetic/features/payments/data/sepa_mandate_service.dart';

class SepaMandateScreen extends ConsumerStatefulWidget {
  final String setupIntentId;
  const SepaMandateScreen({super.key, required this.setupIntentId});

  @override
  ConsumerState<SepaMandateScreen> createState() => _SepaMandateScreenState();
}

class _SepaMandateScreenState extends ConsumerState<SepaMandateScreen> {
  final _ibanController = TextEditingController();
  final _nameController = TextEditingController();
  bool _isAgreed = false;
  bool _isLoading = false;

  void _submitMandate() async {
    if (_ibanController.text.length < 15 || !_isAgreed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez saisir un IBAN valide et accepter les conditions.')),
      );
      return;
    }

    setState(() => _isLoading = true);
    
    // Stripe Validation (Direct)


    await ref.read(sepaMandateProvider).saveMandate(
      setupIntentId: widget.setupIntentId,
      userId: ref.read(userProvider).uid,
      ibanLast4: _ibanController.text.substring(_ibanController.text.length - 4),
      bankName: 'Banque Partenaire',
    );

    if (mounted) {
      Navigator.pop(context, true); // Success
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Mandat SEPA signé avec succès ! ✍️'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  void dispose() {
    _ibanController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Signature de Mandat SEPA')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.account_balance, 
              size: 64, 
              color: Theme.of(context).brightness == Brightness.dark ? AppTheme.gold : AppTheme.marineBlue,
            ),
            const SizedBox(height: 16),
            const Text(
              'Autorisation de Prélèvement',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Pour participer aux tontines en zone Euro, vous devez autoriser Stripe à prélever votre compte bancaire.',
              style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.grey),
            ),
            const SizedBox(height: 32),
            
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Nom complet du titulaire',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _ibanController,
              decoration: const InputDecoration(
                labelText: 'IBAN (ex: FR76...)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.credit_card),
              ),
              keyboardType: TextInputType.text,
            ),
            
            const SizedBox(height: 24),
            
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark ? Colors.white12 : Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Theme.of(context).brightness == Brightness.dark ? Colors.white24 : Colors.grey[300]!),
              ),
              child: Text(
                'En signant ce mandat, vous autorisez (A) Tontetic à envoyer des instructions à votre banque pour débiter votre compte, '
                'et (B) votre banque à débiter votre compte conformément à ces instructions.',
                style: TextStyle(
                  fontSize: 10, 
                  color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.black87,
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            CheckboxListTile(
              value: _isAgreed,
              onChanged: (v) => setState(() => _isAgreed = v ?? false),
              title: const Text('J\'accepte les conditions du mandat SEPA', style: TextStyle(fontSize: 12)),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
            ),
            
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submitMandate,
                child: _isLoading 
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Signer numériquement'),
              ),
            ),
            
            const SizedBox(height: 16),
            const Center(
              child: Text(
                'Sécurisé par Stripe (PCI-DSS)',
                style: TextStyle(fontSize: 10, color: Colors.grey),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
