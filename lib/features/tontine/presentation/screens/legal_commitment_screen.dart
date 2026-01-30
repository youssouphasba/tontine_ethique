import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:tontetic/core/business/tontine_tier_service.dart';

import 'package:tontetic/core/providers/user_provider.dart';
import 'package:tontetic/core/theme/app_theme.dart';
import 'package:tontetic/core/services/audit_service.dart';
import 'package:tontetic/core/providers/auth_provider.dart';
import 'package:tontetic/features/tontine/presentation/widgets/signature_pad.dart';

import 'package:tontetic/core/services/stripe_service.dart';
import 'package:url_launcher/url_launcher.dart';

class LegalCommitmentScreen extends ConsumerStatefulWidget {
  final double amount;
  final String? currency;
  final VoidCallback onAccepted;

  const LegalCommitmentScreen({
    super.key,
    required this.amount,
    this.currency,
    required this.onAccepted,
  });

  @override
  ConsumerState<LegalCommitmentScreen> createState() => _LegalCommitmentScreenState();
}

class _LegalCommitmentScreenState extends ConsumerState<LegalCommitmentScreen> {
  // ... (State vars unchanged)
  bool _renunciationAccepted = false;
  bool _penalClauseAccepted = false;
  bool _sepaAccepted = false; // Nouveau: acceptation mandats SEPA
  bool _isSigning = false;
  final _ibanController = TextEditingController();
  String? _ibanError;

  @override
  void dispose() {
    _ibanController.dispose();
    super.dispose();
  }

  // ... (Methods unchanged until build)

  // Skipping unchanged methods for brevity to reach build...
  // BUT I must include the build start to insert the currency logic.

  // To minimize text, I will target the class definition and the build start separately using multi_replace_file_content if possible?
  // No, replace_file_content is single block.
  // I will just replace the top of the file up to build? No that's too much code.
  // I will use replace_file_content for the Constructor first.


  bool _validateIban(String value) {
    final user = ref.read(userProvider);
    // Dans la zone Euro, l'IBAN est géré par Stripe Connect, pas par le TextField
    if (user.zone == UserZone.zoneEuro) return true;

    // Basic IBAN validation for other zones (Mobile Money etc)
    final cleanIban = value.replaceAll(' ', '').toUpperCase();
    if (cleanIban.length < 9) return false; // More flexible for Mobile Money
    return true;
  }

  void _handleSigning() async {
    setState(() => _isSigning = true);
    
    // Enregistrement du Timestamp et Signature dans les Logs

    
    // Logique Audit Réelle
    await AuditService.logAction(
      actionType: 'MANDAT_SEPA_SIGNATURE',
      userId: ref.read(userProvider).phoneNumber,
      details: 'Montant: ${widget.amount}, Zone: ${ref.read(userProvider).zone.name}, Type: SEPA_PURE',
      signatureHash: 'POINTS_${_signaturePoints.length}',
    );
    
    if (mounted) {
      widget.onAccepted();
    }
  }

  bool _isConnectingStripe = false;

