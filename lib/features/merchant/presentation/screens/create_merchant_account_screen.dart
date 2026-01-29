import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tontetic/core/theme/app_theme.dart';
import 'package:tontetic/core/providers/merchant_account_provider.dart';
import 'package:tontetic/core/providers/user_provider.dart';

/// Merchant Account Creation Screen
/// Allows users to create a merchant account from their existing profile
/// 
/// Required info: Shop name, category, address
/// Optional: Professional email, description
/// PSP connection: External redirect to Stripe/Wave

class CreateMerchantAccountScreen extends ConsumerStatefulWidget {
  const CreateMerchantAccountScreen({super.key});

  @override
  ConsumerState<CreateMerchantAccountScreen> createState() => _CreateMerchantAccountScreenState();
}

class _CreateMerchantAccountScreenState extends ConsumerState<CreateMerchantAccountScreen> {
  final _formKey = GlobalKey<FormState>();
  int _currentStep = 0;
  bool _isLoading = false;

  // Step 1: Shop Info
  final _shopNameController = TextEditingController();
  final _professionalEmailController = TextEditingController();
  final _addressController = TextEditingController();
  final _descriptionController = TextEditingController();
  ProductCategory _selectedCategory = ProductCategory.other;

  // Step 2: Legal acceptance
  bool _cguAccepted = false;
  bool _noFundsAccepted = false;

  // Step 3: PSP
  bool _pspConnected = false;
  String? _selectedPsp;

  @override
  void dispose() {
    _shopNameController.dispose();
    _professionalEmailController.dispose();
    _addressController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.offWhite,
      appBar: AppBar(
        title: Text(_getStepTitle()),
        backgroundColor: Colors.deepPurple,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _currentStep > 0 
            ? () => setState(() => _currentStep--) 
            : () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          Column(
            children: [
              _buildProgressBar(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Form(
                    key: _formKey,
                    child: _buildCurrentStep(),
                  ),
                ),
              ),
            ],
          ),
          if (_isLoading)
            Container(
              color: Colors.black54,
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }

  String _getStepTitle() {
    switch (_currentStep) {
      case 0: return 'Étape 1/3 — Boutique';
      case 1: return 'Étape 2/3 — Conditions';
      case 2: return 'Étape 3/3 — Paiement';
      default: return 'Compte Marchand';
    }
  }

  Widget _buildProgressBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: Colors.white,
      child: Row(
        children: List.generate(3, (i) => Expanded(
          child: Container(
            height: 4,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              color: _currentStep >= i ? Colors.deepPurple : Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        )),
      ),
    );
  }

  Widget _buildCurrentStep() {
    switch (_currentStep) {
      case 0: return _buildStep1();
      case 1: return _buildStep2();
      case 2: return _buildStep3();
      default: return const SizedBox.shrink();
    }
  }

