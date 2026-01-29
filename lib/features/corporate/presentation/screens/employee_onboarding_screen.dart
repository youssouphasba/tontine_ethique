import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tontetic/core/theme/app_theme.dart';

import 'package:tontetic/core/providers/consent_provider.dart';
import 'package:tontetic/core/providers/context_provider.dart';

import 'package:tontetic/features/dashboard/presentation/screens/dashboard_screen.dart';

/// Employee Onboarding Screen (Employee Side)
/// Handles invitation acceptance with existing account detection
/// 
/// Flow:
/// 1. Check if account exists (email/phone)
/// 2. If exists: Link to company (no duplicate)
/// 3. If new: Create account + link
/// 4. Accept dual CGU (company + platform)

class EmployeeOnboardingScreen extends ConsumerStatefulWidget {
  final String invitationToken;
  final String companyName;
  final String companyId;

  const EmployeeOnboardingScreen({
    super.key,
    required this.invitationToken,
    required this.companyName,
    required this.companyId,
  });

  @override
  ConsumerState<EmployeeOnboardingScreen> createState() => _EmployeeOnboardingScreenState();
}

class _EmployeeOnboardingScreenState extends ConsumerState<EmployeeOnboardingScreen> {
  int _currentStep = 0;
  bool _isLoading = false;
  bool _accountExists = false;
  bool _linkingAccepted = false;

  // Step 1: Account check
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();

  // Step 2: New account or login
  final _nameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _showPassword = false;

