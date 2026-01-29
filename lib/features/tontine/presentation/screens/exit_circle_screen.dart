import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tontetic/core/theme/app_theme.dart';
import 'package:tontetic/core/providers/user_provider.dart';
import 'package:tontetic/features/social/data/social_provider.dart';

/// V15: Exit Circle Screen
/// Allows a member to leave a circle by inviting a mutual follower as replacement
/// 
/// Rules:
/// - Member must propose a replacement from their mutual followers
/// - The replacement must accept and be validated by the circle creator
/// - Only then can the original member leave

class ExitCircleScreen extends ConsumerStatefulWidget {
  final String circleName;
  final String circleId;
  final double monthlyAmount;
  final int remainingMonths;
  
  const ExitCircleScreen({
    super.key,
    required this.circleName,
    required this.circleId,
    this.monthlyAmount = 50000,
    this.remainingMonths = 6,
  });

  @override
  ConsumerState<ExitCircleScreen> createState() => _ExitCircleScreenState();
}

class _ExitCircleScreenState extends ConsumerState<ExitCircleScreen> {
  int _currentStep = 0;
  String? _selectedReplacementId;
  String? _selectedReplacementName;
  bool _isSubmitting = false;
  
  // Controllers for external invite
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  
  // Get mutual followers from social provider - REAL DATA
  List<Map<String, dynamic>> get _mutualFollowers {
    final socialState = ref.watch(socialProvider);
    final currentUserId = ref.watch(userProvider).phoneNumber;
    final mutualIds = socialState.getMutualFollowers(currentUserId);
    
    // Map IDs to display objects - names will be fetched from Firestore in future
    return mutualIds.map((id) => {
      'id': id,
      'name': 'User ${id.length > 6 ? id.substring(0, 6) : id}',
      'avatar': '👤',
      'score': 0,
      'isMutual': true,
    }).toList();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quitter le Cercle'),
        backgroundColor: Colors.red.shade700,
      ),
      body: Column(
        children: [
          // Progress stepper
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey.shade100,
            child: Row(
              children: [
                _buildStepIndicator(0, 'Conditions'),
                _buildStepConnector(0),
                _buildStepIndicator(1, 'Remplaçant'),
                _buildStepConnector(1),
                _buildStepIndicator(2, 'Confirmation'),
              ],
            ),
          ),
          
          // Content
          Expanded(
            child: _buildCurrentStep(),
          ),
        ],
      ),
    );
  }

  Widget _buildStepIndicator(int step, String label) {
    final isActive = _currentStep >= step;
    final isCurrent = _currentStep == step;
    
    return Expanded(
      child: Column(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: isActive ? Colors.red : Colors.grey.shade300,
              shape: BoxShape.circle,
              border: isCurrent ? Border.all(color: Colors.red.shade900, width: 2) : null,
            ),
            child: Center(
              child: isActive && !isCurrent
                ? const Icon(Icons.check, color: Colors.white, size: 16)
                : Text('${step + 1}', style: TextStyle(color: isActive ? Colors.white : Colors.grey)),
            ),
          ),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 10, color: isActive ? Colors.red : Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildStepConnector(int step) {
    final isActive = _currentStep > step;
    return Container(
      width: 30,
      height: 2,
      color: isActive ? Colors.red : Colors.grey.shade300,
    );
  }

  Widget _buildCurrentStep() {
    switch (_currentStep) {
      case 0:
        return _buildStep1Conditions();
      case 1:
        return _buildStep2SelectReplacement();
      case 2:
        return _buildStep3Confirmation();
      default:
        return _buildStep1Conditions();
    }
  }

  /// STEP 1: Show conditions and warning
  Widget _buildStep1Conditions() {
    final currencySymbol = ref.read(userProvider).currencySymbol;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Warning banner
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.red.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.warning, color: Colors.red.shade700, size: 32),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Attention !',
                        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red.shade700),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Quitter un cercle en cours a des conséquences importantes.',
                        style: TextStyle(fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          const Text('Conditions de départ :', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 16),
          
          // Condition 1: Find replacement
          _buildConditionTile(
            icon: Icons.person_add,
            title: 'Proposer un remplaçant',
            description: 'Vous devez inviter un de vos followers mutuels à prendre votre place dans le cercle.',
            isRequired: true,
          ),
          
          // Condition 2: Replacement must accept
          _buildConditionTile(
            icon: Icons.handshake,
            title: 'Acceptation du remplaçant',
            description: 'Le remplaçant doit accepter l\'invitation et signer le mandat.',
            isRequired: true,
          ),
          
          // Condition 3: Creator approval
          _buildConditionTile(
            icon: Icons.verified_user,
            title: 'Validation du créateur',
            description: 'Le créateur du cercle doit approuver le remplaçant proposé.',
            isRequired: true,
          ),
          
          const SizedBox(height: 24),
          
          // Financial summary
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Récapitulatif', style: TextStyle(fontWeight: FontWeight.bold)),
                const Divider(),
                _buildInfoRow('Cercle', widget.circleName),
                _buildInfoRow('Engagement restant', '${widget.remainingMonths} mois'),
                _buildInfoRow('Montant total restant', '${(widget.monthlyAmount * widget.remainingMonths).toInt()} $currencySymbol'),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Note
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue, size: 18),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Le remplaçant reprendra vos engagements restants à partir du cycle suivant.',
                    style: TextStyle(fontSize: 12, color: Colors.blue),
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 32),
          
          // Continue button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => setState(() => _currentStep = 1),
              child: const Text('CONTINUER'),
            ),
          ),
          
          const SizedBox(height: 12),
          
          Center(
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler', style: TextStyle(color: Colors.grey)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConditionTile({
    required IconData icon,
    required String title,
    required String description,
    required bool isRequired,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.red, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                    if (isRequired) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text('Requis', style: TextStyle(fontSize: 9, color: Colors.white)),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(description, style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
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

  /// STEP 2: Select replacement from mutual followers
  Widget _buildStep2SelectReplacement() {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Choisir un remplaçant',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Sélectionnez un de vos followers mutuels ou invitez quelqu\'un par téléphone/email.',
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 24),
                
                // Mutual followers section
                if (_mutualFollowers.isNotEmpty) ...[
                  const Text('Vos followers mutuels :', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 12),
                  ..._mutualFollowers.map((follower) => _buildFollowerSelectionTile(follower)),
                  const SizedBox(height: 24),
                ],
                
                // Divider with "OR"
                Row(
                  children: [
                    Expanded(child: Divider(color: Colors.grey.shade300)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text('OU', style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.bold)),
                    ),
                    Expanded(child: Divider(color: Colors.grey.shade300)),
                  ],
                ),
                
                const SizedBox(height: 24),
                
                // Invite by phone/email
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.person_add, color: Colors.blue),
                          SizedBox(width: 8),
                          Text('Inviter quelqu\'un', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Invitez une personne par téléphone ou email. Elle devra créer un compte et vous suivre mutuellement.',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 16),
                      
                      // Phone input
                      TextField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: InputDecoration(
                          labelText: 'Numéro de téléphone',
                          prefixIcon: const Icon(Icons.phone),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 12),
                      
                      // Email input
                      TextField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          labelText: 'Adresse email',
                          prefixIcon: const Icon(Icons.email),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                      ),
                      
                      const SizedBox(height: 12),
                      
                      // Info note
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.info_outline, size: 16, color: Colors.orange),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'L\'invité devra d\'abord devenir votre follower mutuel avant de pouvoir vous remplacer.',
                                style: TextStyle(fontSize: 11, color: Colors.orange),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Link to find replacement
                if (_mutualFollowers.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.orange.shade200),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.person_search, size: 40, color: Colors.orange),
                        const SizedBox(height: 12),
                        const Text(
                          'Vous n\'avez pas de followers mutuels ?',
                          style: TextStyle(fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Trouvez des personnes de confiance à suivre pour avoir plus d\'options.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        const SizedBox(height: 16),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.search),
                          label: const Text('Trouver des remplaçants potentiels'),
                          onPressed: () {
                            // Navigate to discover/social screen
                            Navigator.pop(context);
                            // TODO: Navigate to social discovery screen
                          },
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
        
        // Bottom actions
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => setState(() => _currentStep = 0),
                  child: const Text('Retour'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _canProceed ? Colors.red : Colors.grey,
                  ),
                  onPressed: _canProceed
                    ? () => setState(() => _currentStep = 2)
                    : null,
                  child: const Text('CONTINUER'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
  
  // Check if user can proceed (either selected follower OR entered phone/email)
  bool get _canProceed {
    return _selectedReplacementId != null || 
           _phoneController.text.trim().isNotEmpty || 
           _emailController.text.trim().isNotEmpty;
  }

  Widget _buildFollowerSelectionTile(Map<String, dynamic> follower) {
    final isSelected = _selectedReplacementId == follower['id'];
    
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedReplacementId = follower['id'];
          _selectedReplacementName = follower['name'];
        });
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.red.shade50 : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Colors.red : Colors.grey.shade200,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: AppTheme.gold,
              child: Text(follower['avatar'], style: const TextStyle(fontSize: 24)),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        follower['name'],
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.swap_horiz, size: 14, color: Colors.green),
                      const Text(' Mutuel', style: TextStyle(fontSize: 10, color: Colors.green)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.star, size: 14, color: AppTheme.gold),
                      const SizedBox(width: 4),
                      Text('Score: ${follower['score']}%', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                ],
              ),
            ),
            if (isSelected)
              Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check, color: Colors.white, size: 16),
              )
            else
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.add, color: Colors.grey, size: 16),
              ),
          ],
        ),
      ),
    );
  }

  /// STEP 3: Confirmation
  Widget _buildStep3Confirmation() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const Icon(Icons.swap_horiz, size: 64, color: Colors.red),
          const SizedBox(height: 24),
          const Text(
            'Confirmer le remplacement',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Text(
            'Vous allez envoyer une invitation à $_selectedReplacementName pour vous remplacer dans le cercle "${widget.circleName}".',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.grey),
          ),
          
          const SizedBox(height: 32),
          
          // Summary card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                _buildSummaryRow('Vous', 'Quitte le cercle'),
                const Divider(),
                _buildSummaryRow('Remplaçant', _selectedReplacementName ?? ''),
                const Divider(),
                _buildSummaryRow('Cercle', widget.circleName),
                const Divider(),
                _buildSummaryRow('Engagement transféré', '${widget.remainingMonths} mois'),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Process explanation
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Prochaines étapes :', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                _buildProcessStep(1, '$_selectedReplacementName reçoit l\'invitation'),
                _buildProcessStep(2, 'Il/elle accepte et signe le mandat'),
                _buildProcessStep(3, 'Le créateur du cercle valide'),
                _buildProcessStep(4, 'Vous êtes libéré de vos engagements'),
              ],
            ),
          ),
          
          const SizedBox(height: 32),
          
          // Submit button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              icon: _isSubmitting 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.send),
              label: Text(_isSubmitting ? 'ENVOI EN COURS...' : 'ENVOYER L\'INVITATION'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: _isSubmitting ? null : _submitReplacement,
            ),
          ),
          
          const SizedBox(height: 12),
          
          TextButton(
            onPressed: () => setState(() => _currentStep = 1),
            child: const Text('Choisir un autre remplaçant'),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildProcessStep(int number, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          CircleAvatar(
            radius: 12,
            backgroundColor: Colors.blue,
            child: Text('$number', style: const TextStyle(color: Colors.white, fontSize: 12)),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }

  void _submitReplacement() async {
    setState(() => _isSubmitting = true);
    
    // API call (Direct)

    
    setState(() => _isSubmitting = false);
    
    // Show success and close
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Invitation envoyée à $_selectedReplacementName !'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context);
    }
  }
}