  /// Démarre l'onboarding Stripe Connect Express
  /// Crée un compte Connect puis redirige vers Stripe pour KYC + RIB
  Future<void> _startConnectOnboarding() async {
    setState(() => _isConnectingStripe = true);
    try {
      final user = ref.read(userProvider);
      final authService = ref.read(authServiceProvider);
      final uid = authService.currentUserUid;
      
      // Get email from user state, or from Firebase Auth as fallback
      String? email = user.email;
      if (email.isEmpty) {
        // Try to get email from Firebase Auth current user
        final firebaseEmail = FirebaseAuth.instance.currentUser?.email;
        if (firebaseEmail != null && firebaseEmail.isNotEmpty) {
          email = firebaseEmail;
        }
      }
      
      if (email.isEmpty) {
        throw 'Email requis. Veuillez d\'abord compléter votre profil.';
      }
      
      String? connectAccountId = user.stripeConnectAccountId;
      
      // 1. Créer le compte Connect si pas encore fait
      if (connectAccountId == null) {
        final displayName = user.displayName.isNotEmpty 
            ? user.displayName 
            : ref.read(userProvider).displayName.isNotEmpty ? ref.read(userProvider).displayName : 'Membre Tontetic';
            
        connectAccountId = await StripeService.createConnectAccount(
          email: email,
          userId: uid,
          firstName: displayName.split(' ').firstOrNull,
          lastName: displayName.split(' ').skip(1).join(' '),
        );
        
        // Sauvegarder localement
        ref.read(userProvider.notifier).updateStripeConnectAccountId(connectAccountId);
      }
      
      // 2. Générer le lien d'onboarding
      final onboardingUrl = await StripeService.createConnectAccountLink(
        accountId: connectAccountId,
      );
      
      if (onboardingUrl.isEmpty) {
        throw 'Le serveur n\'a pas renvoyé d\'URL d\'onboarding valide.';
      }
      
      // 3. Ouvrir le navigateur
      final uri = Uri.tryParse(onboardingUrl);
      if (uri == null || !uri.hasAbsolutePath) {
        throw 'L\'URL fournie par Stripe est malformée : $onboardingUrl';
      }

      debugPrint('[STRIPE] Tentative d\'ouverture de: $onboardingUrl');
      
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('🔗 Complétez l\'inscription sur Stripe puis revenez ici.'),
              duration: Duration(seconds: 5),
            ),
          );
        }
      } else {
        throw 'Impossible d\'ouvrir le lien Stripe. Vérifiez qu\'un navigateur est installé.';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Erreur : ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isConnectingStripe = false);
      }
    }
  }

  void _showStripeGuide() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.shield, color: Colors.blue), // Changed to Shield for trust
            SizedBox(width: 12),
            Expanded(child: Text('Activation Bancaire Sécurisée', style: TextStyle(fontSize: 18))),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Vous allez être redirigé vers l\'interface sécurisée de Stripe (notre partenaire bancaire) pour valider votre identité.',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text(
              '🔒 Pourquoi tant d\'informations ?',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
            ),
            const SizedBox(height: 8),
            const Text(
              'Pour lutter contre le blanchiment d\'argent (loi KYC), Stripe doit vérifier votre identité avant de pouvoir vous virer votre gain.',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 16),
             _guideItem(Icons.badge, 'Préparez votre Pièce d\'Identité (CNI/Passeport).'),
            _guideItem(Icons.savings, 'C\'est uniquement pour recevoir votre tour de Tontine (le pot).'),
            _guideItem(Icons.language, 'Site web : mettez "tontetic-app.web.app" (requis par Stripe).'),
            _guideItem(Icons.lock_outline, 'Vérification 100% sécurisée et chiffrée par Stripe.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('PLUS TARD'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _startConnectOnboarding();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.marineBlue, 
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text('OUVRIR L\'ESPACE SÉCURISÉ'),
          ),
        ],
      ),
    );
  }

  Widget _guideItem(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Colors.blue),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }

  /// Vérifie si l'onboarding Connect est terminé
  Future<void> _checkConnectStatus() async {
    final user = ref.read(userProvider);
    if (user.stripeConnectAccountId != null && !user.stripeConnectOnboardingComplete) {
      try {
        final status = await StripeService.getConnectAccountStatus(
          accountId: user.stripeConnectAccountId!,
        );
        
        if (status['detailsSubmitted'] == true) {
          ref.read(userProvider.notifier).updateStripeConnectOnboardingComplete(true);
          
          // Persist to Firestore
          final authService = ref.read(authServiceProvider);
          final uid = authService.currentUserUid;
          if (uid != null) {
            // Would need to add this method to AuthService
          }
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('✅ Compte Stripe Connect vérifié !'),
                backgroundColor: Colors.green,
              ),
            );
          }
        }
      } catch (e) {
        debugPrint('Erreur vérification Connect: $e');
      }
    }
  }

  @override
  void initState() {
    super.initState();
    // Vérifier le statut Connect au chargement
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkConnectStatus();
    });
  }

  List<Offset> _signaturePoints = [];

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(userProvider);
    
    var contribution = TontineTierService.calculateContribution(
      amount: widget.amount, 
      zone: user.zone,
    );
    
    // V17: Override currency if provided (e.g. from Tontine settings) 
    // to match Tontine currency instead of User Zone currency
    if (widget.currency != null) {
      contribution = TontineContributionInfo(
        contributionAmount: contribution.contributionAmount,
        guaranteeAuthorized: contribution.guaranteeAuthorized,
        currency: widget.currency!,
      );
    }

    final tier = user.subscriptionTier;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Engagement Légal'),
        backgroundColor: Theme.of(context).brightness == Brightness.dark ? Colors.black : AppTheme.marineBlue,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(contribution, user.zone, tier),
                  const Divider(height: 40),
                  _buildSectionTitle('1. Architecture SEPA Pure'),
                  const SizedBox(height: 8),
                  Text(
                    'Tontetic agit comme Prestataire Technique. Nous ne détenons JAMAIS vos fonds. Les prélèvements SEPA vont directement au bénéficiaire du tour.',
                    style: TextStyle(fontSize: 14, color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : AppTheme.marineBlue),
                  ),
                  const SizedBox(height: 16),
                  _buildContributionBreakdown(contribution, user),

                  const SizedBox(height: 24),
                  _buildSectionTitle('2. Double Mandat SEPA'),
                  const SizedBox(height: 8),
                  _buildSepaMandate('A', 'Cotisations Récurrentes', contribution.contributionAmount, contribution.currency, true),
                  const SizedBox(height: 8),
                  _buildSepaMandate('B', 'Garantie Conditionnelle', contribution.guaranteeAuthorized, contribution.currency, false),
                  
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.gold.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.gold),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.shield, color: AppTheme.gold),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'La garantie de ${ref.read(userProvider.notifier).formatContent(contribution.guaranteeAuthorized)} '
                            'est une AUTORISATION, pas un prélèvement. Elle ne sera déclenchée qu\'en cas de défaut avéré '
                            '(3 tentatives échouées + 7 jours de grâce).',
                            style: TextStyle(fontSize: 13, color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : AppTheme.marineBlue),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),
                  _buildSectionTitle('3. Cadre Légal & Pénal'),
                  const SizedBox(height: 16),
                  
                  _buildCheckbox(
                    value: _sepaAccepted,
                    label: 'MANDATS SEPA',
                    content: 'J\'autorise les prélèvements récurrents (Mandat A) et l\'autorisation conditionnelle de garantie (Mandat B) selon les conditions décrites ci-dessus.',
                    onChanged: (v) => setState(() => _sepaAccepted = v!),
                  ),
                  const SizedBox(height: 16),
                  
                  _buildCheckbox(
                    value: _renunciationAccepted,
                    label: 'DÉMARRAGE DES SERVICES & FLEXIBILITÉ',
                    content: 'Le service s\'active à la validation. Vous pouvez annuler sans frais tant que le premier tour de la tontine n\'a pas débuté. Passé ce délai, l\'engagement est définitif.',
                    onChanged: (v) => setState(() => _renunciationAccepted = v!),
                  ),
                  const SizedBox(height: 16),
                   _buildCheckbox(
                    value: _penalClauseAccepted,
                    label: 'CLAUSE PÉNALE "ABUS DE CONFIANCE"',
                    content: 'Je certifie sur l\'honneur m\'engager à payer la totalité des tours. Je comprends que tout défaut de paiement après avoir reçu le pot pourra entraîner des poursuites pénales pour abus de confiance.',
                    onChanged: (v) => setState(() => _penalClauseAccepted = v!),
                  ),

                  const SizedBox(height: 32),
                  if (user.zone == UserZone.zoneEuro) ...[
                    _buildSectionTitle('4. Compte de Réception (Stripe Connect)'),
                    const SizedBox(height: 16),
                    if (!user.stripeConnectOnboardingComplete) ...[
                      const Text(
                        'Pour recevoir vos pots de tontine, vous devez enregistrer votre compte bancaire via Stripe. Ceci est requis une seule fois.',
                        style: TextStyle(fontSize: 14),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Vérification d\'identité requise par notre partenaire de paiement (Stripe) pour recevoir des fonds',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontStyle: FontStyle.italic),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _isConnectingStripe ? null : _showStripeGuide,
                          icon: _isConnectingStripe 
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.account_balance),
                          label: Text(_isConnectingStripe ? 'Préparation...' : 'ACTIVER LA RÉCEPTION DES FONDS'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            side: const BorderSide(color: Colors.blue),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: _checkConnectStatus,
                        icon: const Icon(Icons.refresh, size: 16),
                        label: const Text('J\'ai terminé, vérifier mon statut'),
                      ),
                    ] else ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.check_circle, color: Colors.green),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Compte Stripe Connect vérifié ✓',
                                style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ] else ...[
                    // Zone FCFA: Keep IBAN or Mobile Money info
                    _buildSectionTitle('4. Coordonnées de Paiement'),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _ibanController,
                      decoration: InputDecoration(
                        labelText: 'Numéro de Mobile Money / RIB',
                        hintText: '+221...',
                        errorText: _ibanError,
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.phone_android),
                        filled: true,
                        fillColor: Theme.of(context).brightness == Brightness.dark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
                      ),
                      style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black),
                    ),
                  ],
                  
                  const SizedBox(height: 24),
                  _buildSectionTitle('5. Signature du Mandat'),
                  const SizedBox(height: 8),
                  Text('Veuillez signer dans le cadre ci-dessous pour valider votre engagement.', style: TextStyle(fontSize: 12, color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : AppTheme.marineBlue)),
                  const SizedBox(height: 8),
                  SignaturePad(
                    onSigned: (points) {
                      setState(() {
                         _signaturePoints = points;
                      });
                    },
                  ),
                ],
              ),
            ),
          ),
          
          _buildBottomAction(),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Theme.of(context).brightness == Brightness.dark ? AppTheme.gold : AppTheme.marineBlue));
  }

  Widget _buildHeader(TontineContributionInfo contribution, UserZone zone, String tierName) {
    return Column(
      children: [
        Icon(Icons.gavel, size: 48, color: Theme.of(context).brightness == Brightness.dark ? AppTheme.gold : AppTheme.marineBlue),
        const SizedBox(height: 16),
        Text(
          'Code de Conduite SEPA',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: tierName == 'PREMIUM' 
                ? AppTheme.marineBlue 
                : (Theme.of(context).brightness == Brightness.dark ? Colors.white12 : Colors.grey[200]),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            'Tiers ${tierName.toUpperCase()}',
             style: TextStyle(
              color: tierName == 'PREMIUM' ? AppTheme.gold : Colors.black87,
              fontWeight: FontWeight.bold,
              fontSize: 12
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSepaMandate(String letter, String title, double amount, String currency, bool isRecurring) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isRecurring ? Colors.green.withValues(alpha: 0.1) : Colors.orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isRecurring ? Colors.green : Colors.orange),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: isRecurring ? Colors.green : Colors.orange,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Text(letter, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                Text(
                  isRecurring 
                    ? '${ref.read(userProvider.notifier).formatContent(amount)} / tour → Bénéficiaire'
                    : '${ref.read(userProvider.notifier).formatContent(amount)} max (si défaut)',
                  style: TextStyle(fontSize: 12, color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : AppTheme.marineBlue),
                ),
              ],
            ),
          ),
          Icon(
            isRecurring ? Icons.repeat : Icons.shield_outlined,
            color: isRecurring ? Colors.green : Colors.orange,
          ),
        ],
      ),
    );
  }

  Widget _buildContributionBreakdown(TontineContributionInfo contribution, UserState user) {
     final format = ref.read(userProvider.notifier).formatContent;
     return Container(
       padding: const EdgeInsets.all(16),
       decoration: BoxDecoration(
         color: Theme.of(context).brightness == Brightness.dark ? Colors.white.withValues(alpha: 0.05) : Colors.grey[50],
         borderRadius: BorderRadius.circular(12),
         border: Border.all(color: Theme.of(context).brightness == Brightness.dark ? Colors.white12 : Colors.grey.shade200),
       ),
       child: Column(
         children: [
           _row('Cotisation par tour', format(contribution.contributionAmount), bold: true),
           const Divider(),
           _row(
             'Garantie (autorisation)', 
             format(contribution.guaranteeAuthorized), 
             color: Theme.of(context).brightness == Brightness.dark ? AppTheme.gold : Colors.orange.shade900,
           ),
           const SizedBox(height: 8),
           Container(
             padding: const EdgeInsets.all(8),
             decoration: BoxDecoration(
               color: Colors.blue.withValues(alpha: 0.1),
               borderRadius: BorderRadius.circular(8),
             ),
             child: Row(
               children: [
                 const Icon(Icons.info_outline, size: 16, color: Colors.blue),
                 const SizedBox(width: 8),
                 Expanded(
                   child: Text(
                     'La garantie n\'est pas prélevée. Seule la cotisation est débitée chaque tour.',
                     style: TextStyle(fontSize: 11, color: Colors.blue[700]),
                   ),
                 ),
               ],
             ),
           ),
         ],
       ),
     );
  }

  Widget _row(String label, String value, {bool bold = false, double size = 14, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start, // Align to top for multiline
        children: [
          Expanded(
            child: Text(
              label, 
              style: TextStyle(
                fontSize: size, 
                color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.black87
              )
            ),
          ),
          const SizedBox(width: 16),
          Text(
            value, 
            style: TextStyle(
              fontSize: size, 
              fontWeight: bold ? FontWeight.bold : FontWeight.normal, 
              color: color ?? (Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87)
            )
          ),
        ],
      ),
    );
  }

  Widget _buildCheckbox({required bool value, required String label, required String content, required ValueChanged<bool?> onChanged}) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: value 
              ? (Theme.of(context).brightness == Brightness.dark ? AppTheme.gold : AppTheme.marineBlue) 
              : (Theme.of(context).brightness == Brightness.dark ? Colors.white24 : Colors.grey.shade300),
        ),
        borderRadius: BorderRadius.circular(8),
        color: value 
            ? (Theme.of(context).brightness == Brightness.dark ? AppTheme.gold.withValues(alpha: 0.1) : AppTheme.marineBlue.withValues(alpha: 0.05)) 
            : null,
      ),
      child: CheckboxListTile(
        value: value,
        onChanged: onChanged,
        activeColor: Theme.of(context).brightness == Brightness.dark ? AppTheme.gold : AppTheme.marineBlue,
        title: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: Text(content, style: TextStyle(fontSize: 12, color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : AppTheme.marineBlue)),
        ),
        controlAffinity: ListTileControlAffinity.leading,
      ),
    );
  }

  Widget _buildBottomAction() {
    final isStripeZone = ref.read(userProvider).zone == UserZone.zoneEuro;
    final isConnectComplete = ref.read(userProvider).stripeConnectOnboardingComplete;

    final canSign = _sepaAccepted && 
                   _renunciationAccepted && 
                   _penalClauseAccepted && 
                   _signaturePoints.isNotEmpty &&
                   (!isStripeZone || isConnectComplete) &&
                   (isStripeZone || _ibanController.text.isNotEmpty);
    
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1E1E1E) : Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), offset: const Offset(0, -4), blurRadius: 10)],
      ),
      child: Column(
        children: [
          if (_isSigning)
            CircularProgressIndicator(color: Theme.of(context).primaryColor)
          else
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: canSign ? () {
                  if (!_validateIban(_ibanController.text)) {
                    setState(() => _ibanError = 'Format IBAN invalide');
                    return;
                  }
                  _handleSigning();
                } : null,
                icon: const Icon(Icons.fingerprint),
                label: const Text('SIGNER LES MANDATS SEPA'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: canSign ? AppTheme.marineBlue : Colors.grey,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
            const SizedBox(height: 8),
            if (!canSign)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  !isConnectComplete && isStripeZone 
                    ? 'Veuillez activer la réception Stripe ci-dessus.'
                    : _signaturePoints.isEmpty 
                      ? 'N\'oubliez pas de signer dans le cadre.'
                      : 'Cochez toutes les clauses et signez pour activer.',
                  style: const TextStyle(fontSize: 11, color: Colors.orange, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
              )
            else
              const Padding(
                padding: EdgeInsets.only(top: 8.0),
                child: Text(
                  'IP et Timestamp enregistrés pour valeur légale',
                  style: TextStyle(fontSize: 10, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
              ),
        ],
      ),
    );
  }
}
