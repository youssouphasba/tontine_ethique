import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tontetic/core/models/user_model.dart';
import 'package:tontetic/core/theme/app_theme.dart';
import 'package:tontetic/core/providers/user_provider.dart';
import 'package:tontetic/core/services/stripe_service.dart';
import 'package:tontetic/core/services/merchant_account_service.dart';
import 'package:tontetic/core/models/plan_model.dart';
import 'package:tontetic/core/providers/plans_provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';

/// Écran d'inscription marchand avec choix du type de compte
class MerchantRegistrationScreen extends ConsumerStatefulWidget {
  const MerchantRegistrationScreen({super.key});

  @override
  ConsumerState<MerchantRegistrationScreen> createState() => _MerchantRegistrationScreenState();
}

class _MerchantRegistrationScreenState extends ConsumerState<MerchantRegistrationScreen> {
  MerchantType _selectedType = MerchantType.particulier;
  String? _selectedPlanId;
  final _formKey = GlobalKey<FormState>();
  
  // Champs communs
  final _emailController = TextEditingController();
  final _pspAccountController = TextEditingController();
  
  // Champs Vérifié uniquement
  final _siretController = TextEditingController();
  final _ibanController = TextEditingController();
  
  // Document upload state
  bool _idUploaded = false;
  bool _selfieUploaded = false;
  String? _idDocumentUrl;
  String? _selfieUrl;
  bool _isUploadingId = false;
  bool _isUploadingSelfie = false;
  
  bool _cguAccepted = false;
  bool _isSubmitting = false;
  
  final ImagePicker _imagePicker = ImagePicker();
  final FirebaseStorage _storage = FirebaseStorage.instance;

  @override
  void dispose() {
    _emailController.dispose();
    _pspAccountController.dispose();
    _siretController.dispose();
    _ibanController.dispose();
    super.dispose();
  }

  /// Upload document to Firebase Storage
  Future<String?> _uploadDocument({
    required String userId,
    required String docType, // 'id' or 'selfie'
    bool fromCamera = false,
  }) async {
    try {
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: fromCamera ? ImageSource.camera : ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );
      
      if (pickedFile == null) return null;

      // Update loading state
      setState(() {
        if (docType == 'id') {
          _isUploadingId = true;
        } else {
          _isUploadingSelfie = true;
        }
      });

      // Create unique filename with timestamp
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = '${docType}_${userId}_$timestamp.jpg';
      final ref = _storage.ref().child('merchant_kyc/$userId/$fileName');
      
      // Upload the file
      late UploadTask uploadTask;
      
      if (kIsWeb) {
        // Web upload
        final bytes = await pickedFile.readAsBytes();
        uploadTask = ref.putData(
          bytes, 
          SettableMetadata(contentType: 'image/jpeg'),
        );
      } else {
        // Mobile upload
        uploadTask = ref.putFile(
          File(pickedFile.path),
          SettableMetadata(contentType: 'image/jpeg'),
        );
      }

      // Wait for upload to complete
      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();
      
      debugPrint('[MERCHANT] ✅ Uploaded $docType: $downloadUrl');
      return downloadUrl;
      
    } catch (e) {
      debugPrint('[MERCHANT] ❌ Upload error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors du téléchargement: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return null;
    } finally {
      if (mounted) {
        setState(() {
          if (docType == 'id') {
            _isUploadingId = false;
          } else {
            _isUploadingSelfie = false;
          }
        });
      }
    }
  }

