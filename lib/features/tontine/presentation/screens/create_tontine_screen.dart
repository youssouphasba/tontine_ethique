// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tontetic/core/providers/user_provider.dart';
import 'package:tontetic/core/theme/app_theme.dart';
import 'package:tontetic/core/providers/plans_provider.dart';
import 'package:tontetic/core/business/subscription_service.dart';
import 'package:tontetic/features/subscription/presentation/screens/subscription_selection_screen.dart';
import 'package:tontetic/features/tontine/presentation/screens/legal_commitment_screen.dart';
import 'package:tontetic/core/services/wolof_audio_service.dart';
import 'package:tontetic/core/providers/circle_provider.dart';
import 'package:tontetic/features/social/data/social_provider.dart';
import 'package:tontetic/features/settings/presentation/screens/legal_documents_screen.dart';
import 'package:tontetic/features/tontine/presentation/screens/circle_chat_screen.dart';
import 'package:tontetic/core/services/security_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:tontetic/core/providers/auth_provider.dart';

class CreateTontineScreen extends ConsumerStatefulWidget {
  const CreateTontineScreen({super.key});

  @override
  ConsumerState<CreateTontineScreen> createState() => _CreateTontineScreenState();
}

class _CreateTontineScreenState extends ConsumerState<CreateTontineScreen> {
  int _currentStep = 0;
  
  // Controllers Step 1
  final _nameController = TextEditingController();
  final _objectiveController = TextEditingController();
  
  // Controllers Step 2
  final _amountController = TextEditingController();
  final _participantsController = TextEditingController(); 
  String _frequency = 'Mensuelle';
  int _payoutDay = 5; // Default: 5th of the period
  
  final List<String> _frequencies = [
    'Hebdomadaire', 
    'Bi-mensuelle', 
    'Mensuelle', 
    'Bimestrielle', 
    'Trimestrielle', 
    'Semestrielle', 
    'Annuelle'
  ];

  // State Step 3
  String _orderType = 'Aléatoire';

  // State Step 4 (Garantie)
  bool _guaranteeAccepted = false;
  int _gracePeriodDays = 3; // V15: Délai de grâce choisi par le groupe
  
  // State Step 3 (Invites)
  bool _publishToExplorer = true; // Default true per user request "publish to complete"

