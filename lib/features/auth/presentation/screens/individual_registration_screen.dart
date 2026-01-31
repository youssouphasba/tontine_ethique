import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tontetic/core/theme/app_theme.dart';
import 'package:tontetic/core/providers/user_provider.dart';
import 'package:tontetic/core/providers/consent_provider.dart';
import 'package:tontetic/core/providers/auth_provider.dart';
import 'package:go_router/go_router.dart';
import 'package:tontetic/core/services/auth_service.dart';
import 'package:tontetic/features/auth/presentation/widgets/otp_dialog.dart';


import 'package:tontetic/core/constants/legal_texts.dart';
import 'package:tontetic/features/dashboard/presentation/screens/dashboard_screen.dart';

/// Individual Registration Screen
/// 3-step compliant registration flow for Particuliers
/// 
/// Step 1: Inscription minimale (nom, email, tel, mdp)
/// Step 2: Acceptation légale (CGU, Privacy, Charte)
/// Step 3: Profil non financier (photo, pseudo, bio)

class IndividualRegistrationScreen extends ConsumerStatefulWidget {
  final bool skipEmailStep;
  
  const IndividualRegistrationScreen({super.key, this.skipEmailStep = false});

  @override
  ConsumerState<IndividualRegistrationScreen> createState() => _IndividualRegistrationScreenState();
}

