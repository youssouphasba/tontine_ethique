import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tontetic/core/theme/app_theme.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tontetic/core/providers/user_provider.dart';
import 'package:tontetic/core/models/user_model.dart';
import 'package:tontetic/features/auth/presentation/screens/type_selection_screen.dart';
import 'package:go_router/go_router.dart';
import 'package:tontetic/features/tontine/presentation/screens/legal_commitment_screen.dart';

/// V16: Simplified Invitation Landing Flow (3 steps)
///
/// Simplified flow for better UX:
/// 1. Présentation + Contrat (combined) - Shows all info upfront + contract signing
/// 2. Connexion - Login/signup if needed
/// 3. Terminé - Request submitted, user notified via push when approved
///
/// PSP connection is triggered via deep link from push notification after approval.

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
  bool _requestSubmitted = false;

  Map<String, dynamic>? _circleData;
  // ignore: unused_field
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

        // Fetch creator details
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
              'amount': data['amount'] ?? 0,
              'estimatedAmount': '${data['amount'] ?? 0}',
              'currency': data['currency'] ?? 'FCFA',
              'frequency': data['frequency'] ?? 'Mensuel',
              'orderType': data['orderType'] ?? 'Aléatoire',
              'creatorName': data['creatorName'] ?? 'Un membre',
              'creatorId': data['creatorId'],
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
          _errorMessage = 'Une erreur est survenue : ${e.toString()}';
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
      return _buildErrorScreen();
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildProgressIndicator(),
            Expanded(child: _buildCurrentStep()),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorScreen() {
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

  Widget _buildProgressIndicator() {
    // Simplified: 3 steps instead of 5
    final steps = ['Présentation', 'Connexion', 'Terminé'];
    final progress = (_currentStep + 1) / steps.length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.grey.shade200,
              valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.gold),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 12),
          // Step indicators
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(steps.length, (index) {
              final isCompleted = index < _currentStep;
              final isCurrent = index == _currentStep;

              return Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isCompleted ? Colors.green : (isCurrent ? AppTheme.gold : Colors.grey.shade300),
                    ),
                    child: Center(
                      child: isCompleted
                          ? const Icon(Icons.check, size: 14, color: Colors.white)
                          : Text(
                              '${index + 1}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: isCurrent ? AppTheme.marineBlue : Colors.grey,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    steps[index],
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                      color: isCurrent ? AppTheme.marineBlue : Colors.grey,
                    ),
                  ),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentStep() {
    switch (_currentStep) {
      case 0:
        return _buildStep1PresentationAndContract();
      case 1:
        return _buildStep2Auth();
      case 2:
        return _buildStep3Complete();
      default:
        return _buildStep1PresentationAndContract();
    }
  }

  /// STEP 1: Présentation + Contrat (Combined)
  /// Shows circle info WITH amount upfront + contract signing
  Widget _buildStep1PresentationAndContract() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Welcome banner with creator info
          _buildWelcomeBanner(),
          const SizedBox(height: 20),

          // Circle details with amount visible immediately
          _buildCircleDetailsCard(),
          const SizedBox(height: 20),

          // Amount highlight
          _buildAmountCard(),
          const SizedBox(height: 20),

          // Trust indicators
          _buildTrustIndicators(),
          const SizedBox(height: 24),

          // Contract section
          _buildContractSection(),
          const SizedBox(height: 24),

          // CTA Button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _contractSigned ? AppTheme.gold : Colors.grey.shade400,
                foregroundColor: AppTheme.marineBlue,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _contractSigned ? _proceedToAuth : null,
              child: Text(
                _contractSigned ? 'CONTINUER' : 'SIGNEZ LE CONTRAT POUR CONTINUER',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(height: 12),

          Center(
            child: TextButton(
              onPressed: () => context.go('/'),
              child: const Text('Non merci, retour à l\'accueil'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomeBanner() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.marineBlue, AppTheme.marineBlue.withValues(alpha: 0.85)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: AppTheme.gold,
            child: Text(
              _circleData!['creatorAvatar'],
              style: const TextStyle(fontSize: 24),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Vous êtes invité(e) !',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_circleData!['creatorName']} vous invite à rejoindre son cercle.',
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.verified, size: 14, color: Colors.greenAccent),
                    const SizedBox(width: 4),
                    Text(
                      'Score: ${_circleData!['creatorScore']}%',
                      style: const TextStyle(color: Colors.white70, fontSize: 11),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCircleDetailsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.people_alt, color: AppTheme.marineBlue),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _circleData!['name'],
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                ),
              ),
            ],
          ),
          const Divider(height: 20),
          _buildInfoRow(Icons.flag_outlined, 'Objectif', _circleData!['objective']),
          _buildInfoRow(Icons.group_outlined, 'Participants', '${_circleData!['memberCount']}/${_circleData!['maxMembers']}'),
          _buildInfoRow(Icons.calendar_today_outlined, 'Fréquence', _circleData!['frequency']),
          _buildInfoRow(Icons.shuffle, 'Ordre', _circleData!['orderType']),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey),
          const SizedBox(width: 10),
          Text('$label : ', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
          Expanded(
            child: Text(value, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Widget _buildAmountCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.gold.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.gold, width: 1.5),
      ),
      child: Column(
        children: [
          const Text(
            'Cotisation requise',
            style: TextStyle(color: Colors.grey, fontSize: 13),
          ),
          const SizedBox(height: 8),
          Text(
            '${_circleData!['estimatedAmount']} ${_circleData!['currency']}',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: AppTheme.marineBlue,
            ),
          ),
          Text(
            'par ${(_circleData!['frequency'] as String).toLowerCase()}',
            style: const TextStyle(color: Colors.grey, fontSize: 13),
          ),
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
        _buildTrustBadge(Icons.account_balance, 'Garanti'),
      ],
    );
  }

  Widget _buildTrustBadge(IconData icon, String label) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppTheme.marineBlue.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: AppTheme.marineBlue, size: 22),
        ),
        const SizedBox(height: 6),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }

  Widget _buildContractSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _contractSigned ? Colors.green.shade50 : Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _contractSigned ? Colors.green : Colors.orange,
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                _contractSigned ? Icons.check_circle : Icons.description,
                color: _contractSigned ? Colors.green : Colors.orange,
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _contractSigned ? 'Contrat signé ✓' : 'Engagement légal requis',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: _contractSigned ? Colors.green.shade700 : Colors.orange.shade800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _contractSigned
                          ? 'Mandats SEPA et engagements enregistrés'
                          : 'Mandats SEPA A & B + Clause pénale',
                      style: TextStyle(
                        fontSize: 12,
                        color: _contractSigned ? Colors.green.shade600 : Colors.orange.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (!_contractSigned) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.edit_document),
                label: const Text('LIRE ET SIGNER'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.orange.shade800,
                  side: BorderSide(color: Colors.orange.shade800),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: _openContractScreen,
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _openContractScreen() {
    final amount = (_circleData!['amount'] as num).toDouble();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LegalCommitmentScreen(
          amount: amount,
          currency: _circleData!['currency'],
          onAccepted: () {
            Navigator.pop(context);
            if (mounted) {
              setState(() => _contractSigned = true);
            }
          },
        ),
      ),
    );
  }

  void _proceedToAuth() {
    final user = ref.read(userProvider);
    if (user.status != AccountStatus.guest) {
      // Already logged in, submit request directly
      _submitJoinRequest();
    } else {
      // Need to login/signup
      setState(() => _currentStep = 1);
    }
  }

  /// STEP 2: Authentication
  Widget _buildStep2Auth() {
    final user = ref.watch(userProvider);
    final isLoggedIn = user.status != AccountStatus.guest;

    if (isLoggedIn) {
      // Auto-submit once logged in
      Future.microtask(() => _submitJoinRequest());
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Envoi de votre demande...'),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.account_circle,
            size: 80,
            color: AppTheme.marineBlue,
          ),
          const SizedBox(height: 24),
          const Text(
            'Connectez-vous pour continuer',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          const Text(
            'Un compte Tontetic est nécessaire pour rejoindre ce cercle.',
            style: TextStyle(color: Colors.grey),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),

          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.login),
              label: const Text('SE CONNECTER / CRÉER UN COMPTE'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.marineBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const TypeSelectionScreen()),
                ).then((_) {
                  // Check if logged in after returning
                  if (mounted) {
                    final user = ref.read(userProvider);
                    if (user.status != AccountStatus.guest) {
                      _submitJoinRequest();
                    }
                  }
                });
              },
            ),
          ),

          const SizedBox(height: 16),

          TextButton.icon(
            icon: const Icon(Icons.arrow_back),
            label: const Text('Retour'),
            onPressed: () => setState(() => _currentStep = 0),
          ),
        ],
      ),
    );
  }

  Future<void> _submitJoinRequest() async {
    if (_requestSubmitted) {
      setState(() => _currentStep = 2);
      return;
    }

    try {
      final user = ref.read(userProvider);

      // Submit join request to Firestore
      final docRef = await FirebaseFirestore.instance.collection('join_requests').add({
        'circleId': widget.invitationCode,
        'circleName': _circleData?['name'] ?? widget.circleName ?? 'Cercle',
        'requesterId': user.uid,
        'requesterName': user.displayName,
        'requesterEmail': user.email,
        'status': 'pending',
        'contractSigned': true,
        'timestamp': FieldValue.serverTimestamp(),
        'message': 'Demande via lien d\'invitation',
      });

      if (mounted) {
        setState(() {
          _requestId = docRef.id;
          _requestSubmitted = true;
          _currentStep = 2;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: ${e.toString()}')),
        );
      }
    }
  }

  /// STEP 3: Complete - Request submitted, wait for approval notification
  Widget _buildStep3Complete() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Success animation/icon
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
            'Demande envoyée !',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),

          Text(
            'Votre demande pour rejoindre "${_circleData!['name']}" a été envoyée à ${_circleData!['creatorName']}.',
            style: const TextStyle(color: Colors.grey, fontSize: 15),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 32),

          // What happens next
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(Icons.notifications_active, color: Colors.blue.shade700),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Prochaine étape',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'Vous recevrez une notification dès que votre demande sera acceptée. '
                  'Vous pourrez alors configurer votre moyen de paiement.',
                  style: TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.timer_outlined, size: 18, color: Colors.grey),
                    const SizedBox(width: 8),
                    const Text(
                      'Délai moyen : ',
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                    const Text(
                      '< 24h',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // CTA - Go to home
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.gold,
                foregroundColor: AppTheme.marineBlue,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => context.go('/'),
              child: const Text(
                'RETOUR À L\'ACCUEIL',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Secondary - View my requests
          TextButton(
            onPressed: () => context.go('/my-circles'),
            child: const Text('Voir mes demandes en cours'),
          ),
        ],
      ),
    );
  }
}