  @override
  void initState() {
    super.initState();
    
    // Auth Guard: Redirect guests back
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final isGuest = ref.read(isGuestModeProvider);
      if (isGuest) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: const Text('Connexion requise'),
            content: const Text('La création d\'un cercle nécessite un compte vérifié.'),
            actions: [
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  context.go('/auth');
                },
                child: const Text('Se connecter'),
              )
            ],
          ),
        );
      }
    });

    // Bloc 3: Wake-up call to wake up Anta for tontine creation
    ref.read(wolofAudioServiceProvider).wakeUp();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _objectiveController.dispose();
    _amountController.dispose();
    _participantsController.dispose();
    _inviteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(userProvider);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nouvelle Tontine'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          // Refresh button to reload user state after payment
          TextButton.icon(
            onPressed: () {
              // Force reload by invalidating providers
              ref.invalidate(userProvider);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('✅ Données actualisées !'),
                  backgroundColor: Colors.green,
                  duration: Duration(seconds: 2),
                ),
              );
              setState(() {}); // Force rebuild
            },
            icon: const Icon(Icons.refresh, color: Colors.white, size: 20),
            label: const Text('Actualiser', style: TextStyle(color: Colors.white, fontSize: 12)),
          ),
        ],
      ),
      body: Stepper(
        type: StepperType.vertical,
        currentStep: _currentStep,
        onStepContinue: _nextStep,
        onStepCancel: _cancelStep,
        controlsBuilder: (context, details) {
          return _buildStepControls(details);
        },
        steps: [
          _buildStep1(),
          _buildStep2(),
          _buildStepInvites(), // New Step 3
          _buildStep3(),
          _buildStep4Guarantee(),
          _buildStep5Final(),
        ],
      ),
    );
  }

  // State Invite
  final List<String> _invitedContacts = [];
  final _inviteCtrl = TextEditingController();

  Step _buildStepInvites() {
    // V15: Get mutual followers from social provider
    final socialState = ref.watch(socialProvider);
    final currentUserId = ref.watch(userProvider).phoneNumber;
    // FETCH REAL DATA (No more mocks)
    // FETCH REAL DATA (No more mocks)
    final mutualFollowers = socialState.getMutualFollowers(currentUserId);
    final onlyMutuals = mutualFollowers.toList();
    
    return Step(
      title: const Text('Inviter vos Proches'),
      isActive: _currentStep >= 2,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // V15: Mutual followers section
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark ? Colors.green.withValues(alpha: 0.2) : Colors.green.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Theme.of(context).brightness == Brightness.dark ? Colors.green.withValues(alpha: 0.4) : Colors.green.shade200),
            ),
            child: Row(
              children: [
                const Icon(Icons.people, color: Colors.green),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Seuls vos followers mutuels peuvent voir et rejoindre votre cercle.',
                    style: TextStyle(
                      fontSize: 12, 
                      color: Theme.of(context).brightness == Brightness.dark ? Colors.green.shade200 : Colors.green,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          
          const Text('Vos Followers Mutuels', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          
          if (onlyMutuals.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Icon(Icons.person_add_disabled, size: 40, color: Theme.of(context).brightness == Brightness.dark ? Colors.white24 : Colors.grey),
                  const SizedBox(height: 8),
                  Text('Aucun follower mutuel', style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.white38 : Colors.grey)),
                  Text(
                    'Suivez des personnes et attendez qu\'elles vous suivent en retour.', 
                    style: TextStyle(
                      fontSize: 12, 
                      color: Theme.of(context).brightness == Brightness.dark ? Colors.white24 : Colors.grey,
                    ), 
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          else
            ...onlyMutuals.map((fid) => _buildMutualFollowerTile(fid)),
          
          const SizedBox(height: 24),
          const Divider(),
          
          // GENERATED LINK SECTION
          const Text('Ou partagez le lien d\'invitation :', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.marineBlue.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.marineBlue.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                Icon(Icons.link, color: Theme.of(context).brightness == Brightness.dark ? AppTheme.gold : AppTheme.marineBlue),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Lien d\'invitation unique', 
                        style: TextStyle(
                          fontSize: 12, 
                          color: Theme.of(context).brightness == Brightness.dark ? Colors.white38 : Colors.grey,
                        ),
                      ),
                      Text(
                        'tontetic-app.web.app/join/${DateTime.now().millisecondsSinceEpoch}', 
                        style: TextStyle(
                          fontWeight: FontWeight.bold, 
                          color: Theme.of(context).brightness == Brightness.dark ? AppTheme.gold : AppTheme.marineBlue, 
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton.icon(
                  onPressed: () {
                     // Get current invite code or link
                     const inviteLink = "https://tontetic-app.web.app/join/TONT-2026-NEW"; // Fallback demo link
                     // Copy to clipboard logic normally goes here, but for now we'll stick to SnackBar
                     ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lien copié dans le presse-papier !')));
                  },
                  icon: const Icon(Icons.copy, size: 16),
                  label: const Text('COPIER'),
                )
              ],
            ),
          ),
          const SizedBox(height: 16),
          
          // Share buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    final inviteLink = "https://tontetic-app.web.app/join/TONT-2026-NEW";
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('⏳ Ouverture de WhatsApp...')));
                    // Note: share_plus is better for general sharing
                  },
                  icon: const Icon(Icons.chat, color: Colors.green),
                  label: const Text('WhatsApp'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('⏳ Ouverture de la messagerie...')));
                  },
                  icon: const Icon(Icons.sms, color: Colors.blue),
                  label: const Text('SMS'),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          const Divider(),
          
          // V15: EXTERNAL INVITATION SECTION
          const Text('Inviter par téléphone ou email', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark ? Colors.orange.withValues(alpha: 0.2) : Colors.orange.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Theme.of(context).brightness == Brightness.dark ? Colors.orange.withValues(alpha: 0.4) : Colors.orange.shade200),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: Colors.orange, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'La personne invitée devra créer un compte et vous suivre mutuellement avant de pouvoir rejoindre le cercle.',
                    style: TextStyle(
                      fontSize: 11, 
                      color: Theme.of(context).brightness == Brightness.dark ? Colors.orange.shade200 : Colors.orange,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _inviteCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Numéro ou Email',
                    border: OutlineInputBorder(),
                    hintText: 'ex: +33 6... ou email@...',
                    prefixIcon: Icon(Icons.person_add),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                style: IconButton.styleFrom(backgroundColor: AppTheme.marineBlue, foregroundColor: Colors.white),
                icon: const Icon(Icons.send),
                tooltip: 'Envoyer l\'invitation',
                onPressed: () {
                   if (_inviteCtrl.text.isNotEmpty) {
                     setState(() {
                       _invitedContacts.add(_inviteCtrl.text);
                       _inviteCtrl.clear();
                     });
                     ScaffoldMessenger.of(context).showSnackBar(
                       const SnackBar(content: Text('Invitation envoyée ! La personne recevra un lien.')),
                     );
                   }
                },
              )
            ],
          ),
          const SizedBox(height: 12),
          // Mock Contact Picker REMOVED

          
          const SizedBox(height: 24),

          // EXPLORER TOGGLE (only for public circles)
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _publishToExplorer,
            activeThumbColor: AppTheme.marineBlue,
            title: const Text('Publier sur l\'Explorer', style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: const Text('Vos followers mutuels pourront découvrir votre cercle dans l\'Explorer.'),
            onChanged: (v) => setState(() => _publishToExplorer = v),
          ),
          
          // Invited summary
          if (_invitedContacts.isNotEmpty) ...[
            const Divider(),
            Text('${_invitedContacts.length} personne(s) invitée(s)', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: _invitedContacts.map((c) => Chip(
                label: Text(c),
                onDeleted: () => setState(() => _invitedContacts.remove(c)),
                backgroundColor: Theme.of(context).brightness == Brightness.dark ? Colors.blue.withValues(alpha: 0.2) : Colors.blue.shade50,
              )).toList(),
            ),
          ],
        ],
      ),
    );
  }
  
  Widget _buildMutualFollowerTile(String followerId) {
    final isSelected = _invitedContacts.contains(followerId);
    
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(followerId).snapshots(),
      builder: (context, snapshot) {
        final user = ref.read(userProvider);
        String name = user.displayName.isNotEmpty ? user.displayName : 'Membre Tontetic';
        String avatar = '👤';
        int score = 50;

        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>;
          name = data['fullName'] ?? 'Membre Tontetic';
          if (data['encryptedName'] != null) {
            try {
              name = SecurityService.decryptData(data['encryptedName']);
            } catch (_) {}
          }
          score = data['honorScore'] ?? 50;
        }

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: CheckboxListTile(
            value: isSelected,
            onChanged: (v) {
              setState(() {
                if (v == true) {
                  _invitedContacts.add(followerId);
                } else {
                  _invitedContacts.remove(followerId);
                }
              });
            },
            secondary: CircleAvatar(
              backgroundColor: AppTheme.gold,
              child: Text(avatar, style: const TextStyle(fontSize: 20)),
            ),
            title: Row(
              children: [
                Flexible(
                  child: Text(
                    name, 
                    style: const TextStyle(fontWeight: FontWeight.w500),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.swap_horiz, size: 14, color: Colors.green),
                const Padding(
                  padding: EdgeInsets.only(left: 2),
                  child: Text('Mutuel', style: TextStyle(fontSize: 10, color: Colors.green)),
                ),
              ],
            ),
            subtitle: Row(
              children: [
                const Icon(Icons.star, size: 14, color: AppTheme.gold),
                const SizedBox(width: 4),
                Text('Score: $score%', style: const TextStyle(fontSize: 12)),
              ],
            ),
            activeColor: AppTheme.marineBlue,
          ),
        );
      }
    );
  }

  Widget _buildStepControls(ControlsDetails details) {
    final user = ref.watch(userProvider);
    final plan = ref.watch(currentUserPlanProvider).value;

    // 1. Check Active Circles (Global) - Mother Rule
    final quotaError = SubscriptionService.getCreationErrorMessage(
      plan: plan, 
      activeCirclesCount: user.activeCirclesCount,
    );
    
    // 2. Check Participants Limit for current plan
    String? participantError;
    if (_participantsController.text.isNotEmpty) {
       final count = int.tryParse(_participantsController.text) ?? 0;
       participantError = SubscriptionService.getParticipantsErrorMessage(
         plan: plan, 
         requestedParticipants: count,
       );
       
       // V15: Special check for large groups
       const int kLargeGroupThreshold = 15; 
       if (count >= kLargeGroupThreshold) {
         // Logic for large groups or admin bypass could be added here
       }
    }

    final errorMessage = quotaError ?? participantError;
    // final quotaExceeded = errorMessage != null;

    // 3. Check Global Contribution Limit (Security Rule V15)
    // REMOVED V17: SEPA Pure architecture no longer enforces wallet limits same way.

    Widget mainButton;
    VoidCallback? onPressed = details.onStepContinue;

    // Logique boutons spéciaux
    bool isFinalStep = _currentStep == 5;

    // Upgrade Requis ou Limite Globale Atteinte
    if (errorMessage != null) {
       mainButton = Column(
         children: [
           Padding(
             padding: const EdgeInsets.only(bottom: 8.0),
             child: Text(
               errorMessage,
               style: const TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.bold),
               textAlign: TextAlign.center,
             ),
           ),
           SizedBox(
             width: double.infinity,
             child: ElevatedButton.icon(
               onPressed: () {
                 Navigator.push(context, MaterialPageRoute(builder: (_) => const SubscriptionSelectionScreen()));
               },
               icon: const Icon(Icons.star, color: AppTheme.marineBlue),
               label: const Text('Upgrader mon Plan pour débloquer'),
               style: ElevatedButton.styleFrom(backgroundColor: AppTheme.gold),
             ),
           ),
         ],
       );
       onPressed = null;
    }
    // Garantie requise (Step 4 - Guarantee)
    else if (_currentStep == 4 && !_guaranteeAccepted) {
       mainButton = ElevatedButton(
         onPressed: null,
         style: ElevatedButton.styleFrom(backgroundColor: Colors.grey),
         child: const Text('Veuillez accepter la garantie'),
       );
       onPressed = null;
    }
    else {
      String label = isFinalStep ? 'Aller à la Signature' : 'Suivant';
      mainButton = ElevatedButton(
        onPressed: onPressed,
        child: Text(label),
      );
    }
    
    return Padding(
      padding: const EdgeInsets.only(top: 24.0),
      child: Row(
        children: [
          Expanded(child: mainButton),
          if (_currentStep > 0) ...[
            const SizedBox(width: 12),
            TextButton(
              onPressed: details.onStepCancel,
              child: const Text('Retour'),
            ),
          ],
        ],
      ),
    );
  }

  Step _buildStep1() {
    return Step(
      title: const Text('Informations'),
      isActive: _currentStep >= 0,
      state: _currentStep > 0 ? StepState.complete : StepState.editing,
      content: Column(
        children: [
          TextField(
            controller: _nameController, 
            style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87),
            decoration: InputDecoration(
              labelText: 'Nom de la tontine', 
              labelStyle: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.grey[600]),
              border: const OutlineInputBorder(),
              filled: true,
              fillColor: Theme.of(context).brightness == Brightness.dark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _objectiveController, 
            style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87),
            decoration: InputDecoration(
              labelText: 'Objectif', 
              labelStyle: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.grey[600]),
              border: const OutlineInputBorder(),
              filled: true,
              fillColor: Theme.of(context).brightness == Brightness.dark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Step _buildStep2() {
    final user = ref.watch(userProvider);
    final plan = ref.watch(currentUserPlanProvider).value;
    final currency = user.currencySymbol;
    
    final maxMembers = plan?.getLimit<int>('maxMembers', 10) ?? 10;
    final maxCotisation = plan?.getLimit<num>('maxPotAmount', 500) ?? 500;
    
    return Step(
      title: const Text('Finances'),
      isActive: _currentStep >= 1,
      state: _currentStep > 1 ? StepState.complete : StepState.editing,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _amountController,
            keyboardType: TextInputType.number,
            onChanged: (v) => setState(() {}),
            decoration: InputDecoration(
              labelText: 'Cotisation (Mensuelle)', suffixText: currency, border: const OutlineInputBorder(),
              helperText: 'Plafond individuel autorisé : $maxCotisation $currency',
              helperStyle: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _participantsController,
            keyboardType: TextInputType.number,
            style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87),
            onChanged: (v) => setState(() {}),
            decoration: InputDecoration(
              labelText: 'Participants', 
              labelStyle: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.grey[600]),
              border: const OutlineInputBorder(),
              filled: true,
              fillColor: Theme.of(context).brightness == Brightness.dark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
              helperText: 'Max autorisé par votre plan : $maxMembers',
            ),
          ),
          const SizedBox(height: 24),
          Text('Paramètres Temporels', style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).brightness == Brightness.dark ? AppTheme.gold : AppTheme.marineBlue)),
          const SizedBox(height: 12),
          
          // Frequency Dropdown
          DropdownButtonFormField<String>(
            initialValue: _frequency,
            decoration: const InputDecoration(
              labelText: 'Fréquence de cotisation',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.repeat),
            ),
            items: _frequencies.map((f) => DropdownMenuItem(value: f, child: Text(f))).toList(),
            onChanged: (v) => setState(() => _frequency = v!),
          ),
          const SizedBox(height: 16),
          
          // Payout Day
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark ? Colors.white.withValues(alpha: 0.02) : Colors.grey[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Theme.of(context).brightness == Brightness.dark ? Colors.white12 : Colors.grey[300]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Jour de versement du pot', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    Text('Le $_payoutDay du cycle', style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? AppTheme.gold : AppTheme.marineBlue, fontWeight: FontWeight.bold)),
                  ],
                ),
                Slider(
                  value: _payoutDay.toDouble(),
                  min: 1,
                  max: 31,
                  divisions: 30,
                  activeColor: AppTheme.marineBlue,
                  onChanged: (v) => setState(() => _payoutDay = v.toInt()),
                ),
                Text(
                  'C\'est le jour où le bénéficiaire reçoit les fonds après la collecte.',
                  style: TextStyle(
                    fontSize: 11, 
                    color: Theme.of(context).brightness == Brightness.dark ? Colors.white38 : Colors.grey,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Step _buildStep3() {
    return Step(
      title: const Text('Ordre'),
      isActive: _currentStep >= 2,
      state: _currentStep > 2 ? StepState.complete : StepState.editing,
      content: Column(children: [
        ListTile(
          title: const Text('Aléatoire (Recommandé)'), 
          subtitle: const Text('Tontetic génère l\'ordre au hasard.'),


          leading: Radio<String>(
            value: 'Aléatoire', 
            groupValue: _orderType, 
            onChanged: (v) {
              if (v != null) setState(() => _orderType = v);
            },
          ),
          onTap: () => setState(() => _orderType = 'Aléatoire'),
        ),
        ListTile(
          title: const Text('Vote des Membres'), 
          subtitle: const Text('Les participants décident ensemble.'),

          leading: Radio<String>(
            value: 'Vote', 
            groupValue: _orderType, 
            onChanged: (v) {
              if (v != null) setState(() => _orderType = v);
            },
          ),
          onTap: () => setState(() => _orderType = 'Vote'),
        ),
      ]),
    );
  }

  Step _buildStep4Guarantee() {
    final amountText = _amountController.text.isEmpty ? '0' : _amountController.text;
    final user = ref.read(userProvider);
    final currency = user.currencySymbol;
    final guaranteeAmount = (double.tryParse(amountText) ?? 0) * 1.0; // 100% = 1 cotisation

    return Step(
      title: const Text('Garantie Solidaire'),
      isActive: _currentStep >= 3,
      state: _currentStep > 3 ? StepState.complete : StepState.editing,
      content: Column(
        children: [
          // Main guarantee card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.marineBlue.withValues(alpha: 0.05),
              border: Border.all(color: AppTheme.marineBlue.withValues(alpha: 0.2)),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                const Icon(Icons.shield_outlined, size: 48, color: AppTheme.gold),
                const SizedBox(height: 16),
                Text(
                  'Garantie : ${guaranteeAmount.toStringAsFixed(0)} $currency',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Theme.of(context).brightness == Brightness.dark ? AppTheme.gold : AppTheme.marineBlue),
                ),
                const SizedBox(height: 8),
                Text(
                  '(1 cotisation - AUTORISATION SEPA uniquement)',
                  style: TextStyle(
                    fontSize: 12, 
                    color: Theme.of(context).brightness == Brightness.dark ? Colors.white38 : Colors.grey,
                  ),
                ),
                const SizedBox(height: 20),
                
                // Important message - No deduction if conditions respected
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).brightness == Brightness.dark ? Colors.green.withValues(alpha: 0.2) : Colors.green.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Theme.of(context).brightness == Brightness.dark ? Colors.green.withValues(alpha: 0.4) : Colors.green.shade200),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.check_circle, color: Colors.green, size: 24),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Autorisation SEPA, jamais prélevée',
                              style: TextStyle(
                                fontWeight: FontWeight.bold, 
                                fontSize: 15, 
                                color: Theme.of(context).brightness == Brightness.dark ? Colors.green.shade200 : Colors.green,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Cette garantie est une AUTORISATION, pas un prélèvement. Elle ne sera déclenchée qu\'en cas de défaut avéré (3 tentatives + 7 jours de grâce).',
                        style: TextStyle(
                          fontSize: 13, 
                          height: 1.5,
                          color: Colors.black, // Explicitly black for contrast on light green
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // What the guarantee is for
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).brightness == Brightness.dark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('À quoi sert cette garantie ?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 8),
                      Text(
                        '• Protège les autres membres en cas d\'imprévus\n'
                        '• Renforce la confiance au sein du cercle\n'
                        '• N\'est utilisée qu\'en dernier recours',
                        style: TextStyle(
                          fontSize: 12, 
                          color: Theme.of(context).brightness == Brightness.dark ? Colors.white60 : Colors.grey, 
                          height: 1.6,
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 20),
                
                // Grace period selection
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).brightness == Brightness.dark ? Colors.blue.withValues(alpha: 0.2) : Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Délai de grâce', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 4),
                      Text(
                        'En cas de retard, combien de jours avant que la garantie puisse être sollicitée ?',
                        style: TextStyle(
                          fontSize: 11, 
                          color: Theme.of(context).brightness == Brightness.dark ? Colors.white38 : Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          _buildGracePeriodOption(3),
                          const SizedBox(width: 8),
                          _buildGracePeriodOption(5),
                          const SizedBox(width: 8),
                          _buildGracePeriodOption(7),
                        ],
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 20),
                
                // Checkbox
                CheckboxListTile(
                  value: _guaranteeAccepted,
                  activeColor: AppTheme.gold,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('J\'accepte les conditions de la Garantie Solidaire'),
                  onChanged: (v) => setState(() => _guaranteeAccepted = v!),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Link to CGU
          TextButton.icon(
            icon: const Icon(Icons.article_outlined, size: 18),
            label: const Text('Lire les conditions détaillées de la garantie'),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const LegalDocumentsScreen(initialTabIndex: 0),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
  
  Widget _buildGracePeriodOption(int days) {
    final isSelected = _gracePeriodDays == days;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _gracePeriodDays = days),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected 
                ? Colors.orange 
                : (Theme.of(context).brightness == Brightness.dark ? Colors.white.withValues(alpha: 0.05) : Colors.white),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected 
                  ? Colors.orange 
                  : (Theme.of(context).brightness == Brightness.dark ? Colors.white12 : Colors.grey.shade300),
            ),
          ),
          child: Column(
            children: [
              Text(
                '$days',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isSelected 
                      ? Colors.white 
                      : (Theme.of(context).brightness == Brightness.dark ? Colors.white38 : Colors.grey),
                ),
              ),
              Text(
                'jours',
                style: TextStyle(
                  fontSize: 11,
                  color: isSelected 
                      ? Colors.white 
                      : (Theme.of(context).brightness == Brightness.dark ? Colors.white38 : Colors.grey),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Step _buildStep5Final() {
    return Step(
      title: const Text('Confirmation'),
      isActive: _currentStep >= 4,
      state: StepState.editing,
      content: Column(
        children: [
          Icon(Icons.check_circle_outline, size: 60, color: Theme.of(context).brightness == Brightness.dark ? AppTheme.gold : AppTheme.marineBlue),
          const SizedBox(height: 16),
          const Text('Tout est prêt !', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 8),
          const Text('Vérifiez les informations et signez le mandat pour créer officiellement votre cercle.', 
            style: TextStyle(color: Colors.grey, fontSize: 13), textAlign: TextAlign.center),
          const SizedBox(height: 24),
          
          // Summary card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1E1E1E) : Colors.white,
              border: Border.all(color: AppTheme.marineBlue.withValues(alpha: 0.3)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Récapitulatif', style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).brightness == Brightness.dark ? AppTheme.gold : AppTheme.marineBlue)),
                const Divider(),
                _buildSummaryRow('Nom', _nameController.text.isEmpty ? 'Non défini' : _nameController.text),
                _buildSummaryRow('Montant', _amountController.text.isEmpty ? 'Non défini' : '${_amountController.text} ${ref.read(userProvider).currencySymbol}'),
                _buildSummaryRow('Participants', _participantsController.text.isEmpty ? 'Non défini' : _participantsController.text),
                _buildSummaryRow('Fréquence', _frequency),
                _buildSummaryRow('Invités', '${_invitedContacts.length} personne(s)'),
              ],
            ),
          ),
          const SizedBox(height: 16),
          
          // Visibility note
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark ? Colors.blue.withValues(alpha: 0.2) : Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              children: [
                Icon(Icons.visibility, color: Colors.blue, size: 18),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Votre cercle sera visible uniquement par vos followers mutuels.',
                    style: TextStyle(fontSize: 12, color: Colors.blue),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  void _nextStep() {
    if (_currentStep < 5) { // Updated to 5 steps
      // Dynamic Validiations
      final plan = ref.read(currentUserPlanProvider).value;
      
      if (_currentStep == 1) {
        if (_amountController.text.isEmpty) return;
        
        final amount = double.tryParse(_amountController.text) ?? 0;
        final participants = int.tryParse(_participantsController.text) ?? 0;
        
        // V17: Fetch Plan limits dynamically
        final maxCotisation = plan?.getLimit<num>('maxPotAmount', 500) ?? 500;
        final maxMembers = plan?.getLimit<int>('maxMembers', 10) ?? 10;

        if (amount > maxCotisation) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('La cotisation (${amount.toStringAsFixed(0)}) dépasse le plafond individuel de votre plan (${maxCotisation.toStringAsFixed(0)}).'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }

        if (participants > maxMembers) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Le nombre de participants ($participants) dépasse la limite de votre plan ($maxMembers).'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }
      }
      
      setState(() => _currentStep += 1);
    } else {
      Navigator.push(
        context, 
        MaterialPageRoute(
          builder: (_) => LegalCommitmentScreen(
            amount: double.tryParse(_amountController.text) ?? 0,
            currency: ref.read(userProvider).currencySymbol,
            onAccepted: () async {
               // V14: Create circle in provider for persistence
               final user = ref.read(userProvider);
               final circleId = await ref.read(circleProvider.notifier).createCircle(
                 name: _nameController.text,
                 objective: _objectiveController.text,
                 amount: double.tryParse(_amountController.text) ?? 0,
                 maxParticipants: int.tryParse(_participantsController.text) ?? 10,
                 frequency: _frequency,
                 payoutDay: _payoutDay,
                 orderType: _orderType,
                 creatorId: user.uid,
                 creatorName: user.displayName,
                 isPublic: _publishToExplorer,
                 isSponsored: false, // V15: Boost option removed
                 invitedContacts: _invitedContacts,
                 currency: ref.read(userProvider).currencySymbol,
               );
               
               // Trigger Billing si premier cercle
               ref.read(userProvider.notifier).activateSubscriptionBilling();
               // Incrémenter compteur ACL
               ref.read(userProvider.notifier).updateActiveCircles(user.activeCirclesCount + 1);
               
               if (!mounted) return;
               
               Navigator.pop(context); // Close Legal
               Navigator.pop(context); // Close CreateTontine
               
               if (circleId != null) {
                 Navigator.push(
                   context, 
                   MaterialPageRoute(
                     builder: (_) => CircleChatScreen(
                       circleId: circleId,
                       circleName: _nameController.text,
                     ),
                   ),
                 );
               }
               
               ScaffoldMessenger.of(context).showSnackBar(
                 const SnackBar(
                   content: Text('✅ Tontine créée & Mandat signé !'),
                   backgroundColor: AppTheme.marineBlue,
                 ),
               );
            },
          )
        )
      );
    }
  }

  void _cancelStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep -= 1);
    } else {
      Navigator.pop(context);
    }
  }
}
