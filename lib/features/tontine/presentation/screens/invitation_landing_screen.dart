import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tontetic/core/theme/app_theme.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tontetic/core/providers/user_provider.dart';
import 'package:tontetic/core/models/user_model.dart';
import 'package:tontetic/features/auth/presentation/screens/type_selection_screen.dart';
import 'package:tontetic/features/auth/presentation/screens/psp_connection_screen.dart';
import 'package:go_router/go_router.dart';
import 'package:tontetic/features/tontine/presentation/screens/legal_commitment_screen.dart';

/// V15: Invitation Landing Flow
/// Secure multi-step process for joining a tontine via invitation link
/// 
/// Steps:
/// 1. Circle presentation (no payment mention)
/// 2. Login or signup
/// 3. Contract signing (no banking info)
/// 4. Creator approval wait
/// 5. PSP connection (only after approval)

class InvitationLandingScreen extends ConsumerStatefulWidget {
  final String invitationCode;
  final String? circleName;
  
  const InvitationLandingScreen({
    super.key,
    required this.invitationCode,
    this.circleName,
  });

  @override
  ConsumerState<InvitationLandingScreen> createState() => _InvitationLandingScreenState();
}

class _InvitationLandingScreenState extends ConsumerState<InvitationLandingScreen> {
  int _currentStep = 0;
  bool _contractSigned = false;

  bool _isApproved = false;
  