  void _showUploadOptions(String docType) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera, color: AppTheme.marineBlue),
              title: const Text('Prendre une photo'),
              onTap: () async {
                Navigator.pop(ctx);
                final user = ref.read(userProvider);
                final url = await _uploadDocument(
                  userId: user.phoneNumber,
                  docType: docType,
                  fromCamera: true,
                );
                if (url != null) {
                  setState(() {
                    if (docType == 'id') {
                      _idDocumentUrl = url;
                      _idUploaded = true;
                    } else {
                      _selfieUrl = url;
                      _selfieUploaded = true;
                    }
                  });
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: AppTheme.marineBlue),
              title: const Text('Choisir depuis la galerie'),
              onTap: () async {
                Navigator.pop(ctx);
                final user = ref.read(userProvider);
                final url = await _uploadDocument(
                  userId: user.phoneNumber,
                  docType: docType,
                  fromCamera: false,
                );
                if (url != null) {
                  setState(() {
                    if (docType == 'id') {
                      _idDocumentUrl = url;
                      _idUploaded = true;
                    } else {
                      _selfieUrl = url;
                      _selfieUploaded = true;
                    }
                  });
                }
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _submitRegistration() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_cguAccepted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez accepter les CGU marchands')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final user = ref.read(userProvider);
    final notifier = ref.read(merchantAccountProvider.notifier);

    MerchantAccount? account;

    // 1. Auto-create Stripe Connect Account
    String connectAccountId = _pspAccountController.text;
    
    try {
      // If user didn't provide a manual ID, create one automatically
      if (connectAccountId.isEmpty) {
        connectAccountId = await StripeService.createConnectAccount(
          email: _emailController.text,
          userId: user.phoneNumber, // Using phone as ID for now, ideally uid
          firstName: 'Marchand', // Should get from User model
          lastName: user.phoneNumber,
        );
        debugPrint('Stripe Connect Account Created: $connectAccountId');
      }
    } catch (e) {
      debugPrint('Error creating Stripe Connect: $e');
      // Continue without connect ID or show error? For now continue creates "manual" merchant
    }

    if (_selectedType == MerchantType.particulier) {
      account = await notifier.createParticulierAccount(
        userId: user.phoneNumber,
        email: _emailController.text,
        pspAccountId: connectAccountId,
      );
    } else {
      if (!_idUploaded || !_selfieUploaded) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Veuillez télécharger tous les documents requis')),
        );
        setState(() => _isSubmitting = false);
        return;
      }

      if (_idDocumentUrl == null || _selfieUrl == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erreur: documents non uploadés correctement')),
        );
        setState(() => _isSubmitting = false);
        return;
      }

      account = await notifier.createVerifieAccount(
        userId: user.phoneNumber,
        email: _emailController.text,
        siretNinea: _siretController.text,
        idDocumentUrl: _idDocumentUrl!,
        selfieUrl: _selfieUrl!,
        pspAccountId: connectAccountId,
        iban: _ibanController.text.isNotEmpty ? _ibanController.text : null,
      );
    }

    setState(() => _isSubmitting = false);

    if (account != null && mounted) {
      _showSuccessDialog();
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(
              _selectedType == MerchantType.particulier 
                  ? Icons.person : Icons.verified,
              color: AppTheme.gold,
            ),
            const SizedBox(width: 12),
            const Expanded(child: Text('Compte créé !')),
          ],
        ),
        content: Text(
          _selectedType == MerchantType.particulier
              ? 'Votre compte Particulier est actif. Vous pouvez publier jusqu\'à 5 annonces.'
              : 'Votre demande de compte Vérifié est en cours de traitement. Vous recevrez une confirmation sous 48h.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(userProvider);
    final plansAsyncValue = ref.watch(merchantPlansProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Devenir Marchand'),
        backgroundColor: AppTheme.marineBlue,
        foregroundColor: Colors.white,
      ),
      body: plansAsyncValue.when(
        data: (plans) {
          // Auto-select first plan
          if (_selectedPlanId == null && plans.isNotEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              setState(() {
                _selectedPlanId = plans.first.id;
                _selectedType = plans.first.id.contains('verifie') 
                    ? MerchantType.verifie 
                    : MerchantType.particulier;
              });
            });
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header explicatif
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppTheme.marineBlue, Color(0xFF152642)],
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Column(
                      children: [
                        Icon(Icons.storefront, color: AppTheme.gold, size: 48),
                        SizedBox(height: 12),
                        Text(
                          'Vendez sur Tontetic',
                          style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Touchez notre communauté de tontiniers. Paiements hors plateforme = zéro commission !',
                          style: TextStyle(color: Colors.white70, fontSize: 13),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Choix du type de compte
                  const Text('Type de compte', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),

                  // Dynamic Plan Cards
                  ...plans.map((plan) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _buildDynamicTypeCard(
                      plan: plan,
                      user: user,
                    ),
                  )),

                  const SizedBox(height: 24),

              // Formulaire
              const Text('Informations', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),

              // Email
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email professionnel',
                  prefixIcon: Icon(Icons.email),
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (v) => (v?.isEmpty ?? true) ? 'Email requis' : null,
              ),

              const SizedBox(height: 16),

              // Compte PSP
              TextFormField(
                controller: _pspAccountController,
                decoration: const InputDecoration(
                  labelText: 'Identifiant Stripe/Wave',
                  prefixIcon: Icon(Icons.account_balance_wallet),
                  border: OutlineInputBorder(),
                  helperText: 'Pour recevoir vos paiements hors plateforme',
                ),
                validator: (v) => (v?.isEmpty ?? true) ? 'Compte PSP requis' : null,
              ),

              // Champs supplémentaires pour Vérifié
              if (_selectedType == MerchantType.verifie) ...[
                const SizedBox(height: 16),

                TextFormField(
                  controller: _siretController,
                  decoration: const InputDecoration(
                    labelText: 'SIRET / NINEA',
                    prefixIcon: Icon(Icons.business),
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => (v?.isEmpty ?? true) ? 'SIRET/NINEA requis' : null,
                ),

                const SizedBox(height: 16),

                TextFormField(
                  controller: _ibanController,
                  decoration: const InputDecoration(
                    labelText: 'IBAN (optionnel)',
                    prefixIcon: Icon(Icons.credit_card),
                    border: OutlineInputBorder(),
                    helperText: 'Pour remboursements d\'abonnement uniquement',
                  ),
                ),

                const SizedBox(height: 16),

                // Upload documents
                const Text('Documents requis', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),

                _buildUploadButton(
                  label: 'Pièce d\'identité',
                  uploaded: _idUploaded,
                  isUploading: _isUploadingId,
                  onTap: () => _showUploadOptions('id'),
                ),

                const SizedBox(height: 8),

                _buildUploadButton(
                  label: 'Selfie avec pièce d\'identité',
                  uploaded: _selfieUploaded,
                  isUploading: _isUploadingSelfie,
                  onTap: () => _showUploadOptions('selfie'),
                ),
              ],

              const SizedBox(height: 24),

              // CGU
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark ? Colors.orange.withAlpha(51) : Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Theme.of(context).brightness == Brightness.dark ? Colors.orange.withAlpha(102) : Colors.orange.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '⚠️ Important - Transactions hors plateforme',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tontetic est une plateforme de mise en relation uniquement. '
                      'Toutes les transactions commerciales se font HORS de l\'application, '
                      'directement entre vous et l\'acheteur. '
                      'Tontetic ne prélève aucune commission sur vos ventes.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).brightness == Brightness.dark ? Colors.orange.shade100 : Colors.orange.shade900,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 12),
                    CheckboxListTile(
                      value: _cguAccepted,
                      onChanged: (v) => setState(() => _cguAccepted = v ?? false),
                      title: const Text(
                        'J\'accepte les conditions marchands',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Bouton submit
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitRegistration,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.gold,
                    foregroundColor: AppTheme.marineBlue,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          _selectedType == MerchantType.particulier
                              ? 'CRÉER MON COMPTE GRATUIT'
                              : 'SOUMETTRE MA DEMANDE',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                ),
              ),

              const SizedBox(height: 16),
                ],
              ),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erreur: $e')),
      ),
    );
  }

  Widget _buildDynamicTypeCard({
    required Plan plan,
    required UserState user,
  }) {
    final isVerifie = plan.id.contains('verifie');
    final isSelected = _selectedPlanId == plan.id;
    final icon = isVerifie ? Icons.verified : Icons.person;
    
    // Get price label from plan in user's currency
    final price = plan.getPrice(user.zone.currency == 'FCFA' ? 'XOF' : 'EUR');
    final priceLabel = price > 0 
        ? '${price.toStringAsFixed(0)} ${user.zone.currency}/mois'
        : 'Gratuit';

    return InkWell(
      onTap: () => setState(() {
        _selectedPlanId = plan.id;
        _selectedType = isVerifie ? MerchantType.verifie : MerchantType.particulier;
      }),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.marineBlue.withAlpha(20) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppTheme.marineBlue : Colors.transparent,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSelected ? AppTheme.marineBlue : Colors.grey.shade400,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: Colors.white, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(child: Text(plan.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16), overflow: TextOverflow.ellipsis)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.gold,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(priceLabel, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // plan.features is non-nullable
                    ...plan.features.take(3).map((f) => Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Row(
                        children: [
                          const Icon(Icons.check, size: 14, color: Colors.green),
                          const SizedBox(width: 4),
                          Text(f, style: const TextStyle(fontSize: 12)),
                        ],
                      ),
                    )),
                ],
              ),
            ),
            Radio<String>(
              value: plan.id,
              // ignore: deprecated_member_use
              groupValue: _selectedPlanId,
              // ignore: deprecated_member_use
              onChanged: (value) => setState(() {
                _selectedPlanId = value!;
                _selectedType = value.contains('verifie') ? MerchantType.verifie : MerchantType.particulier;
              }),
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUploadButton({
    required String label,
    required bool uploaded,
    required bool isUploading,
    required VoidCallback onTap,
  }) {
    return OutlinedButton.icon(
      onPressed: (uploaded || isUploading) ? null : onTap,
      icon: isUploading 
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(
              uploaded ? Icons.check_circle : Icons.upload_file,
              color: uploaded ? Colors.green : AppTheme.marineBlue,
            ),
      label: Text(
        isUploading 
            ? 'Upload en cours...'
            : (uploaded ? '$label ✓' : label),
        style: TextStyle(
          color: uploaded ? Colors.green : AppTheme.marineBlue,
        ),
      ),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        side: BorderSide(
          color: isUploading 
              ? Colors.grey 
              : (uploaded ? Colors.green : AppTheme.marineBlue),
        ),
      ),
    );
  }
}