class _IndividualRegistrationScreenState extends ConsumerState<IndividualRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  int _currentStep = 0;
  bool _isLoading = false;
  bool _emailVerified = false;
  bool _phoneVerified = false;

  // Step 1: Inscription minimale
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  String _selectedCountryCode = '+33';
  bool _showPassword = false;

  @override
  void initState() {
    super.initState();
    // If coming from Google Sign-In, skip email step and pre-fill data
    if (widget.skipEmailStep) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final user = ref.read(userProvider);
        final firebaseUser = FirebaseAuth.instance.currentUser;
        
        // 1. Pre-fill Email
        if (user.email.isNotEmpty) {
          _emailController.text = user.email;
          _emailVerified = true;
        } else if (firebaseUser?.email != null) {
          _emailController.text = firebaseUser!.email!;
          _emailVerified = true;
        }
        
        // 2. Pre-fill Name
        if (user.displayName.isNotEmpty) {
          final parts = user.displayName.split(' ');
          _firstNameController.text = parts.first;
          if (parts.length > 1) {
            _lastNameController.text = parts.sublist(1).join(' ');
          }
        } else if (firebaseUser?.displayName != null) {
          final parts = firebaseUser!.displayName!.split(' ');
          _firstNameController.text = parts.first;
          if (parts.length > 1) {
            _lastNameController.text = parts.sublist(1).join(' ');
          }
        }
        
        // Ensure UI updates if we filled data
        if (mounted) setState(() {});
      });
    }
  }

  // Step 2: Acceptation légale
  bool _cguAccepted = false;
  bool _privacyAccepted = false;
  bool _charterAccepted = false;

  // Step 3: Profil non financier
  final _pseudoController = TextEditingController();
  final _bioController = TextEditingController();

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _pseudoController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // backgroundColor: AppTheme.offWhite, // Removed to respect theme brightness
      appBar: AppBar(
        title: Text(_getStepTitle()),
        backgroundColor: AppTheme.marineBlue,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _currentStep > 0 ? () => setState(() => _currentStep--) : () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // Progress indicator
          _buildProgressBar(),
          
          // Content
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
    );
  }

  String _getStepTitle() {
    switch (_currentStep) {
      case 0: return 'Étape 1/3 — Inscription';
      case 1: return 'Étape 2/3 — Conditions';
      case 2: return 'Étape 3/3 — Profil';
      default: return 'Inscription';
    }
  }

  Widget _buildProgressBar() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      child: Row(
        children: [
          _buildProgressDot(0, '1'),
          Expanded(child: Container(height: 2, color: _currentStep >= 1 ? AppTheme.gold : (isDark ? Colors.white12 : Colors.grey[300]))),
          _buildProgressDot(1, '2'),
          Expanded(child: Container(height: 2, color: _currentStep >= 2 ? AppTheme.gold : (isDark ? Colors.white12 : Colors.grey[300]))),
          _buildProgressDot(2, '3'),
        ],
      ),
    );
  }

  Widget _buildProgressDot(int step, String label) {
    final isActive = _currentStep >= step;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isActive ? AppTheme.gold : (isDark ? Colors.white12 : Colors.grey[300]),
      ),
      child: Center(
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? Colors.white : (isDark ? Colors.white38 : Colors.grey[600]),
            fontWeight: FontWeight.bold,
          ),
        ),
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

  // =============== STEP 1: INSCRIPTION MINIMALE ===============
  Widget _buildStep1() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.skipEmailStep ? 'Complétez votre profil' : 'Inscription minimale',
          style: TextStyle(
            fontSize: 22, 
            fontWeight: FontWeight.bold, 
            color: Theme.of(context).brightness == Brightness.dark ? AppTheme.gold : AppTheme.marineBlue,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.green.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Row(
            children: [
              Icon(Icons.verified_user, color: Colors.green),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  '✅ Utilisez vos vraies informations pour bénéficier de la protection communautaire et établir votre Score d\'Honneur.',
                  style: TextStyle(fontSize: 12, color: Colors.green),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Prénom
        TextFormField(
          controller: _firstNameController,
          decoration: const InputDecoration(
            labelText: 'Prénom',
            prefixIcon: Icon(Icons.person_outline),
            border: OutlineInputBorder(),
          ),
          validator: (v) => v!.isEmpty ? 'Requis' : null,
        ),
        const SizedBox(height: 16),

        // Nom
        TextFormField(
          controller: _lastNameController,
          decoration: const InputDecoration(
            labelText: 'Nom',
            prefixIcon: Icon(Icons.person),
            border: OutlineInputBorder(),
          ),
          validator: (v) => v!.isEmpty ? 'Requis' : null,
        ),
        const SizedBox(height: 16),

        // Email
        TextFormField(
          controller: _emailController,
          enabled: !widget.skipEmailStep, // Disable edit if from Google
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(
            labelText: 'Email',
            prefixIcon: const Icon(Icons.email_outlined),
            border: const OutlineInputBorder(),
            suffixIcon: widget.skipEmailStep
                ? const Icon(Icons.check_circle, color: Colors.green)
                : const Icon(Icons.email, color: Colors.grey),
          ),
          validator: (v) {
            if (v!.isEmpty) return 'Requis';
            if (!v.contains('@')) return 'Email invalide';
            return null;
          },
        ),
        const SizedBox(height: 16),

        // Téléphone
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                border: Border.all(color: Theme.of(context).brightness == Brightness.dark ? Colors.white24 : Colors.grey),
                borderRadius: BorderRadius.circular(4),
              ),
              child: DropdownButton<String>(
                value: _selectedCountryCode,
                underline: const SizedBox(),
                items: const [
                  DropdownMenuItem(value: '+221', child: Text('🇸🇳 +221')),
                  DropdownMenuItem(value: '+33', child: Text('🇫🇷 +33')),
                  DropdownMenuItem(value: '+225', child: Text('🇨🇮 +225')),
                ],
                onChanged: (v) => setState(() => _selectedCountryCode = v!),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: 'Numéro de téléphone',
                  border: const OutlineInputBorder(),
                  suffixIcon: _phoneVerified
                      ? const Icon(Icons.check_circle, color: Colors.green)
                      : TextButton(
                          onPressed: _verifyPhone,
                          child: const Text('Vérifier'),
                        ),
                ),
                validator: (v) => v!.isEmpty ? 'Requis' : null,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        if (!widget.skipEmailStep) ...[
          const SizedBox(height: 16),
          // Mot de passe
          TextFormField(
            controller: _passwordController,
            obscureText: !_showPassword,
            decoration: InputDecoration(
              labelText: 'Mot de passe',
              prefixIcon: const Icon(Icons.lock_outline),
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: Icon(_showPassword ? Icons.visibility_off : Icons.visibility),
                onPressed: () => setState(() => _showPassword = !_showPassword),
              ),
            ),
            validator: (v) {
              if (v!.isEmpty) return 'Requis';
              if (v.length < 8) return 'Minimum 8 caractères';
              return null;
            },
          ),
          const SizedBox(height: 8),
          _buildPasswordStrength(),
          const SizedBox(height: 16),

          // Confirmation mot de passe
          TextFormField(
            controller: _confirmPasswordController,
            obscureText: !_showPassword,
            decoration: const InputDecoration(
              labelText: 'Confirmer le mot de passe',
              prefixIcon: Icon(Icons.lock),
              border: OutlineInputBorder(),
            ),
            validator: (v) {
              if (v != _passwordController.text) return 'Les mots de passe ne correspondent pas';
              return null;
            },
          ),
          const SizedBox(height: 8),
        ],

        // Forgot password
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Un email de réinitialisation sera envoyé à votre adresse')),
              );
            },
            child: Text(
              'Mot de passe oublié ?', 
              style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.white38 : Colors.grey),
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _goToStep2,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.gold,
              foregroundColor: AppTheme.marineBlue,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: _isLoading
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Continuer', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }

  Widget _buildPasswordStrength() {
    final password = _passwordController.text;
    int strength = 0;
    if (password.length >= 8) strength++;
    if (password.contains(RegExp(r'[A-Z]'))) strength++;
    if (password.contains(RegExp(r'[0-9]'))) strength++;
    if (password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) strength++;

    Color color = Colors.red;
    String label = 'Faible';
    if (strength >= 4) { color = Colors.green; label = 'Excellent'; }
    else if (strength >= 3) { color = Colors.green; label = 'Fort'; }
    else if (strength >= 2) { color = Colors.orange; label = 'Moyen'; }

    return Row(
      children: [
        Expanded(
          child: LinearProgressIndicator(
            value: strength / 4,
            backgroundColor: Theme.of(context).brightness == Brightness.dark ? Colors.white10 : Colors.grey[300],
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
        const SizedBox(width: 8),
        Text(label, style: TextStyle(color: color, fontSize: 12)),
      ],
    );
  }



  void _verifyPhone() async {
    if (_phoneController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez entrer un numéro')),
      );
      return;
    }

    // Strip leading zero from the local number before adding country code
    String localNumber = _phoneController.text.trim();
    if (localNumber.startsWith('0')) {
      localNumber = localNumber.substring(1);
    }
    final fullPhone = '$_selectedCountryCode$localNumber';
    
    setState(() => _isLoading = true);
    
    final authService = ref.read(authServiceProvider);
    final result = await authService.sendOtp(fullPhone);
    
    setState(() => _isLoading = false);

    if (!result.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur envoi SMS: ${result.error}'), backgroundColor: Colors.red),
      );
      return;
    }
    
    if (!mounted) return;

    // Show new reusable OTP dialog
    final otpResult = await OtpDialog.show(context, phone: fullPhone);

    if (!mounted) return;

    if (otpResult == 'SUCCESS') {
      setState(() => _phoneVerified = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Téléphone vérifié !'), backgroundColor: Colors.green),
      );
    }
  }

  void _goToStep2() {
    if (_formKey.currentState!.validate()) {
      if (!_phoneVerified) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⚠️ Veuillez vérifier votre numéro par OTP pour continuer.'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
      setState(() => _currentStep = 1);
    }
  }

  // =============== STEP 2: ACCEPTATION LÉGALE ===============
  Widget _buildStep2() {
    final allAccepted = _cguAccepted && _privacyAccepted && _charterAccepted;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Acceptation légale',
          style: TextStyle(
            fontSize: 22, 
            fontWeight: FontWeight.bold, 
            color: Theme.of(context).brightness == Brightness.dark ? AppTheme.gold : AppTheme.marineBlue,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Avant d\'accéder à l\'application, veuillez lire et accepter les documents suivants.',
          style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.white60 : Colors.grey),
        ),
        const SizedBox(height: 24),

        // CGU
        _buildLegalCheckbox(
          title: 'Conditions Générales d\'Utilisation',
          subtitle: 'Version 1.2 — Janvier 2026',
          value: _cguAccepted,
          onChanged: (v) => setState(() => _cguAccepted = v!),
          onRead: () => _showLegalDocument('CGU', LegalTexts.cgu),
        ),
        const SizedBox(height: 16),

        // Privacy
        _buildLegalCheckbox(
          title: 'Politique de Confidentialité',
          subtitle: 'RGPD conforme',
          value: _privacyAccepted,
          onChanged: (v) => setState(() => _privacyAccepted = v!),
          onRead: () => _showLegalDocument('Confidentialité', LegalTexts.privacyPolicy),
        ),
        const SizedBox(height: 16),

        // Charter
        _buildLegalCheckbox(
          title: 'Charte des Tontines',
          subtitle: 'Règles de fonctionnement',
          value: _charterAccepted,
          onChanged: (v) => setState(() => _charterAccepted = v!),
          onRead: () => _showLegalDocument('Charte Tontines', _getTontineCharter()),
        ),
        const SizedBox(height: 32),

        // Warning
        if (!allAccepted)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange),
            ),
            child: const Row(
              children: [
                Icon(Icons.warning, color: Colors.orange),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Vous devez accepter tous les documents pour continuer.',
                    style: TextStyle(color: Colors.orange, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 24),

        // Button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: allAccepted ? _goToStep3 : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.gold,
              foregroundColor: AppTheme.marineBlue,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: const Text('Continuer', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }

  Widget _buildLegalCheckbox({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool?> onChanged,
    required VoidCallback onRead,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2C2C2C) : Colors.white,
        border: Border.all(color: value ? AppTheme.gold : (isDark ? Colors.white12 : Colors.grey[400]!)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          CheckboxListTile(
            value: value,
            onChanged: onChanged,
            title: Text(
              title, 
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : AppTheme.marineBlue,
                fontSize: 15,
              ),
            ),
            subtitle: Text(
              subtitle, 
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white60 : Colors.grey[700],
              ),
            ),
            activeColor: AppTheme.gold,
            checkColor: AppTheme.marineBlue,
            controlAffinity: ListTileControlAffinity.leading,
          ),
          Padding(
            padding: const EdgeInsets.only(left: 16, right: 16, bottom: 12),
            child: TextButton.icon(
              onPressed: onRead,
              icon: const Icon(Icons.description, size: 16, color: AppTheme.gold),
              label: const Text(
                'Lire le document complet',
                style: TextStyle(color: AppTheme.gold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showLegalDocument(String title, String content) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.8,
        expand: false,
        builder: (_, scrollController) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
            ),
            const Divider(),
            Expanded(
              child: SingleChildScrollView(
                controller: scrollController,
                padding: const EdgeInsets.all(16),
                child: Text(content, style: const TextStyle(height: 1.6)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getTontineCharter() {
    return '''
CHARTE DE FONCTIONNEMENT DES TONTINES

1. PRINCIPE DE SOLIDARITÉ
La tontine repose sur la confiance mutuelle et l'engagement de chaque membre à respecter ses obligations.

2. ENGAGEMENTS DU MEMBRE
- Verser sa cotisation aux dates prévues
- Respecter l'ordre de passage défini
- Signaler tout problème à l'avance
- Participer aux votes de gouvernance

3. SANCTIONS
En cas de défaut de paiement :
- Premier retard : Rappel automatique
- Deuxième retard : Avertissement
- Troisième retard : Exclusion possible + impact Score d'Honneur

4. PROTECTION AMANAH
Une garantie SEPA conditionnelle (1 cotisation) protège les bénéficiaires en cas de défaillance. Elle n'est jamais prélevée sauf défaut avéré.

5. RÈGLEMENT DES LITIGES
Tout litige est soumis à l'arbitrage communautaire avant toute procédure externe.
''';
  }

  void _goToStep3() {
    // Record consents with timestamp
    // Note: Real IP is captured server-side via Cloud Function for RGPD compliance
    final consentNotifier = ref.read(consentProvider.notifier);
    consentNotifier.acceptCGUAndPrivacy('client-side', '1.2');
    consentNotifier.recordConsent(
      type: ConsentType.dataSharing, 
      accepted: true, 
      ipAddress: 'client-side', // Real IP captured by server
      version: '1.0',
    );
    
    setState(() => _currentStep = 2);
  }

  // =============== STEP 3: PROFIL NON FINANCIER ===============
  Widget _buildStep3() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Votre profil',
          style: TextStyle(
            fontSize: 22, 
            fontWeight: FontWeight.bold, 
            color: Theme.of(context).brightness == Brightness.dark ? AppTheme.gold : AppTheme.marineBlue,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Ces informations sont facultatives et non financières.',
          style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.white60 : Colors.grey),
        ),
        const SizedBox(height: 24),

        // Photo (facultatif)
        Center(
          child: GestureDetector(
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Fonctionnalité photo à venir...')),
              );
            },
            child: Stack(
              children: [
                CircleAvatar(
                  radius: 50,
                  backgroundColor: Theme.of(context).brightness == Brightness.dark ? Colors.white10 : Colors.grey[300],
                  child: Icon(Icons.person, size: 50, color: Theme.of(context).brightness == Brightness.dark ? Colors.white38 : Colors.grey),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      color: AppTheme.gold,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.camera_alt, size: 16, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        const Center(child: Text('Photo de profil (facultatif)', style: TextStyle(color: Colors.grey, fontSize: 12))),
        const SizedBox(height: 24),

        // Pseudonyme
        TextFormField(
          controller: _pseudoController,
          style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87),
          decoration: InputDecoration(
            labelText: 'Pseudonyme (facultatif)',
            labelStyle: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.white60 : Colors.grey[600]),
            prefixIcon: Icon(Icons.alternate_email, color: Theme.of(context).brightness == Brightness.dark ? AppTheme.gold : AppTheme.marineBlue),
            border: const OutlineInputBorder(),
            hintText: 'Ex: MoussaD',
            hintStyle: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.white24 : Colors.grey[400]),
            filled: true,
            fillColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF2C2C2C) : Colors.white,
          ),
        ),
        const SizedBox(height: 16),

        // Profession (NEW)
        TextFormField(
          style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87),
          decoration: InputDecoration(
            labelText: 'Profession (facultatif)',
            labelStyle: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.white60 : Colors.grey[600]),
            prefixIcon: Icon(Icons.work_outline, color: Theme.of(context).brightness == Brightness.dark ? AppTheme.gold : AppTheme.marineBlue),
            border: const OutlineInputBorder(),
            hintText: 'Ex: Entrepreneur, Enseignant...',
            hintStyle: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.white24 : Colors.grey[400]),
            filled: true,
            fillColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF2C2C2C) : Colors.white,
          ),
        ),
        const SizedBox(height: 16),

        // Bio
        TextFormField(
          controller: _bioController,
          maxLines: 3,
          maxLength: 150,
          style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87),
          decoration: InputDecoration(
            labelText: 'Bio (facultatif)',
            labelStyle: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.white60 : Colors.grey[600]),
            prefixIcon: Icon(Icons.edit, color: Theme.of(context).brightness == Brightness.dark ? AppTheme.gold : AppTheme.marineBlue),
            border: const OutlineInputBorder(),
            hintText: 'Parlez de vous...',
            hintStyle: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.white24 : Colors.grey[400]),
            filled: true,
            fillColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF2C2C2C) : Colors.white,
          ),
        ),
        const SizedBox(height: 24),

        // Encouragement message
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.green.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Row(
            children: [
              Icon(Icons.favorite, color: Colors.green),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  '💚 Soyez vous-même',
                  style: TextStyle(fontSize: 14, color: Colors.green, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),

        // Buttons
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _completeRegistration,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.gold,
              foregroundColor: AppTheme.marineBlue,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: _isLoading
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Créer mon compte', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: TextButton(
            onPressed: _completeRegistration,
            child: const Text('Passer cette étape'),
          ),
        ),
      ],
    );
  }

  void _completeRegistration() async {
    setState(() => _isLoading = true);
    
    // 1. Create Firebase account (Only if NOT from Google)
    if (!widget.skipEmailStep) {
      final authService = ref.read(authServiceProvider);
      final result = await authService.signUpWithEmail(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        fullName: '${_firstNameController.text} ${_lastNameController.text}',
        role: 'Membre',
      );

      if (!mounted) return;

      if (!result.success) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: ${result.error}'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }
    
    // Combine country code and phone for auto zone detection
    final fullPhone = '$_selectedCountryCode${_phoneController.text.trim()}';
    
    // Set user phone and automatically detect zone
    ref.read(userProvider.notifier).setUser(fullPhone, false);
    
    // Save additional user data to local provider
    await ref.read(userProvider.notifier).updateProfile(
      name: '${_firstNameController.text} ${_lastNameController.text}',
      address: '', // Not collected per compliance
      type: UserType.individual,
      birthDate: null,
    );

    // Set account to read-only mode
    // Account status is already readOnly by default
    
    if (!mounted) return;
    
    // Navigate to Dashboard or Show Verification Dialog
    if (!mounted) return;
    
    if (!widget.skipEmailStep) {
       // Send verification email
       final emailResult = await ref.read(authServiceProvider).sendEmailVerification();
       if (!emailResult.success) {
          debugPrint('REGISTRATION: Failed to send email: ${emailResult.error}');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Attention: Erreur envoi email: ${emailResult.error}'), backgroundColor: Colors.orange),
            );
          }
       }
       
       if (!mounted) return;
       
       // Show MANDATORY verification dialog
       await showDialog(
         context: context,
         barrierDismissible: false,
         builder: (ctx) => AlertDialog(
           title: const Text('📧 Vérification requise'),
           content: Column(
             mainAxisSize: MainAxisSize.min,
             children: [
               const Icon(Icons.mark_email_read, size: 64, color: AppTheme.marineBlue),
               const SizedBox(height: 16),
               const Text(
                 'Un email de vérification a été envoyé à votre adresse.\n\n'
                 'Veuillez cliquer sur le lien dans l\'email pour activer votre compte. '
                 'Vous pourrez ensuite accéder à toutes les fonctionnalités.',
                 textAlign: TextAlign.center,
               ),
             ],
           ),
           actions: [
             TextButton(
               onPressed: () {
                 Navigator.pop(ctx);
                 context.go('/');
               },
               child: const Text('PLUS TARD (ACCÈS SPECTATEUR)'),
             ),
             ElevatedButton(
               onPressed: () {
                 Navigator.pop(ctx);
                 context.go('/');
               },
               child: const Text('C\'EST FAIT'),
             ),
           ],
         ),
       );
    } else {
      if (Navigator.canPop(context)) {
        Navigator.pop(context, true);
      } else {
        context.go('/');
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Compte créé avec succès !'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 4),
        ),
      );
    }
  }
}