  // Data should be fetched via invitationCode
  Map<String, dynamic>? _circleData;
  String _requestId = '';
  String? _errorMessage;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchCircleDetails();
  }

  Future<void> _fetchCircleDetails() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final doc = await FirebaseFirestore.instance
          .collection('tontines')
          .doc(widget.invitationCode)
          .get();

      if (doc.exists && mounted) {
        final data = doc.data()!;
        
        // Fetch creator details for avatar and score
        String creatorAvatar = '👤';
        int creatorScore = 100;
        
        try {
          final creatorId = data['creatorId'];
          if (creatorId != null) {
            final userDoc = await FirebaseFirestore.instance.collection('users').doc(creatorId).get();
            if (userDoc.exists) {
              final userData = userDoc.data()!;
              creatorAvatar = userData['photoUrl'] != null ? '🖼️' : (userData['fullName'] ?? 'U').substring(0, 1).toUpperCase();
              creatorScore = userData['honorScore'] ?? 100;
            }
          }
        } catch (e) {
          debugPrint('Error fetching creator: $e');
        }

        if (mounted) {
          setState(() {
            _circleData = {
              'name': data['name'] ?? 'Cercle sans nom',
              'estimatedAmount': '${data['amount'] ?? 0}',
              'currency': data['currency'] ?? 'FCFA',
              'frequency': data['frequency'] ?? 'Mensuel',
              'orderType': data['orderType'] ?? 'Aléatoire',
              'creatorName': data['creatorName'] ?? 'Un membre',
              'creatorAvatar': creatorAvatar,
              'creatorScore': creatorScore,
              'objective': data['objective'] ?? 'Épargne solidaire',
              'memberCount': (data['memberIds'] as List?)?.length ?? 0,
              'maxMembers': data['maxParticipants'] ?? 10,
            };
            _isLoading = false;
          });
        }
      } else if (mounted) {
        setState(() {
          _errorMessage = 'Cercle introuvable ou invitation expirée.';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Une erreur est survenue lors du chargement : ${e.toString()}';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Chargement de l\'invitation...'),
            ],
          ),
        ),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 24),
                Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('RETOUR'),
                  ),
                ),
                TextButton(
                  onPressed: _fetchCircleDetails,
                  child: const Text('RÉESSAYER'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Assuming localizationProvider exists and is imported
    // final l10n = ref.watch(localizationProvider); 
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // Progress indicator
            _buildProgressIndicator(),
            
            // Content
            Expanded(
              child: _buildCurrentStep(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressIndicator() {
    final steps = ['Découverte', 'Contrat', 'Compte', 'Validation', 'Paiement'];
    
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Column(
        children: [
          Row(
            children: List.generate(steps.length, (index) {
              final isCompleted = index < _currentStep;
              final isCurrent = index == _currentStep;
              
              return Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 4,
                        decoration: BoxDecoration(
                          color: isCompleted || isCurrent 
                            ? AppTheme.gold 
                            : Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    if (index < steps.length - 1) const SizedBox(width: 4),
                  ],
                ),
              );
            }),
          ),
          const SizedBox(height: 8),
          Text(
            steps[_currentStep],
            style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).brightness == Brightness.dark ? AppTheme.gold : AppTheme.marineBlue),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentStep() {
    switch (_currentStep) {
      case 0:
        return _buildStep1Discovery();
      case 1:
        return _buildStep2Contract();
      case 2:
        return _buildStep3Auth();
      case 3:
        return _buildStep4Approval();
      case 4:
        return _buildStep5PSP();
      default:
        return _buildStep1Discovery();
    }
  }

  /// STEP 1: Circle Discovery - No payment mention
  Widget _buildStep1Discovery() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // Welcome banner
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppTheme.marineBlue, AppTheme.marineBlue.withValues(alpha: 0.8)],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                const Icon(Icons.mail_outline, size: 48, color: Colors.white),
                const SizedBox(height: 16),
                const Text(
                  'Vous avez été invité(e) !',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${_circleData!['creatorName']} vous invite à rejoindre son cercle d\'épargne solidaire.',
                  style: const TextStyle(color: Colors.white70),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Creator profile
          _buildCreatorCard(),
          
          const SizedBox(height: 24),
          
          // Circle info (NO amounts shown)
          _buildCircleInfoCard(),
          
          const SizedBox(height: 24),
          
          // Trust indicators
          _buildTrustIndicators(),
          
          const SizedBox(height: 32),
          
          // CTA
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.gold,
                foregroundColor: AppTheme.marineBlue,
              ),
              onPressed: () => setState(() => _currentStep = 1),
              child: const Text('DÉCOUVRIR LE CERCLE'),
            ),
          ),
          
          const SizedBox(height: 12),
          
          TextButton(
            onPressed: () => context.go('/'),
            child: const Text('Non merci'),
          ),
        ],
      ),
    );
  }

  Widget _buildCreatorCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: AppTheme.gold,
            child: Text(
              _circleData!['creatorAvatar'],
              style: const TextStyle(fontSize: 28),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _circleData!['creatorName'],
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.verified, size: 16, color: Colors.green),
                    const SizedBox(width: 4),
                    const Text('Profil vérifié', style: TextStyle(fontSize: 12, color: Colors.green)),
                    const SizedBox(width: 12),
                    const Icon(Icons.star, size: 16, color: AppTheme.gold),
                    const SizedBox(width: 4),
                    Text('Score: ${_circleData!['creatorScore']}%', style: const TextStyle(fontSize: 12)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCircleInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.circle, color: Theme.of(context).brightness == Brightness.dark ? AppTheme.gold : AppTheme.marineBlue),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _circleData!['name'],
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          _buildInfoRow(Icons.flag, 'Objectif', _circleData!['objective']),
          _buildInfoRow(Icons.people, 'Participants', '${_circleData!['memberCount']}/${_circleData!['maxMembers']} membres'),
          _buildInfoRow(Icons.calendar_today, 'Fréquence', _circleData!['frequency']),
          _buildInfoRow(Icons.how_to_vote, 'Ordre des tours', _circleData!['orderType']),
          
          // Note: No amount shown at this step
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Les détails financiers seront présentés à l\'étape suivante.',
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

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey),
          const SizedBox(width: 12),
          Text('$label : ', style: const TextStyle(color: Colors.grey)),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }

  Widget _buildTrustIndicators() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildTrustBadge(Icons.security, 'Sécurisé'),
        _buildTrustBadge(Icons.gavel, 'Légal'),
        _buildTrustBadge(Icons.people, 'Solidaire'),
      ],
    );
  }

  Widget _buildTrustBadge(IconData icon, String label) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.marineBlue.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Theme.of(context).brightness == Brightness.dark ? AppTheme.gold : AppTheme.marineBlue),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  /// STEP 2: Contract Signing (Using Official LegalCommitmentScreen)
  Widget _buildStep2Contract() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Amount reveal
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.gold.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.gold),
            ),
            child: Column(
              children: [
                const Text('Montant de la cotisation', style: TextStyle(color: Colors.grey)),
                const SizedBox(height: 8),
                Text(
                  '${_circleData!['estimatedAmount']} ${_circleData!['currency']}',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).brightness == Brightness.dark ? AppTheme.gold : AppTheme.marineBlue,
                  ),
                ),
                Text('par ${_circleData!['frequency'].toLowerCase()}', style: const TextStyle(color: Colors.grey)),
              ],
            ),
          ),
          
          const SizedBox(height: 32),
          
          if (_contractSigned) ...[
             Container(
               padding: const EdgeInsets.all(16),
               decoration: BoxDecoration(
                 color: Colors.green.withValues(alpha: 0.1),
                 borderRadius: BorderRadius.circular(12),
                 border: Border.all(color: Colors.green),
               ),
               child: const Row(
                 children: [
                   Icon(Icons.check_circle, color: Colors.green, size: 32),
                   SizedBox(width: 16),
                   Expanded(
                     child: Column(
                       crossAxisAlignment: CrossAxisAlignment.start,
                       children: [
                         Text('Contrat Signé', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green)),
                         Text('Vos mandats SEPA et engagements ont été enregistrés.', style: TextStyle(fontSize: 12)),
                       ],
                     ),
                   ),
                 ],
               ),
             ),
             const SizedBox(height: 24),
          ] else ...[
             const Text(
              'Pour rejoindre ce cercle, vous devez lire et signer le contrat d\'engagement légal complet (Mandats SEPA A & B + Clause Pénale).',
              textAlign: TextAlign.center,
              style: TextStyle(height: 1.5),
            ),
            const SizedBox(height: 24),
             SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.description),
                label: const Text('LIRE ET SIGNER LE CONTRAT'),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: AppTheme.marineBlue),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                onPressed: () {
                   // Parse amount
                   final amountStr = _circleData!['estimatedAmount'].toString();
                   final amount = double.tryParse(amountStr.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0.0;
                   
                   Navigator.push(
                     context,
                     MaterialPageRoute(
                       builder: (_) => LegalCommitmentScreen(
                         amount: amount,
                         currency: _circleData!['currency'],
                         onAccepted: () {
                           Navigator.pop(context); // Close contract
                           setState(() => _contractSigned = true);
                         },
                       ),
                     ),
                   );
                },
              ),
            ),
            const SizedBox(height: 24),
          ],

          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.person_add),
              label: const Text('CRÉER UN COMPTE / REJOINDRE'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _contractSigned ? AppTheme.gold : Colors.grey,
                foregroundColor: _contractSigned ? AppTheme.marineBlue : Colors.white,
              ),
              onPressed: _contractSigned
                ? () {
                    // Check if already logged in
                    final user = ref.read(userProvider);
                    if (user.status != AccountStatus.guest) {
                      _submitJoinRequest();
                    } else {
                      setState(() => _currentStep = 2);
                    }
                  }
                : null,
            ),
          ),
          
          const SizedBox(height: 12),
          
          TextButton.icon(
            icon: const Icon(Icons.arrow_back),
            label: const Text('Retour'),
            onPressed: () => setState(() => _currentStep = 0),
          ),
        ],
      ),
    );
  }

  /// STEP 3: Authentication (Triggered after contract)
  Widget _buildStep3Auth() {
    final user = ref.watch(userProvider);
    final isLoggedIn = user.status != AccountStatus.guest;
    
    if (isLoggedIn) {
      // Auto-submit request once logged in
      Future.microtask(() => _submitJoinRequest());
      return const Center(child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Finalisation de la demande...'),
        ],
      ));
    }
    
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.account_circle, size: 80, color: Theme.of(context).brightness == Brightness.dark ? AppTheme.gold : AppTheme.marineBlue),
          const SizedBox(height: 24),
          const Text(
            'Connectez-vous pour continuer',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          const Text(
            'Un compte est nécessaire pour rejoindre le cercle.',
            style: TextStyle(color: Colors.grey),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.marineBlue,
              ),
              onPressed: () {
                // Navigate to login/signup
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const TypeSelectionScreen()),
                ).then((_) {
                  // Check if logged in after returning
                  final user = ref.read(userProvider);
                  if (user.status != AccountStatus.guest) {
                    // Will auto-submit via the check at top of build
                  }
                });
              },
              child: const Text('SE CONNECTER / CRÉER UN COMPTE'),
            ),
          ),
          
          const SizedBox(height: 16),
          
          TextButton.icon(
            icon: const Icon(Icons.arrow_back),
            label: const Text('Retour'),
            onPressed: () => setState(() => _currentStep = 1),
          ),
        ],
      ),
    );
  }

  Future<void> _submitJoinRequest() async {
     try {
      final user = ref.read(userProvider);
      
      // Prevent duplicate submissions
      if (_requestId.isNotEmpty) {
         setState(() => _currentStep = 3);
         return;
      }

      // Submit request
      final docRef = await FirebaseFirestore.instance.collection('join_requests').add({
        'circleId': widget.invitationCode, 
        'circleName': _circleData?['name'] ?? widget.circleName ?? 'Cercle',
        'requesterId': user.uid,
        'requesterName': user.displayName,
        'status': 'pending',
        'timestamp': FieldValue.serverTimestamp(),
        'message': 'Joined via Invitation Link',
      });
      
      if (mounted) {
        setState(() {
          _requestId = docRef.id;
          _currentStep = 3;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
    }
  }


  Widget _buildContractPoint(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Text(text, style: const TextStyle(height: 1.5)),
    );
  }

  /// STEP 4: Waiting for Creator Approval
  Widget _buildStep4Approval() {
    if (_isApproved) {
      Future.microtask(() => setState(() => _currentStep = 4));
      return const Center(child: CircularProgressIndicator());
    }
    
    return StreamBuilder<DocumentSnapshot>(
      stream: _requestId.isNotEmpty 
          ? FirebaseFirestore.instance.collection('join_requests').doc(_requestId).snapshots()
          : null,
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>;
          if (data['status'] == 'approved') {
            // Auto-advance to next step
            WidgetsBinding.instance.addPostFrameCallback((_) {
               if (mounted && !_isApproved) {
                 setState(() {
                   _isApproved = true;
                   _currentStep = 4;
                 });
               }
            });
          } else if (data['status'] == 'rejected') {
             return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
               const Icon(Icons.cancel, size: 64, color: Colors.red),
               const SizedBox(height: 16),
               const Text('Demande refusée', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
               const SizedBox(height: 8),
               TextButton(onPressed: () => Navigator.pop(context), child: const Text('Retour'))
             ]));
          }
        }

        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Animated waiting indicator
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.hourglass_top, size: 64, color: Colors.orange),
              ),
              const SizedBox(height: 32),
              
              const Text(
                'En attente de validation',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Text(
                '${_circleData!['creatorName']} doit valider votre demande d\'adhésion.',
                style: const TextStyle(color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 32),
              
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(Icons.notifications_active, color: Theme.of(context).brightness == Brightness.dark ? AppTheme.gold : AppTheme.marineBlue),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Vous recevrez une notification dès que ${_circleData!['creatorName']} validera votre demande.',
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    Row(
                      children: [
                        const Icon(Icons.timer, color: Colors.grey),
                        const SizedBox(width: 12),
                        const Text('Délai moyen : ', style: TextStyle(color: Colors.grey)),
                        const Text('< 24h', style: TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 32),
              
              const Text('Vous serez notifié par SMS/email.', style: TextStyle(color: Colors.grey, fontSize: 12)),
              
              const SizedBox(height: 16),
              
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Retour à l\'accueil'),
              ),
            ],
          ),
        );
      },
    );
  }

  /// STEP 5: PSP Connection (Only after approval)
  Widget _buildStep5PSP() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Success badge
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.green.shade100,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_circle, size: 64, color: Colors.green),
          ),
          const SizedBox(height: 24),
          
          const Text(
            'Demande acceptée ! 🎉',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Text(
            '${_circleData!['creatorName']} a validé votre adhésion au cercle.',
            style: const TextStyle(color: Colors.grey),
            textAlign: TextAlign.center,
          ),
          
          const SizedBox(height: 32),
          
          // PSP connection info
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.marineBlue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(Icons.account_balance, color: Theme.of(context).brightness == Brightness.dark ? AppTheme.gold : AppTheme.marineBlue),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Dernière étape : Connectez votre compte bancaire',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const Divider(height: 24),
                const Text(
                  'Vous serez redirigé vers notre partenaire de paiement sécurisé (Stripe/Wave) pour configurer les prélèvements.',
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
                const SizedBox(height: 12),
                const Row(
                  children: [
                    Icon(Icons.lock, size: 16, color: Colors.green),
                    SizedBox(width: 8),
                    Text(
                      'Vos données bancaires ne sont jamais stockées par Tontetic.',
                      style: TextStyle(fontSize: 11, color: Colors.green),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 32),
          
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.account_balance_wallet),
              label: const Text('CONNECTER MON COMPTE'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.gold,
                foregroundColor: AppTheme.marineBlue,
              ),
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => PspConnectionScreen()),
                );
              },
            ),
          ),
          
          const SizedBox(height: 12),
          
          TextButton(
            onPressed: () {
              // Show reminder that they can do this later
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Vous pourrez connecter votre compte plus tard depuis Paramètres.'),
                ),
              );
              Navigator.pop(context);
            },
            child: const Text('Plus tard'),
          ),
        ],
      ),
    );
  }
}
