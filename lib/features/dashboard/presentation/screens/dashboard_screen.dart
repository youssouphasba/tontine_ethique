import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import 'package:tontetic/core/providers/user_provider.dart';
import 'package:tontetic/core/theme/app_theme.dart';
import 'package:tontetic/core/providers/plans_provider.dart';
import 'package:tontetic/core/business/subscription_service.dart';
import 'package:tontetic/features/social/presentation/screens/conversations_list_screen.dart';
import 'package:tontetic/features/tontine/presentation/screens/circle_chat_screen.dart';
import 'package:tontetic/features/onboarding/presentation/widgets/welcome_dialog.dart';
import 'package:tontetic/core/services/referral_service.dart';
import 'package:tontetic/features/settings/presentation/screens/settings_screen.dart';
import 'package:tontetic/features/shop/presentation/screens/boutique_screen.dart'; // Boutique TikTok-style
import 'package:tontetic/features/tontine/presentation/screens/create_tontine_screen.dart';
import 'package:tontetic/features/tontine/presentation/screens/my_circles_screen.dart';
import 'package:tontetic/features/wallet/presentation/screens/wallet_tab_screen.dart';
import 'package:share_plus/share_plus.dart'; // V10.0 Native Share
import 'package:tontetic/features/tontine/presentation/screens/qr_invitation_screen.dart'; // V18 QR Invitation
import 'package:tontetic/features/tontine/presentation/screens/explorer_screen.dart';
import 'package:tontetic/features/ai/presentation/screens/smart_coach_screen.dart'; // V5.0
import 'package:tontetic/features/tontine/presentation/screens/user_profile_screen.dart'; // V5.1 Profile
import 'package:tontetic/features/tontine/presentation/screens/tontine_simulator_screen.dart'; // V20: Restore Simulator
import 'package:tontetic/core/providers/localization_provider.dart';
import 'package:tontetic/core/presentation/widgets/tts_control_toggle.dart';
import 'package:tontetic/core/services/voice_service.dart';
import 'package:tontetic/features/ai/presentation/widgets/voice_consent_dialog.dart';
import 'package:tontetic/features/ai/presentation/widgets/audio_visualizer.dart';
import 'package:tontetic/features/ai/presentation/widgets/pulsating_mic_button.dart';
import 'package:tontetic/core/providers/tontine_provider.dart';
import 'package:tontetic/core/providers/context_provider.dart';
import 'package:tontetic/features/auth/presentation/widgets/biometric_setup_prompt.dart';
import 'package:tontetic/core/services/guest_mode_service.dart';
import 'package:tontetic/core/providers/auth_provider.dart';
import 'package:tontetic/core/providers/navigation_provider.dart';
import 'package:tontetic/core/providers/notification_provider.dart';
import 'package:tontetic/core/models/notification_model.dart';
import 'package:tontetic/features/auth/presentation/screens/auth_screen.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  final int initialIndex; // V3.5
  const DashboardScreen({super.key, this.initialIndex = 0});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> with SingleTickerProviderStateMixin {

  bool _isReferralActive = false;
  String _activeCampaignReward = '';
  bool _isRecording = false;
  bool _isProcessing = false;
  bool _hasVoiceConsent = false;
  
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;
  
  // V3.5: Local state for Tab selection ensuring stability
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.initialIndex != 0) {
        ref.read(navigationProvider.notifier).setIndex(widget.initialIndex);
      }
    });
    _checkFeatureFlag();
    
    // Animation Setup
    _animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
    
    _animController.forward();
    
    // Welcome Dialog only if Authenticated
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = ref.read(userProvider);
      if (user.status != AccountStatus.guest && !ref.read(isGuestModeProvider)) { 
         // authenticated flow
         WelcomeDialog.show(context);
         
         // Show biometric setup prompt after welcome dialog
         Future.delayed(const Duration(seconds: 2), () {
           if (mounted) {
             BiometricSetupPrompt.showIfNeeded(context, ref);
           }
         });
      }
      
      // Guest Mode Timer Start
      if (ref.read(isGuestModeProvider)) {
         ref.read(guestModeServiceProvider).startTimer(context);
      }
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }
  
  Future<void> _checkFeatureFlag() async {
    // Check for active referral campaign
    final activeCampaign = await ReferralService().getActiveCampaign();
    if (mounted) {
      setState(() {
        _isReferralActive = activeCampaign != null;
        _activeCampaignReward = activeCampaign?.rewardAmount.toString() ?? '';
      });
    }
  }

  void _onItemTapped(int index) {
      setState(() {
        _selectedIndex = index;
      });
      ref.read(navigationProvider.notifier).setIndex(index);
  }

  @override
  Widget build(BuildContext context) {
    // Sync with Provider safe way
    ref.listen(navigationProvider, (previous, next) {
      if (next != _selectedIndex) {
        setState(() {
          _selectedIndex = next;
        });
      }
    });

    final l10n = ref.watch(localizationProvider);
    List<BottomNavigationBarItem> navItems = [
      BottomNavigationBarItem(icon: const Icon(Icons.home), label: l10n.translate('tab_home')),
      const BottomNavigationBarItem(icon: Icon(Icons.search), label: 'Explorer'),
      BottomNavigationBarItem(icon: const Icon(Icons.account_balance_wallet), label: l10n.translate('tab_wallet')),
      BottomNavigationBarItem(icon: const Icon(Icons.storefront), label: 'Boutique'),
      const BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Paramètres'),
    ];

    Widget content;
    final user = ref.watch(userProvider);
    final isGuest = user.status == AccountStatus.guest;

    if (_selectedIndex == 0) {
      content = _buildHomeContent();
    } else if (_selectedIndex == 1) {
      content = const ExplorerScreen();
    } else if (_selectedIndex == 2) {
      content = isGuest ? _buildGuestBlocker('Portefeuille') : const WalletTabScreen();
    } else if (_selectedIndex == 3) {
      content = const BoutiqueScreen();
    } else {
      content = const SettingsScreen();
    }

    return Scaffold(
      appBar: AppBar(
        title: _buildGreeting(user.displayName),
        elevation: 0,
        backgroundColor: AppTheme.marineBlue,
        foregroundColor: Colors.white,
        actions: [
          const TTSControlToggle(),
          IconButton(
            icon: const Icon(Icons.chat_bubble_outline, color: Colors.white),
            onPressed: () => context.push('/conversations'),
          ),
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_none, color: Colors.white),
                onPressed: () => _showNotifications(context, ref),
              ),
              if (ref.watch(notificationProvider).unreadCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      '${ref.watch(notificationProvider).unreadCount}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          CircleAvatar(
            radius: 16,
            backgroundColor: AppTheme.gold,
            child: IconButton(
              icon: const Icon(Icons.person, size: 18, color: AppTheme.marineBlue),
              onPressed: () => context.push('/profile?isMe=true'),
            ),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: SafeArea(
        child: Stack(
          children: [
            content,
            if (_isRecording)
              Positioned(
                bottom: 100,
                left: 24,
                right: 24,
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10)],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(l10n.translate('voice_listening'), style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.emeraldGreen)),
                      const SizedBox(height: 16),
                      AudioVisualizer(isRecording: _isRecording),
                      const SizedBox(height: 8),
                      Text(
                        l10n.translate('voice_privacy_note'),
                        style: const TextStyle(fontSize: 10, color: Colors.grey),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      const Text("Appuyez sur le micro pour arrêter", style: TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
      floatingActionButton: _selectedIndex == 0 // Only on Home
          ? PulsatingMicButton(
              isRecording: _isRecording,
              isProcessing: _isProcessing,
              onTap: _handleCoachAction,
              onLongPress: _handleVoiceRecording,
            )
          : null,
      // Bottom navigation is now provided by MainShell
    );
  }

  void _handleCoachAction() {
    if (_isRecording) {
      _handleVoiceRecording();
    } else {
      context.push('/coach');
    }
  }

  Future<void> _handleVoiceRecording() async {
    final voiceService = ref.read(voiceServiceProvider);

    if (!_hasVoiceConsent) {
      final consented = await showDialog<bool>(
        context: context,
        builder: (context) => const VoiceConsentDialog(),
      );
      if (consented == true) {
        _hasVoiceConsent = true;
      } else {
        return;
      }
    }

    if (!_isRecording) {
      setState(() => _isRecording = true);
      await voiceService.startRecording();
    } else {
      setState(() {
        _isRecording = false;
        _isProcessing = true;
      });
      final audioFile = await voiceService.stopRecording();
      if (audioFile != null) {
        final transcription = await voiceService.transcribeAudio(audioFile);
        if (mounted) {
          setState(() => _isProcessing = false);
          context.push('/coach?text=${Uri.encodeComponent(transcription.text)}');
        }
      } else {
        setState(() => _isProcessing = false);
      }
    }
  }

  void _showJoinByCodeDialog() {
    final codeController = TextEditingController();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        bool isChecking = false;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('🔐 Rejoindre un cercle'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Saisissez le code d\'invitation partagé par l\'organisateur.'),
                  const SizedBox(height: 16),
                  TextField(
                    controller: codeController,
                    enabled: !isChecking,
                    decoration: const InputDecoration(
                      labelText: 'Code d\'invitation',
                      hintText: 'Ex: TONT-2026-XYZ',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.vpn_key),
                    ),
                    textCapitalization: TextCapitalization.characters,
                  ),
                  if (isChecking) ...[
                    const SizedBox(height: 16),
                    const CircularProgressIndicator(),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isChecking ? null : () => Navigator.pop(ctx), 
                  child: const Text('ANNULER')
                ),
                ElevatedButton(
                  onPressed: isChecking ? null : () async {
                    if (codeController.text.isEmpty) return;
                    
                    setDialogState(() => isChecking = true);
                    
                    try {
                      final query = await FirebaseFirestore.instance
                          .collection('tontines')
                          .where('inviteCode', isEqualTo: codeController.text.trim().toUpperCase())
                          .limit(1)
                          .get();
                      
                      if (query.docs.isNotEmpty) {
                        final doc = query.docs.first;
                        final data = doc.data();
                        if (mounted) {
                          Navigator.pop(ctx);
                          this.context.push('/tontine/${doc.id}?name=${Uri.encodeComponent(data['name'] ?? 'Cercle')}&isJoined=false');
                        }
                      } else {
                        setDialogState(() => isChecking = false);
                        if (mounted) {
                          ScaffoldMessenger.of(this.context).showSnackBar(
                            const SnackBar(
                              content: Text('Code invalide ou cercle inexistant.'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    } catch (e) {
                      setDialogState(() => isChecking = false);
                      if (mounted) {
                        ScaffoldMessenger.of(this.context).showSnackBar(
                          SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
                        );
                      }
                    }
                  }, 
                  child: const Text('VÉRIFIER LE CODE')
                ),
              ],
            );
          }
        );
      },
    );
  }

  Widget _buildHomeContent() {

    return FadeTransition(
      opacity: _fadeAnim,
      child: SlideTransition(
        position: _slideAnim,
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 80),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // V14: Pending Invitations Banner
              _buildPendingInvitationsBanner(),
              
              // _buildHeader(), // Removed as AppBar now handles it
              
                // --- ACQUISITION POWER PACK START ---
                // 1. Welcome Bonus Banner (Updated: Launch Offer 3 Months)

              // --- ACQUISITION POWER PACK REMOVED (Mock/Marketing) ---


              const SizedBox(height: 16),
              _buildKPISummaryRow(),
              const SizedBox(height: 24),
              const SizedBox(height: 24),
              // Coach advice removed

              const SizedBox(height: 16),
              
              // V9.0: Referral Banner (Moved from Tab)
              if (_isReferralActive) _buildReferralBanner(),
              
              const SizedBox(height: 16),
              _buildQuickActions(),
              const SizedBox(height: 24),
              _buildMyTontinesSection(),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildKPISummaryRow() {
    final circles = ref.watch(circleProvider).myCircles;
    final user = ref.watch(userProvider);
    
    // Calculate Total Saved (Approximate: sum of circle value * cycles passed, assuming participation)
    // In production, this should come from a dedicated Transaction/Savings Service.
    double totalSaved = 0;
    for (var circle in circles) {
      totalSaved += circle.amount * circle.currentCycle;
    }
    
    // Calculate Next Payout Date
    DateTime? nextPayout;
    if (circles.isNotEmpty) {
      final now = DateTime.now();
      // Simple logic: Find next occurrence of payoutDay
      final dates = circles.map((c) {
        final day = c.payoutDay;
        var date = DateTime(now.year, now.month, day);
        if (date.isBefore(now)) {
          date = DateTime(now.year, now.month + 1, day);
        }
        return date;
      }).toList();
      dates.sort();
      if (dates.isNotEmpty) nextPayout = dates.first;
    }

    final formattedDate = nextPayout != null ? DateFormat('d MMM', 'fr_FR').format(nextPayout) : '-';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Row(
        children: [
          Expanded(child: _buildKPIItem('Cotisations Totales', ref.read(userProvider.notifier).formatContent(totalSaved), Icons.savings, Colors.green)),
          const SizedBox(width: 12),
          Expanded(child: _buildKPIItem('Prochain Pot', formattedDate, Icons.event, AppTheme.marineBlue)),
          const SizedBox(width: 12),
          Expanded(child: _buildKPIItem('Honneur', '${user.honorScore} pts 📈', Icons.trending_up, AppTheme.gold)),
        ],
      ),
    );
  }

  Widget _buildKPIItem(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Theme.of(context).brightness == Brightness.dark && color == AppTheme.marineBlue ? AppTheme.gold : color),
          const SizedBox(height: 8),
          Text(
            value, 
            style: TextStyle(
              fontWeight: FontWeight.bold, 
              fontSize: 14,
              color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            label, 
            style: TextStyle(
              fontSize: 10, 
              color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.grey[700], 
              height: 1.2,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          _buildQuickActionItem(Icons.add_circle, 'Créer Tontine', () {
            final plan = ref.read(currentUserPlanProvider).value;
            final user = ref.read(userProvider);
            final error = SubscriptionService.getCreationErrorMessage(
              plan: plan, 
              activeCirclesCount: user.activeCirclesCount,
            );
            
            if (error != null) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(error), backgroundColor: Colors.red),
              );
              return;
            }
            context.push('/create-tontine');
          }),
          const SizedBox(width: 16),
          _buildQuickActionItem(Icons.qr_code, 'Inviter', () => context.push('/qr-invitation')),
          const SizedBox(width: 16),
          _buildQuickActionItem(Icons.calculate_outlined, 'Simulation', () => context.push('/simulator')),
        ],
      ),
    );
  }

  Widget _buildQuickActionItem(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.marineBlue.withValues(alpha: Theme.of(context).brightness == Brightness.dark ? 0.3 : 0.1), 
              borderRadius: BorderRadius.circular(16)
            ),
            child: Icon(
              icon, 
              color: Theme.of(context).brightness == Brightness.dark ? AppTheme.gold : AppTheme.marineBlue, 
              size: 28
            ),
          ),
          const SizedBox(height: 8),
          Text(label, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87)),
        ],
      ),
    );
  }





  Widget _buildMyTontinesSection() {
    final myCircles = ref.watch(circleProvider).myCircles;

    if (myCircles.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
             Text(
              'Mes Tontines',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            _buildAddTontineCard(),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Mes Tontines',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                TextButton(
                  onPressed: () {
                     context.push('/tontines');
                  },
                  child: const Text('Voir tout'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 160,
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemCount: myCircles.length + 1, // +1 for Add Card
              itemBuilder: (context, index) {
                if (index == myCircles.length) {
                  return _buildAddTontineCard();
                }
                final circle = myCircles[index];
                return _buildTontineCard(
                  circleId: circle.id,
                  title: circle.name,
                  role: 'Tour ${circle.currentCycle}/${circle.maxParticipants}',
                  amount: '${ref.read(userProvider.notifier).formatContent(circle.amount)} / ${circle.frequency}',
                  progress: circle.progress,
                  color: AppTheme.marineBlue,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTontineCard({
    required String circleId,
    required String title,
    required String role,
    required String amount,
    required double progress,
    required Color color,
  }) {
    return Hero(
      tag: 'tontine_$title',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            context.push('/chat/$circleId?name=${Uri.encodeComponent(title)}');
          },
          child: Container(
            width: 160,
            margin: const EdgeInsets.symmetric(horizontal: 8),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.groups, color: Colors.white, size: 28),
                    const SizedBox(height: 12),
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      amount,
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LinearProgressIndicator(
                      value: progress,
                      backgroundColor: Colors.white24,
                      valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.gold),
                      minHeight: 4,
                      borderRadius: BorderRadius.circular(2),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      role,
                      style: const TextStyle(
                        color: AppTheme.gold,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAddTontineCard() {
    return InkWell(
      onTap: () {
        showModalBottomSheet(
          context: context,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
          builder: (ctx) => Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.vpn_key, color: AppTheme.marineBlue),
                  title: const Text('Rejoindre une tontine existante'),
                  subtitle: const Text('Entrez le code d\'invitation'),
                  onTap: () {
                    Navigator.pop(ctx); // Close bottom sheet first
                    _showJoinByCodeDialog();
                  },
                ),

                const Divider(),
                ListTile(
                  leading: const Icon(Icons.add_circle_outline, color: AppTheme.gold),
                  title: const Text('Créer ma propre tontine'),
                  subtitle: const Text('Invitez vos proches (Famille, Amis)'),
                  onTap: () {
                    context.push('/create-tontine');
                  },
                ),
              ],
            ),
          ),
        );
      },
      child: Container(
        width: 100,
        margin: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.shade300, style: BorderStyle.solid),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_circle, color: AppTheme.marineBlue.withValues(alpha: 0.5), size: 32),
              const SizedBox(height: 8),
              Text(
                "Nouveau",
                style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.bold),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGreeting(String displayName) {
    final l10n = ref.watch(localizationProvider);
    // Fallback to Auth displayName if Firestore name is not yet loaded
    final effectiveName = displayName.isNotEmpty && displayName != 'Membre' 
        ? displayName 
        : (FirebaseAuth.instance.currentUser?.displayName ?? 'Membre');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${l10n.translate('hello')}, $effectiveName 👋',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        Row(
          children: [
            Text(
              l10n.translate('welcome_back'),
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 12,
              ),
            ),
            if (ref.watch(contextProvider).isEmployee) ...[
              const SizedBox(width: 8),
              _buildContextSwitcher(),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildReferralBanner() {

    // Generate referral code based on user name
    final userState = ref.watch(userProvider);
    final userName = userState.displayName;
    final userId = userState.phoneNumber;
    
    // Generate code from user name
    final namePart = userName.toUpperCase().split(' ').first.substring(0, 
      userName.split(' ').first.length > 6 ? 6 : userName.split(' ').first.length);
    final referralCode = ReferralService().getReferralCode(userId, namePart);
    final referralLink = ReferralService().getReferralLink(referralCode);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [AppTheme.marineBlue, Colors.indigo.shade800]),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: AppTheme.marineBlue.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.card_giftcard, color: AppTheme.gold, size: 24),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Parrainez vos proches ! 🎁', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                    SizedBox(height: 2),
                    Text('1 mois sans frais pour chaque ami', style: TextStyle(color: Colors.white70, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Referral Code
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Text('Votre code: ', style: TextStyle(color: Colors.white70, fontSize: 12)),
                Text(referralCode, style: const TextStyle(color: AppTheme.gold, fontWeight: FontWeight.bold, fontSize: 18, letterSpacing: 1)),
                const Spacer(),
                InkWell(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: referralCode));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('✓ Code copié !'), duration: Duration(seconds: 2)),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.copy, color: Colors.white, size: 14),
                        SizedBox(width: 4),
                        Text('Copier', style: TextStyle(color: Colors.white, fontSize: 12)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          
          // Share buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    Share.share(
                      '🌟 Rejoins Tontetic, l\'app de tontine solidaire !\n\n'
                      '💰 Ensemble, on atteint nos objectifs.\n'
                      '🎁 Utilise mon code $referralCode pour gagner ${_activeCampaignReward.isNotEmpty ? "$_activeCampaignReward FCFA" : "une récompense"} !\n\n'
                      '📲 $referralLink',
                      subject: 'Invitation Tontetic - Code $referralCode',
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.gold,
                    foregroundColor: AppTheme.marineBlue,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.share, size: 18),
                  label: const Text('Partager mon lien', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 12),
              InkWell(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: referralLink));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('✓ Lien copié !'), duration: Duration(seconds: 2)),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.link, color: Colors.white, size: 20),
                ),
              ),
            ],
          ),
          
          // Reward details
          const SizedBox(height: 12),
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.info_outline, color: Colors.white54, size: 14),
              SizedBox(width: 4),
              Text(
                'Bonus crédité quand votre filleul rejoint un cercle',
                style: TextStyle(color: Colors.white54, fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // V14: Pending Invitations Banner
  Widget _buildPendingInvitationsBanner() {
    final circleState = ref.watch(circleProvider);
    final invitations = circleState.pendingInvitations;
    
    if (invitations.isEmpty) return const SizedBox.shrink();
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [Colors.orange.shade600, Colors.deepOrange]),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.orange.withValues(alpha: 0.3), blurRadius: 10)],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Text('${invitations.length}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('🔔 Invitations en attente', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 4),
                Text(
                  invitations.length == 1 
                    ? '${invitations.first.requesterName} vous invite à rejoindre "${invitations.first.circleName}"'
                    : '${invitations.length} cercles vous attendent !',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 16),
            onPressed: () {
              ref.read(navigationProvider.notifier).setIndex(1);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildContextSwitcher() {
    final contextState = ref.watch(contextProvider);
    final isPersonal = contextState.currentContext == UserContext.personal;

    return GestureDetector(
      onTap: () => _showContextMenu(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isPersonal ? Colors.blue.withValues(alpha: 0.1) : Colors.indigo.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isPersonal ? Colors.blue : Colors.indigo),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isPersonal ? Icons.person : Icons.business,
              size: 14,
              color: isPersonal ? Colors.blue : Colors.indigo,
            ),
            const SizedBox(width: 6),
            Text(
              isPersonal 
                ? 'Personnel'
                : contextState.currentCompany?.companyName ?? 'Entreprise',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: isPersonal ? Colors.blue : Colors.indigo,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.keyboard_arrow_down, size: 16, color: isPersonal ? Colors.blue : Colors.indigo),
          ],
        ),
      ),
    );
  }

  void _showContextMenu() {
    final contextState = ref.read(contextProvider);
    
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Changer de contexte', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('Choisissez le contexte pour naviguer.', style: TextStyle(color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 20),
            
            // Personal context
            _buildContextOption(
              icon: Icons.person,
              title: 'Compte Personnel',
              subtitle: 'Tontines privées et familiales',
              color: Colors.blue,
              isSelected: contextState.currentContext == UserContext.personal,
              onTap: () {
                ref.read(contextProvider.notifier).switchToPersonal();
                Navigator.pop(ctx);
              },
            ),
            const SizedBox(height: 12),
            
            // Enterprise contexts
            ...contextState.employeeLinks.map((link) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildContextOption(
                icon: Icons.business,
                title: link.companyName,
                subtitle: 'Tontines entreprise',
                color: Colors.indigo,
                isSelected: contextState.activeCompanyId == link.companyId,
                onTap: () {
                  ref.read(contextProvider.notifier).switchToEnterprise(link.companyId);
                  Navigator.pop(ctx);
                },
              ),
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildContextOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: isSelected ? color : Colors.grey[300]!),
          borderRadius: BorderRadius.circular(12),
          color: isSelected ? color.withValues(alpha: 0.05) : null,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle, color: color)
            else
              Icon(Icons.radio_button_unchecked, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }

  Widget _buildGuestBlocker(String title) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock_outline, size: 64, color: Colors.grey),
            const SizedBox(height: 24),
            Text(
              'Accès Réservé ($title)',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Pour accéder à la section $title, créer des tontines et sécuriser votre argent, vous devez avoir un compte.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () {
                // Stop timer if navigating away (although AuthService likely handles state reset)
                ref.read(guestModeServiceProvider).stopTimer();
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const AuthScreen()),
                  (route) => false,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.gold,
                foregroundColor: AppTheme.marineBlue,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              ),
              child: const Text('Créer un compte maintenant'),
            ),
          ],
        ),
      ),
    );
  }

  void _showNotifications(BuildContext context, WidgetRef ref) {
    final notifState = ref.watch(notificationProvider);
    final notes = notifState.notifications;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        builder: (_, scrollController) => Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Centre de Notifications', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  if (notifState.unreadCount > 0)
                    TextButton(
                      onPressed: () => ref.read(notificationProvider.notifier).markAllAsRead(),
                      child: const Text('Tout marquer comme lu'),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: notifState.isLoading 
                  ? const Center(child: CircularProgressIndicator())
                  : notes.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.notifications_off_outlined, size: 64, color: Colors.grey),
                            SizedBox(height: 16),
                            Text('Aucune notification pour le moment.', style: TextStyle(color: Colors.grey)),
                          ],
                        ),
                      )
                    : ListView.builder(
                      controller: scrollController,
                      itemCount: notes.length,
                      itemBuilder: (ctx, i) {
                        final n = notes[i];
                        
                        IconData iconData = Icons.info_outline;
                        Color iconColor = Colors.blue;
                        
                        switch (n.type) {
                          case NotificationType.success:
                          case NotificationType.payment:
                            iconData = Icons.check_circle_outline;
                            iconColor = Colors.green;
                            break;
                          case NotificationType.warning:
                            iconData = Icons.warning_amber_rounded;
                            iconColor = Colors.orange;
                            break;
                          case NotificationType.tontine_invite:
                            iconData = Icons.mail_outline;
                            iconColor = Colors.purple;
                            break;
                          case NotificationType.chat_message:
                            iconData = Icons.chat_bubble_outline;
                            iconColor = AppTheme.marineBlue;
                            break;
                          default:
                            iconData = Icons.notifications_none;
                        }

                        return Dismissible(
                          key: Key(n.id),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 20.0),
                            color: Colors.red,
                            child: const Icon(Icons.delete, color: Colors.white),
                          ),
                          onDismissed: (direction) {
                             ref.read(notificationProvider.notifier).deleteNotification(n.id);
                          },
                          child: Card(
                            elevation: n.isRead ? 0 : 2,
                            color: n.isRead ? Colors.transparent : (Theme.of(context).brightness == Brightness.dark ? Colors.grey[900] : Colors.white),
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: iconColor.withValues(alpha: 0.1),
                                child: Icon(iconData, color: iconColor),
                              ),
                              title: Text(n.title, style: TextStyle(fontWeight: n.isRead ? FontWeight.normal : FontWeight.bold)),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(n.body),
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      DateFormat('dd/MM HH:mm').format(n.createdAt),
                                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                                    ),
                                  ),
                                ],
                              ),
                              onTap: () {
                                // Mark as read
                                ref.read(notificationProvider.notifier).markAsRead(n.id);
                                
                                // Logic based on type (example)
                                if (n.type == NotificationType.tontine_invite && n.data != null) {
                                  // Example navigation
                                  // context.push('/circle-details/${n.data!['circleId']}');
                                }
                              },
                            ),
                          ),
                        );
                      },
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