  // Step 3: CGU
  bool _cguCompanyAccepted = false;
  bool _cguPlatformAccepted = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.offWhite,
      appBar: AppBar(
        title: const Text('Rejoindre l\'entreprise'),
        backgroundColor: Theme.of(context).brightness == Brightness.dark ? Colors.indigo.shade900 : Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Company header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Theme.of(context).brightness == Brightness.dark ? Colors.indigo.withValues(alpha: 0.2) : Colors.indigo.withValues(alpha: 0.1),
            child: Row(
              children: [
                const CircleAvatar(
                  backgroundColor: Colors.indigo,
                  child: Icon(Icons.business, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.companyName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const Text('Vous a invité à rejoindre ses tontines', style: TextStyle(color: Colors.grey, fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Progress
          _buildProgressBar(),
          
          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: _buildCurrentStep(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      color: Colors.white,
      child: Row(
        children: List.generate(3, (i) => Expanded(
          child: Container(
            height: 4,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              color: _currentStep >= i ? Colors.indigo : Colors.grey[300],
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

  // =============== STEP 1: ACCOUNT CHECK ===============
  Widget _buildStep1() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Vérification du compte', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.indigo)),
        const SizedBox(height: 8),
        const Text('Entrez votre email ou téléphone pour vérifier si vous avez déjà un compte.', style: TextStyle(color: Colors.grey)),
        const SizedBox(height: 24),

        // Email
        TextFormField(
          controller: _emailController,
          decoration: const InputDecoration(
            labelText: 'Email',
            prefixIcon: Icon(Icons.email),
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        const Center(child: Text('ou', style: TextStyle(color: Colors.grey))),
        const SizedBox(height: 12),
        
        // Phone
        TextFormField(
          controller: _phoneController,
          decoration: const InputDecoration(
            labelText: 'Téléphone',
            prefixIcon: Icon(Icons.phone),
            border: OutlineInputBorder(),
            hintText: '+221 77 123 45 67',
          ),
        ),
        const SizedBox(height: 32),

        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _checkAccount,
            style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16)),
            child: _isLoading
              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Vérifier'),
          ),
        ),
      ],
    );
  }

  void _checkAccount() async {
    if (_emailController.text.isEmpty && _phoneController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez entrer un email ou téléphone')),
      );
      return;
    }

    setState(() => _isLoading = true);
    // Account Check (Direct)


    // Simulate account check - in reality this would be an API call
    final existingAccount = _emailController.text.contains('existing') || _phoneController.text.contains('existing');
    
    setState(() {
      _isLoading = false;
      _accountExists = existingAccount;
      _currentStep = 1;
    });
  }

  // =============== STEP 2: LINK OR CREATE ===============
  Widget _buildStep2() {
    if (_accountExists) {
      return _buildLinkExistingAccount();
    } else {
      return _buildCreateNewAccount();
    }
  }

  Widget _buildLinkExistingAccount() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.person_search, size: 64, color: Colors.indigo),
        const SizedBox(height: 16),
        const Text('Compte existant détecté', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.indigo)),
        const SizedBox(height: 8),
        const Text('Vous avez déjà un compte sur Tontetic.', style: TextStyle(color: Colors.grey)),
        const SizedBox(height: 24),

        // Linking info
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark ? Colors.green.withValues(alpha: 0.2) : Colors.green.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Theme.of(context).brightness == Brightness.dark ? Colors.green.withValues(alpha: 0.4) : Colors.green),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.link, color: Theme.of(context).brightness == Brightness.dark ? Colors.green.shade200 : Colors.green),
                  const SizedBox(width: 8),
                  Text('Rattacher à l\'entreprise', style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).brightness == Brightness.dark ? Colors.green.shade100 : Colors.green)),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                'Si vous acceptez, votre compte existant sera rattaché à cette entreprise.\n\n'
                '✅ Vous conservez vos tontines personnelles et votre Score d\'Honneur\n'
                '✅ L\'entreprise ne verra que les données des tontines qu\'elle finance\n'
                '❌ L\'entreprise n\'aura pas accès à vos informations bancaires ni à vos tontines personnelles',
                style: TextStyle(fontSize: 13, height: 1.5),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Password verification
        TextFormField(
          controller: _passwordController,
          obscureText: !_showPassword,
          decoration: InputDecoration(
            labelText: 'Confirmez avec votre mot de passe',
            prefixIcon: const Icon(Icons.lock),
            border: const OutlineInputBorder(),
            suffixIcon: IconButton(
              icon: Icon(_showPassword ? Icons.visibility_off : Icons.visibility),
              onPressed: () => setState(() => _showPassword = !_showPassword),
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Checkbox
        CheckboxListTile(
          value: _linkingAccepted,
          onChanged: (v) => setState(() => _linkingAccepted = v!),
          title: const Text('J\'accepte de rattacher mon compte à cette entreprise', style: TextStyle(fontSize: 14)),
          activeColor: Colors.indigo,
          controlAffinity: ListTileControlAffinity.leading,
        ),
        const SizedBox(height: 24),

        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _linkingAccepted && _passwordController.text.isNotEmpty ? _linkAccount : null,
            style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16)),
            child: const Text('Rattacher mon compte'),
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Refuser et quitter'),
          ),
        ),
      ],
    );
  }

  void _linkAccount() async {
    setState(() => _isLoading = true);
    // Link Account (Direct)


    // Link to company
    ref.read(contextProvider.notifier).linkToCompany(
      companyId: widget.companyId,
      companyName: widget.companyName,
    );

    setState(() {
      _isLoading = false;
      _currentStep = 2;
    });
  }

  Widget _buildCreateNewAccount() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Créer votre compte', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.indigo)),
        const SizedBox(height: 8),
        const Text('Renseignez vos informations pour créer votre compte.', style: TextStyle(color: Colors.grey)),
        const SizedBox(height: 24),

        // Name
        TextFormField(
          controller: _nameController,
          decoration: const InputDecoration(
            labelText: 'Nom complet',
            prefixIcon: Icon(Icons.person),
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),

        // Password
        TextFormField(
          controller: _passwordController,
          obscureText: !_showPassword,
          decoration: InputDecoration(
            labelText: 'Mot de passe',
            prefixIcon: const Icon(Icons.lock),
            border: const OutlineInputBorder(),
            suffixIcon: IconButton(
              icon: Icon(_showPassword ? Icons.visibility_off : Icons.visibility),
              onPressed: () => setState(() => _showPassword = !_showPassword),
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Info
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark ? Colors.blue.withValues(alpha: 0.2) : Colors.blue.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Theme.of(context).brightness == Brightness.dark ? Colors.blue.withValues(alpha: 0.4) : Colors.blue.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              Icon(Icons.info, color: Theme.of(context).brightness == Brightness.dark ? Colors.blue.shade200 : Colors.blue, size: 20),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Votre compte vous permettra de participer aux tontines de l\'entreprise ET de créer vos propres tontines personnelles.',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _nameController.text.isNotEmpty && _passwordController.text.length >= 8 
              ? () => setState(() => _currentStep = 2) 
              : null,
            style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16)),
            child: const Text('Continuer'),
          ),
        ),
      ],
    );
  }

  // =============== STEP 3: DUAL CGU ===============
  Widget _buildStep3() {
    final allAccepted = _cguCompanyAccepted && _cguPlatformAccepted;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Conditions d\'utilisation', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.indigo)),
        const SizedBox(height: 8),
        const Text('Veuillez accepter les conditions pour les deux contextes.', style: TextStyle(color: Colors.grey)),
        const SizedBox(height: 24),

        // CGU Company
        _buildCguCard(
          title: 'CGU Tontines Entreprise',
          subtitle: 'Règles spécifiques à ${widget.companyName}',
          icon: Icons.business,
          color: Colors.indigo,
          value: _cguCompanyAccepted,
          onChanged: (v) => setState(() => _cguCompanyAccepted = v!),
          content: _getCompanyCgu(),
        ),
        const SizedBox(height: 16),

        // CGU Platform
        _buildCguCard(
          title: 'CGU Plateforme (Particulier)',
          subtitle: 'Conditions générales + tontines personnelles',
          icon: Icons.person,
          color: Colors.blue,
          value: _cguPlatformAccepted,
          onChanged: (v) => setState(() => _cguPlatformAccepted = v!),
          content: _getPlatformCgu(),
        ),
        const SizedBox(height: 24),

        // Clause unique
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark ? Colors.orange.withValues(alpha: 0.2) : Colors.orange.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Theme.of(context).brightness == Brightness.dark ? Colors.orange.withValues(alpha: 0.4) : Colors.orange),
          ),
          child: const Text(
            '« Le salarié d\'une entreprise dispose d\'un compte unique sur la plateforme. Les droits et obligations varient selon le contexte : participation à une tontine de l\'entreprise ou à une tontine privée. La plateforme agit exclusivement comme prestataire technique et ne détient aucun fonds. »',
            style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
          ),
        ),
        const SizedBox(height: 32),

        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: allAccepted ? _completeOnboarding : null,
            style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16)),
            child: const Text('Terminer et accéder'),
          ),
        ),
      ],
    );
  }

  Widget _buildCguCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required bool value,
    required ValueChanged<bool?> onChanged,
    required String content,
  }) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: value ? color : Colors.grey[300]!),
      ),
      child: Column(
        children: [
          CheckboxListTile(
            value: value,
            onChanged: onChanged,
            title: Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 8),
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
            activeColor: color,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextButton.icon(
              onPressed: () => _showCguDialog(title, content),
              icon: const Icon(Icons.description, size: 16),
              label: const Text('Lire le document'),
            ),
          ),
        ],
      ),
    );
  }

  void _showCguDialog(String title, String content) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        expand: false,
        builder: (_, scrollController) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
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

  String _getCompanyCgu() {
    return '''
CONDITIONS GÉNÉRALES - TONTINES ENTREPRISE

1. OBJET
Le présent document régit votre participation aux tontines organisées par ${widget.companyName}.

2. PARTICIPATION
Votre participation aux tontines de l'entreprise est volontaire. L'entreprise peut proposer un abondement selon ses politiques internes.

3. CONFIDENTIALITÉ
L'entreprise n'a pas accès à vos informations bancaires personnelles ni à vos tontines privées.

4. PAIEMENTS
Les paiements sont gérés par le PSP (Wave, Stripe). L'entreprise ne gère pas directement les flux financiers.

5. REMPLACEMENT
En cas de départ de l'entreprise ou de la tontine, vous devez trouver un remplaçant selon les règles du cercle.
''';
  }

  String _getPlatformCgu() {
    return '''
CONDITIONS GÉNÉRALES D'UTILISATION - PLATEFORME

1. COMPTE UNIQUE
Vous disposez d'un compte unique vous permettant de participer aux tontines d'entreprise ET de créer vos propres tontines personnelles.

2. RÔLE DE LA PLATEFORME
La plateforme agit exclusivement comme prestataire technique. Les services de paiement sont fournis par un PSP agréé.

3. TONTINES PERSONNELLES
En dehors des tontines de l'entreprise, vous pouvez librement créer ou rejoindre des tontines privées avec vos proches.

4. SCORE D'HONNEUR
Votre Score d'Honneur est calculé sur l'ensemble de vos participations et reste personnel.

5. PROTECTION DES DONNÉES
Vos données bancaires ne transitent jamais par notre plateforme. Elles sont gérées directement par le PSP.
''';
  }

  void _completeOnboarding() async {
    setState(() => _isLoading = true);

    // Record consents
    ref.read(consentProvider.notifier).recordConsent(
      type: ConsentType.cgu,
      accepted: true,
      ipAddress: '192.168.x.x',
      version: '2.0-EMPLOYEE',
    );

    // Link to company
    ref.read(contextProvider.notifier).linkToCompany(
      companyId: widget.companyId,
      companyName: widget.companyName,
    );

    // Complete Onboarding (Direct)


    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const DashboardScreen()),
      (route) => false,
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('✅ Bienvenue ! Vous êtes rattaché à ${widget.companyName}'),
        backgroundColor: Colors.green,
      ),
    );
  }
}