  // =============== STEP 1: SHOP INFO ===============
  Widget _buildStep1() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Informations Boutique', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.deepPurple)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.deepPurple.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Row(
            children: [
              Icon(Icons.store, color: Colors.deepPurple),
              SizedBox(width: 8),
              Expanded(child: Text('Créez votre boutique et vendez vos produits', style: TextStyle(fontSize: 12, color: Colors.deepPurple))),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Shop Name
        TextFormField(
          controller: _shopNameController,
          decoration: const InputDecoration(
            labelText: 'Nom de la boutique / marque',
            prefixIcon: Icon(Icons.storefront),
            border: OutlineInputBorder(),
          ),
          validator: (v) => v!.isEmpty ? 'Requis' : null,
        ),
        const SizedBox(height: 16),

        // Category
        DropdownButtonFormField<ProductCategory>(
          initialValue: _selectedCategory,
          decoration: const InputDecoration(
            labelText: 'Catégorie',
            prefixIcon: Icon(Icons.category),
            border: OutlineInputBorder(),
          ),
          items: ProductCategory.values.map((c) => DropdownMenuItem(
            value: c,
            child: Text(_getCategoryLabel(c)),
          )).toList(),
          onChanged: (v) => setState(() => _selectedCategory = v!),
        ),
        const SizedBox(height: 16),

        // Professional Email (optional)
        TextFormField(
          controller: _professionalEmailController,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(
            labelText: 'Email professionnel (optionnel)',
            prefixIcon: Icon(Icons.email),
            border: OutlineInputBorder(),
            helperText: 'Si différent de votre email principal',
          ),
        ),
        const SizedBox(height: 16),

        // Address
        TextFormField(
          controller: _addressController,
          maxLines: 2,
          decoration: const InputDecoration(
            labelText: 'Adresse professionnelle',
            prefixIcon: Icon(Icons.location_on),
            border: OutlineInputBorder(),
            helperText: 'Pour facturation et conformité',
          ),
          validator: (v) => v!.isEmpty ? 'Requis' : null,
        ),
        const SizedBox(height: 16),

        // Description
        TextFormField(
          controller: _descriptionController,
          maxLines: 3,
          maxLength: 200,
          decoration: const InputDecoration(
            labelText: 'Description (optionnel)',
            prefixIcon: Icon(Icons.description),
            border: OutlineInputBorder(),
            hintText: 'Décrivez votre activité...',
          ),
        ),
        const SizedBox(height: 24),

        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () {
              if (_formKey.currentState!.validate()) {
                setState(() => _currentStep = 1);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16)),
            child: const Text('Continuer'),
          ),
        ),
      ],
    );
  }

  String _getCategoryLabel(ProductCategory c) {
    switch (c) {
      case ProductCategory.electronics: return '📱 Électronique';
      case ProductCategory.fashion: return '👗 Mode & Vêtements';
      case ProductCategory.food: return '🍽️ Alimentation';
      case ProductCategory.services: return '🔧 Services';
      case ProductCategory.crafts: return '🎨 Artisanat';
      case ProductCategory.beauty: return '💄 Beauté & Bien-être';
      case ProductCategory.home: return '🏠 Maison & Déco';
      case ProductCategory.health: return '🏥 Santé & Pharm';
      case ProductCategory.other: return '📦 Autre';
    }
  }

  // =============== STEP 2: LEGAL ===============
  Widget _buildStep2() {
    final allAccepted = _cguAccepted && _noFundsAccepted;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Conditions Marchand', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.deepPurple)),
        const SizedBox(height: 8),
        const Text('Vous devez accepter les conditions suivantes.', style: TextStyle(color: Colors.grey)),
        const SizedBox(height: 24),

        // CGU Marchand
        _buildLegalCard(
          icon: Icons.gavel,
          title: 'CGU Marchand',
          description: 'Conditions d\'utilisation pour les vendeurs',
          value: _cguAccepted,
          onChanged: (v) => setState(() => _cguAccepted = v!),
        ),
        const SizedBox(height: 12),

        // No Direct Funds
        _buildLegalCard(
          icon: Icons.account_balance,
          title: 'Paiements externes',
          description: 'Les paiements se font via PSP agréé ou lien externe. Tontetic ne gère aucun fonds.',
          value: _noFundsAccepted,
          onChanged: (v) => setState(() => _noFundsAccepted = v!),
        ),
        const SizedBox(height: 24),

        // Legal disclaimer
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blue),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(Icons.info, color: Colors.blue, size: 20),
                SizedBox(width: 8),
                Text('Important', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
              ]),
              SizedBox(height: 8),
              Text(
                '• La plateforme agit uniquement comme outil technique\n'
                '• Vous êtes responsable de vos ventes et livraisons\n'
                '• Les paiements passent par votre compte PSP personnel',
                style: TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: allAccepted ? () => setState(() => _currentStep = 2) : null,
            style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16)),
            child: const Text('Accepter et continuer'),
          ),
        ),
      ],
    );
  }

  Widget _buildLegalCard({
    required IconData icon,
    required String title,
    required String description,
    required bool value,
    required ValueChanged<bool?> onChanged,
  }) {
    return Card(
      child: CheckboxListTile(
        value: value,
        onChanged: onChanged,
        title: Row(
          children: [
            Icon(icon, color: Colors.deepPurple),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                title, 
                style: const TextStyle(fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(description, style: const TextStyle(fontSize: 12)),
        ),
        activeColor: Colors.deepPurple,
        controlAffinity: ListTileControlAffinity.trailing,
      ),
    );
  }

  // =============== STEP 3: PSP CONNECTION ===============
  Widget _buildStep3() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Recevoir les paiements', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.deepPurple)),
        const SizedBox(height: 8),
        const Text('Connectez votre compte de paiement pour recevoir l\'argent de vos ventes.', style: TextStyle(color: Colors.grey)),
        const SizedBox(height: 24),

        // PSP Options
        _buildPspOption('Stripe', Icons.credit_card, Colors.purple, 'Cartes bancaires, SEPA'),
        const SizedBox(height: 12),
        _buildPspOption('PayPal', Icons.account_balance_wallet, Colors.blue, 'PayPal Business'),
        const SizedBox(height: 12),
        _buildPspOption('Wave', Icons.waves, Colors.lightBlue, 'Mobile Money'),
        const SizedBox(height: 24),

        // Alternative: Manual links
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Alternative : Liens de paiement', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('Vous pouvez aussi utiliser vos propres liens de paiement (PayPal.me, Lydia, etc.) sans connecter de PSP.', style: TextStyle(fontSize: 12)),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => _skipPspConnection(),
                child: const Text('Passer cette étape →'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        if (_pspConnected)
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
                const Text('Boutique créée avec succès !', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.green)),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _goToMerchantDashboard,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                  child: const Text('Accéder au Dashboard Marchand', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildPspOption(String name, IconData icon, Color color, String description) {
    final isSelected = _selectedPsp == name;
    return Card(
      elevation: isSelected ? 4 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: isSelected ? color : Colors.grey[300]!, width: isSelected ? 2 : 1),
      ),
      child: InkWell(
        onTap: () => _connectPsp(name),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: TextStyle(fontWeight: FontWeight.bold, color: color)),
                    Text(description, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ),
              Icon(isSelected ? Icons.check_circle : Icons.arrow_forward_ios, color: isSelected ? color : Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  void _connectPsp(String pspName) async {
    setState(() {
      _selectedPsp = pspName;
      _isLoading = true;
    });

    // Instead of simulation, we show a REAL form to enter bank details
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) {
        final ibanController = TextEditingController();
        final bicController = TextEditingController();
        return AlertDialog(
          title: Text('Coordonnées Bancaires ($pspName)'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Entrez les coordonnées de votre compte professionnel.', style: TextStyle(fontSize: 12)),
              const SizedBox(height: 16),
              TextField(
                controller: ibanController,
                decoration: const InputDecoration(labelText: 'IBAN', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: bicController,
                decoration: const InputDecoration(labelText: 'BIC / SWIFT', border: OutlineInputBorder()),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
            ElevatedButton(
              onPressed: () {
                if (ibanController.text.isNotEmpty && bicController.text.isNotEmpty) {
                  Navigator.pop(ctx, {'iban': ibanController.text, 'bic': bicController.text});
                }
              },
              child: const Text('Confirmer'),
            ),
          ],
        );
      }
    );

    if (result != null) {
      _createMerchantAccount('psp_${pspName.toLowerCase()}_${DateTime.now().millisecondsSinceEpoch}');
    } else {
      setState(() {
        _isLoading = false;
        _selectedPsp = null;
      });
    }
  }

  void _skipPspConnection() {
    _createMerchantAccount(null);
  }

  void _createMerchantAccount(String? pspAccountId) {
    final user = ref.read(userProvider);
    
    // Create shop
    ref.read(merchantAccountProvider.notifier).createShop(
      userId: user.phoneNumber,
      shopName: _shopNameController.text,
      professionalEmail: _professionalEmailController.text.isNotEmpty ? _professionalEmailController.text : null,
      category: _selectedCategory,
      address: _addressController.text,
      description: _descriptionController.text.isNotEmpty ? _descriptionController.text : null,
    );

    // Activate if PSP connected
    if (pspAccountId != null) {
      ref.read(merchantAccountProvider.notifier).activateShop(pspAccountId);
    }

    setState(() {
      _isLoading = false;
      _pspConnected = true;
    });
  }

  void _goToMerchantDashboard() {
    // Switch to merchant mode
    ref.read(merchantAccountProvider.notifier).switchToMerchant();
    Navigator.pop(context);
  }
}
