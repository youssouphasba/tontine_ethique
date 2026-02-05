import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tontetic/core/theme/app_theme.dart';
import 'package:tontetic/core/providers/merchant_account_provider.dart';
import 'package:tontetic/core/providers/user_provider.dart';
import 'package:tontetic/core/services/stripe_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/foundation.dart'; // for kIsWeb

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
              child: const Center(child: CircularProgressIndicator(color: Colors.white)),
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
      case 1: return _buildStep2(); // Legal Step
      case 2: return _buildPaymentStep(); // Payment Step
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
  
  // =============== STEP 3: PAYMENT ===============
  Widget _buildPaymentStep() {
    // HARDCODED PRICE ID from User request
    const priceId = 'price_1SvMLDCpguZvNb1ULfsoGWof';
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Frais d\'inscription', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.deepPurple)),
        const SizedBox(height: 16),
        
        Container(
           padding: const EdgeInsets.all(24),
           width: double.infinity,
           decoration: BoxDecoration(
             color: Colors.white,
             borderRadius: BorderRadius.circular(16),
             boxShadow: [
               BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4)),
             ],
             border: Border.all(color: Colors.deepPurple.withValues(alpha: 0.1)),
           ),
           child: Column(
             children: [
               const Icon(Icons.workspace_premium, size: 48, color: Colors.deepPurple),
               const SizedBox(height: 16),
               const Text('Compte Marchand', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
               const SizedBox(height: 8),
               const Text('Accès illimité à la création de boutique', style: TextStyle(color: Colors.grey)),
               const SizedBox(height: 24),
               const Text('9.99 €', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.deepPurple)),
               const Text('/ mois', style: TextStyle(color: Colors.grey)),
               const SizedBox(height: 32),
               
               SizedBox(
                 width: double.infinity,
                 child: ElevatedButton(
                   onPressed: () => _payAndCreateShop(priceId),
                   style: ElevatedButton.styleFrom(
                     backgroundColor: Colors.deepPurple,
                     foregroundColor: Colors.white,
                     padding: const EdgeInsets.symmetric(vertical: 16),
                     shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                   ),
                   child: const Row(
                     mainAxisAlignment: MainAxisAlignment.center,
                     children: [
                       Icon(Icons.payment),
                       SizedBox(width: 8),
                       Text('Payer l\'inscription'),
                     ],
                   ),
                 ),
               ),
               const SizedBox(height: 16),
               const Text('Paiement sécurisé par Stripe', style: TextStyle(fontSize: 10, color: Colors.grey)),
             ],
           ),
        ),
      ],
    );
  }

  Future<void> _payAndCreateShop(String priceId) async {
    setState(() => _isLoading = true);
    
    try {
      final user = ref.read(userProvider);
      
      // 1. Create Shop (Pending Payment)
      // This allows us to have a 'shopId' to reference in the payment
      final shopId = await ref.read(merchantAccountProvider.notifier).createShop(
        userId: user.uid.isNotEmpty ? user.uid : user.phoneNumber,
        shopName: _shopNameController.text,
        professionalEmail: _professionalEmailController.text.isNotEmpty ? _professionalEmailController.text : null,
        category: _selectedCategory,
        address: _addressController.text,
        description: _descriptionController.text.isNotEmpty ? _descriptionController.text : null,
      );
      
      // 2. Prepare Success URL with TYPE=merchant and SHOP_ID
      // This tells PaymentSuccessScreen to activate this specific shop
      final successUrl = kIsWeb 
          ? 'https://tontetic-app.web.app/payment/success?type=merchant&shopId=$shopId'
          : 'tontetic://payment/success?type=merchant&shopId=$shopId';
          
      final cancelUrl = kIsWeb
          ? 'https://tontetic-app.web.app/payment/cancel' // Just go back to dashboard/cancel
          : 'tontetic://payment/cancel';
      
      // 3. Create Checkout Session
      final url = await StripeService.createCheckoutSession(
        priceId: priceId,
        email: user.email,
        customerId: user.stripeCustomerId,
        userId: user.uid,
        successUrl: successUrl, // Redirect here on success
        cancelUrl: cancelUrl,
      );
      
      // 4. Launch Payment
      if (await canLaunchUrl(Uri.parse(url))) {
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      } else {
        throw Exception("Impossible d'ouvrir le lien de paiement");
      }
      
      // 5. Close this screen (User will return via Deep Link to Success Screen)
      if (mounted) {
         Navigator.pop(context); // Close Registration Screen
      }
      
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}
