import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tontetic/core/theme/app_theme.dart';
import 'package:tontetic/core/providers/user_provider.dart';
import 'package:tontetic/core/models/user_model.dart';
import 'package:tontetic/core/models/tontine_model.dart';

import 'package:tontetic/features/social/data/social_provider.dart';
import 'package:tontetic/features/social/data/contact_service.dart';
import 'package:tontetic/features/social/data/suggestion_service.dart';
import 'package:tontetic/features/social/presentation/screens/conversations_list_screen.dart';
import 'package:tontetic/core/business/subscription_service.dart';
import 'package:tontetic/features/tontine/presentation/screens/qr_scanner_screen.dart';
import 'package:tontetic/core/providers/localization_provider.dart';
import 'package:tontetic/core/providers/tontine_provider.dart';
import 'package:tontetic/core/providers/auth_provider.dart';
import 'package:tontetic/features/tontine/presentation/screens/circle_details_screen.dart';
import 'package:go_router/go_router.dart';
import 'package:tontetic/core/models/plan_model.dart';
import 'package:tontetic/core/providers/plans_provider.dart';

class MyCirclesScreen extends ConsumerWidget {
  const MyCirclesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(localizationProvider);

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Tontetic Dashboard'),
          centerTitle: false,
          backgroundColor: AppTheme.marineBlue,
          actions: [
            // Language Toggle
            TextButton(
              onPressed: () => ref.read(localizationProvider.notifier).toggleLanguage(),
              child: Text(
                l10n.language == AppLanguage.fr ? 'WOLOF' : 'FRANÇAIS',
                style: const TextStyle(color: AppTheme.gold, fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.chat_bubble_outline),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (ctx) => const ConversationsListScreen())),
            ),
            IconButton(icon: const Icon(Icons.qr_code_scanner), onPressed: () => _openScanner(context)),
          ],
          bottom: TabBar(
            indicatorColor: AppTheme.gold,
            labelColor: AppTheme.gold,
            unselectedLabelColor: Colors.white70,
            indicatorWeight: 3,
            tabs: [
              Tab(text: l10n.translate('my_tontines')),
              Tab(text: l10n.translate('explore')),
              Tab(text: l10n.translate('community')),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _MyTontinesTab(),
            _ExploreTab(),
            _CommunityTab(),
          ],
        ),
      ),
    );
  }

  static void _openScanner(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (ctx) => const QRScannerScreen()));
  }
}

// --- SHARED UI COMPONENTS (Point 6: Dashboard) ---

Widget _buildUserDashboardCard(BuildContext context, WidgetRef ref) {
  final user = ref.watch(userProvider);
  final planAsync = ref.watch(currentUserPlanProvider);
  final plan = planAsync.value;
  
  // Default values if plan not found yet
  final maxCircles = plan?.getLimit<int>('maxCircles', 1) ?? 1;
  final maxMembers = plan?.getLimit<int>('maxMembers', 5) ?? 5;
  final remaining = plan != null ? SubscriptionService.getRemainingCircles(plan, user.activeCirclesCount) : 0;

  return Container(
    width: double.infinity,
    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [AppTheme.marineBlue, AppTheme.marineBlue.withValues(alpha: 0.8)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          color: AppTheme.marineBlue.withValues(alpha: 0.3),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Text(user.subscriptionTier.emoji, style: const TextStyle(fontSize: 20)),
                    const SizedBox(width: 8),
                    Text(
                      'Plan ${user.subscriptionTier.toUpperCase()}',
                      style: const TextStyle(
                        color: AppTheme.gold,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${user.activeCirclesCount} / $maxCircles tontines actives',
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
            ElevatedButton(
              onPressed: () {
                final isGuest = ref.read(isGuestModeProvider);
                if (isGuest) {
                  _showAuthRequiredDialog(context);
                  return;
                }
                context.push('/subscription');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.gold,
                foregroundColor: AppTheme.marineBlue,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                minimumSize: const Size(80, 32),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
              child: const Text('Changer', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Progress bar
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: user.activeCirclesCount / maxCircles,
            backgroundColor: Colors.white24,
            valueColor: AlwaysStoppedAnimation<Color>(remaining <= 0 ? Colors.red : AppTheme.gold),
            minHeight: 6,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Membres max : $maxMembers',
              style: const TextStyle(color: Colors.white60, fontSize: 11),
            ),
            if (remaining <= 0)
              const Text(
                'Quota tontines atteint ⚠️',
                style: TextStyle(color: Colors.amber, fontSize: 11, fontWeight: FontWeight.bold),
              )
            else
              Text(
                'Disponible : $remaining',
                style: const TextStyle(color: Colors.white60, fontSize: 11),
              ),
          ],
        ),
      ],
    ),
  );
}


class _MyTontinesTab extends ConsumerWidget {
  const _MyTontinesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // V14: Get real circles from provider
    final circleState = ref.watch(circleProvider);
    final activeCircles = circleState.myCircles.where((c) => !c.isFinished).toList();
    final finishedCircles = circleState.myCircles.where((c) => c.isFinished).toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        // Responsive height based on orientation
        final isLandscape = constraints.maxWidth > constraints.maxHeight;
        final _ = isLandscape ? 100.0 : 145.0; // Reserved for activity feed height

        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Règle 6: Dashboard utilisateur
                _buildUserDashboardCard(context, ref),
                
                
                // Circles list
                if (circleState.myCircles.isEmpty)
                  SizedBox(
                    height: constraints.maxHeight - 300,
                    child: _buildEmptyState(context, ref),
                  )
                else
                  Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: _buildHonorScoreHeader(context, ref),
                      ),
                      if (activeCircles.isNotEmpty) ...[
                        const Padding(
                          padding: EdgeInsets.only(top: 16, bottom: 8, left: 16),
                          child: Text('TONTINES EN COURS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey)),
                        ),
                        ...activeCircles.map((circle) => Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: _buildCircleCard(context, ref, circle),
                        )),
                      ],
                      if (finishedCircles.isNotEmpty) ...[
                        const Divider(height: 32, indent: 16, endIndent: 16),
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8.0, horizontal: 16),
                          child: Text('HISTORIQUE (TERMINÉES)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey)),
                        ),
                        ...finishedCircles.map((circle) => Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: _buildCircleCard(context, ref, circle, isFinished: true),
                        )),
                      ],
                      const SizedBox(height: 24),
                    ],
                  ),
              ],
            ),
          ),
        );
      },
    );
  }


  Widget _buildEmptyState(BuildContext context, WidgetRef ref) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.account_balance_wallet_outlined, 
              size: 80, 
              color: Theme.of(context).brightness == Brightness.dark ? Colors.grey[600] : Colors.grey,
            ),
            const SizedBox(height: 16),
            Text(
              'Aucune tontine', 
              style: TextStyle(
                fontSize: 20, 
                fontWeight: FontWeight.bold, 
                color: Theme.of(context).brightness == Brightness.dark ? Colors.grey[400] : Colors.grey,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Créez votre première tontine pour commencer !', 
              style: TextStyle(
                color: Theme.of(context).brightness == Brightness.dark ? Colors.grey[500] : Colors.grey,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                final isGuest = ref.read(isGuestModeProvider);
                if (isGuest) {
                  _showAuthRequiredDialog(context);
                  return;
                }
                context.push('/create-tontine');
              },
              icon: const Icon(Icons.add),
              label: const Text('Créer une Tontine'),
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.marineBlue),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCircleCard(BuildContext context, WidgetRef ref, TontineCircle circle, {bool isFinished = false}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: isFinished ? Border.all(color: Colors.grey.shade200) : null,
        boxShadow: isFinished ? null : [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1), 
            blurRadius: 8, 
            offset: const Offset(0, 4)
          ),
        ],
      ),

      child: InkWell(
        onTap: () {
          Navigator.push(context, MaterialPageRoute(
            builder: (_) => CircleDetailsScreen(
              circleName: circle.name,
              circleId: circle.id, // Pass the real circle ID
              isJoined: true,
              isAdmin: circle.creatorId == ref.read(authStateProvider).value?.uid,
            ),
          ));
        },
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.marineBlue,
                borderRadius: BorderRadius.circular(50),
              ),
              child: const Icon(
                Icons.account_balance, 
                color: AppTheme.gold, 
                size: 24
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          circle.name,
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Theme.of(context).brightness == Brightness.dark ? AppTheme.gold : AppTheme.marineBlue),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${circle.amount.toInt()} ${circle.currency} • ${circle.frequency}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: circle.progress,
                      color: AppTheme.gold,
                      backgroundColor: Colors.grey[200],
                      minHeight: 6,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Cycle ${circle.currentCycle}/${circle.maxParticipants} • ${circle.memberIds.length} membres',
                    style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
      ),
    );
  }



  Widget _buildHonorScoreHeader(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(localizationProvider);
    final user = ref.watch(userProvider);

    // Get honor score from user (0-100 scale)
    final honorScore = user.honorScore.clamp(0, 100);
    final scoreProgress = honorScore / 100.0;

    // Determine status based on score
    String statusKey;
    Color statusColor;
    if (honorScore >= 80) {
      statusKey = 'honor_score_excellent';
      statusColor = Colors.green;
    } else if (honorScore >= 60) {
      statusKey = 'honor_score_good';
      statusColor = AppTheme.gold;
    } else if (honorScore >= 40) {
      statusKey = 'honor_score_status';
      statusColor = Colors.orange;
    } else {
      statusKey = 'honor_score_low';
      statusColor = Colors.red;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 24, top: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: Theme.of(context).brightness == Brightness.dark
              ? [AppTheme.marineBlue.withValues(alpha: 0.3), const Color(0xFF1E1E1E)]
              : [AppTheme.marineBlue.withValues(alpha: 0.05), Colors.white],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.marineBlue.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 60,
                    height: 60,
                    child: CircularProgressIndicator(
                      value: scoreProgress,
                      backgroundColor: Colors.grey[200],
                      color: statusColor,
                      strokeWidth: 6,
                    ),
                  ),
                  Text(
                    '$honorScore',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Theme.of(context).brightness == Brightness.dark ? AppTheme.gold : AppTheme.marineBlue),
                  ),
                ],
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          l10n.translate('honor_score_title'),
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Theme.of(context).brightness == Brightness.dark ? AppTheme.gold : AppTheme.marineBlue),
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          icon: const Icon(Icons.help_outline, size: 18, color: Colors.grey),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () => _showHonorRules(context, ref),
                        ),
                      ],
                    ),
                    Text(
                      l10n.translate(statusKey),
                      style: TextStyle(fontSize: 12, color: statusColor, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            l10n.translate('honor_score_welcome'),
            style: TextStyle(fontSize: 13, color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.black54, height: 1.4),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Icon(Icons.psychology, size: 20, color: AppTheme.gold),
              const SizedBox(width: 8),
              Text(
                l10n.translate('coach_signature'),
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Theme.of(context).brightness == Brightness.dark ? AppTheme.gold.withValues(alpha: 0.8) : AppTheme.marineBlue.withValues(alpha: 0.8)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            l10n.translate('coach_bravo_msg'),
            style: TextStyle(fontSize: 13, color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.black54, height: 1.4, fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }

  void _showHonorRules(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(localizationProvider);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.translate('rules_title')),
        content: Text(l10n.translate('rules_content')),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
      ),
    );
  }


  }

class _ExploreTab extends ConsumerStatefulWidget {
  const _ExploreTab();

  @override
  ConsumerState<_ExploreTab> createState() => _ExploreTabState();
}

class _ExploreTabState extends ConsumerState<_ExploreTab> {
  String _selectedObjective = 'Pour vous';
  final List<String> _filters = ['Pour vous', 'Proximité', '🏠 Maison', '🚗 Transport', '📦 Business', '📚 Éducation', '💰 Épargne'];
  bool _showListView = false; // Toggle between TikTok feed and list view
  // ignore: unused_field
  bool _legalWarningShown = false;

  // Localization getter
  LocalizationState get l10n => ref.read(localizationProvider);


  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndShowLegalWarning();
    });
  }

  Future<void> _checkAndShowLegalWarning() async {
    final prefs = await SharedPreferences.getInstance();
    final hasShown = prefs.getBool('explorer_legal_warning_shown') ?? false;
    if (!hasShown && mounted) {
      _showLegalWarning();
      await prefs.setBool('explorer_legal_warning_shown', true);
    }
    setState(() => _legalWarningShown = true);
  }

  void _showLegalWarning() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(l10n.translate('tech_warning_title')),
        content: Text(l10n.translate('tech_warning_content')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.translate('ok')),
          ),
        ],
      ),
    );
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
              title: const Text('Rejoindre un cercle privé'),
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
                          Navigator.push(context, MaterialPageRoute(builder: (ctx) => CircleDetailsScreen(
                            circleId: doc.id,
                            circleName: data['name'] ?? 'Cercle Privé',
                            isJoined: false,
                          )));
                        }
                      } else {
                        setDialogState(() => isChecking = false);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
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
                        ScaffoldMessenger.of(context).showSnackBar(
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        // Technical Platform Banner
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          color: Colors.amber.withValues(alpha: 0.8),
          child: Text(
            l10n.translate('tech_banner_text'),
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.bold),
          ),
        ),

        // Action Bar (Join by Code + View Toggle)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _showJoinByCodeDialog,
                  icon: const Icon(Icons.vpn_key, size: 18, color: AppTheme.gold),
                  label: const Text('Rejoindre par code', style: TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.marineBlue,
                    side: const BorderSide(color: AppTheme.gold),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              IconButton(
                icon: Icon(_showListView ? Icons.view_carousel : Icons.list, color: AppTheme.marineBlue),
                tooltip: _showListView ? 'Vue immersive' : 'Vue liste',
                onPressed: () => setState(() => _showListView = !_showListView),
              ),
            ],
          ),
        ),

        // TikTok Feed or List View
        Expanded(
          child: _showListView ? _buildListView() : _buildTikTokFeed(),
        ),
      ],
    );
  }

  Widget _buildTikTokFeed() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('tontines').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Erreur: ${snapshot.error}'));
        }

        final docs = snapshot.data?.docs ?? [];

        var feedItems = docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          data['id'] = doc.id;
          data['members'] = (data['memberIds'] as List?)?.length ?? 0;
          data['maxMembers'] = data['maxParticipants'] ?? 12;
          data['location'] = data['location'] ?? 'Universel';
          data['currency'] = data['currency'] ?? 'FCFA';

          // Default image if missing
          if (data['imageUrl'] == null || (data['imageUrl'] as String).isEmpty) {
            data['imageUrl'] = 'https://images.unsplash.com/photo-1573164713714-d95e436ab8d6?q=80&w=1000';
          }
          if (data['tags'] == null) {
            data['tags'] = ['Divers'];
          }
          return data;
        }).where((data) {
          final user = ref.read(userProvider);
          // Exclude my own circles and circles I already joined
          if (data['creatorId'] == user.uid) return false;
          if ((data['memberIds'] as List).contains(user.uid)) return false;

          // Objective Filter
          if (_selectedObjective != 'Pour vous') {
            final filterTag = _selectedObjective.split(' ').last.toLowerCase();
            final tags = (data['tags'] as List).map((t) => t.toString().toLowerCase()).toList();
            final name = (data['name'] as String?)?.toLowerCase() ?? '';
            bool matches = tags.any((t) => t.contains(filterTag)) || name.contains(filterTag);
            if (!matches) return false;
          }

          return true;
        }).toList();

        if (feedItems.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.search_off, size: 48, color: Colors.grey[400]),
                const SizedBox(height: 16),
                const Text("Aucun cercle trouvé"),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => setState(() => _selectedObjective = 'Pour vous'),
                  child: const Text('Réinitialiser les filtres'),
                ),
              ],
            ),
          );
        }

        return Stack(
          children: [
            // TikTok-style Vertical PageView
            PageView.builder(
              scrollDirection: Axis.vertical,
              itemCount: feedItems.length,
              itemBuilder: (context, index) {
                return _buildFullCircleCard(feedItems[index]);
              },
            ),

            // Floating Glass Filters
            Positioned(
              top: 8,
              left: 0,
              right: 0,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: _filters.map((f) => _buildGlassChip(f, isDark)).toList(),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildListView() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('tontines')
          .where('isPublic', isEqualTo: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Erreur: ${snapshot.error}'));
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
          return const Center(child: Text("Aucune tontine publique disponible."));
        }

        final circles = docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          data['id'] = doc.id;
          data['members'] = (data['memberIds'] as List?)?.length ?? 0;
          data['maxMembers'] = data['maxParticipants'] ?? 12;
          data['tags'] = data['tags'] ?? ['Tontine'];
          data['location'] = data['location'] ?? 'Universel';
          return data;
        }).where((circle) {
          final user = ref.read(userProvider);
          if (circle['creatorId'] == user.uid) return false;
          if ((circle['memberIds'] as List).contains(user.uid)) return false;

          // Objective Filter
          if (_selectedObjective != 'Pour vous') {
            final filterTag = _selectedObjective.split(' ').last.toLowerCase();
            final tags = (circle['tags'] as List?)?.map((t) => t.toString().toLowerCase()).toList() ?? [];
            final name = (circle['name'] as String?)?.toLowerCase() ?? '';
            final matches = tags.any((t) => t.contains(filterTag)) || name.contains(filterTag);
            if (!matches) return false;
          }
          return true;
        }).toList();

        if (circles.isEmpty) {
          return const Center(child: Text("Aucun résultat pour ces filtres."));
        }

        return Column(
          children: [
            // Filters
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.all(8),
              child: Row(
                children: _filters.map((f) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(f, style: const TextStyle(fontSize: 12)),
                    selected: _selectedObjective == f,
                    onSelected: (_) => setState(() => _selectedObjective = f),
                    selectedColor: AppTheme.gold.withValues(alpha: 0.2),
                    checkmarkColor: AppTheme.marineBlue,
                  ),
                )).toList(),
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: circles.length,
                itemBuilder: (context, index) => _buildTontineItem(circles[index]),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildGlassChip(String label, bool isDark) {
    final isSelected = _selectedObjective == label;
    return GestureDetector(
      onTap: () => setState(() => _selectedObjective = label),
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.gold.withValues(alpha: 0.3)
              : (isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.05)),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? AppTheme.gold : (isDark ? Colors.white30 : Colors.black12)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isDark ? Colors.white : (isSelected ? AppTheme.marineBlue : Colors.black87),
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildFullCircleCard(Map<String, dynamic> circle) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Background Image
        Image.network(
          circle['imageUrl'] ?? 'https://images.unsplash.com/photo-1573164713714-d95e436ab8d6?q=80&w=1000',
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => Container(
            color: AppTheme.marineBlue,
            child: const Center(child: Icon(Icons.account_balance, size: 64, color: Colors.white30)),
          ),
        ),

        // Gradient Overlay
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.2),
                Colors.black.withValues(alpha: 0.8),
              ],
            ),
          ),
        ),

        // Info Overlay
        Positioned(
          bottom: 100,
          left: 20,
          right: 20,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                color: AppTheme.marineBlue,
                child: const Text('Cercle Tontine', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 8),
              InkWell(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (ctx) => CircleDetailsScreen(
                      circleId: circle['id'],
                      circleName: circle['name'],
                      isJoined: false,
                    ),
                  ),
                ),
                child: Text(circle['name'] ?? 'Tontine', style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.location_on, color: Colors.white70, size: 14),
                  const SizedBox(width: 4),
                  Text(circle['location'] ?? 'Universel', style: const TextStyle(color: Colors.white70)),
                  const SizedBox(width: 16),
                  const Icon(Icons.group, color: Colors.white70, size: 14),
                  const SizedBox(width: 4),
                  Text('${circle['members']}/${circle['maxMembers']} places', style: const TextStyle(color: Colors.white70)),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                '${(circle['amount'] as num?)?.toInt() ?? 0} ${circle['currency'] ?? 'FCFA'} / mois',
                style: const TextStyle(color: AppTheme.gold, fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),

        // Action Button
        Positioned(
          bottom: 30,
          right: 20,
          child: FloatingActionButton(
            backgroundColor: AppTheme.marineBlue,
            child: const Icon(Icons.arrow_forward, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (ctx) => CircleDetailsScreen(
                    circleId: circle['id'],
                    circleName: circle['name'],
                    isJoined: false,
                  )
                )
              );
            },
          ),
        )
      ],
    );
  }

  Widget _buildTontineItem(Map<String, dynamic> circle) {
    final int currentMembers = circle['members'] ?? 0;
    final int maxMembers = circle['maxMembers'] ?? 10;
    final double amount = (circle['amount'] as num).toDouble();
    final String name = circle['name'] ?? 'Tontine';
    final String frequency = circle['frequency'] ?? 'Mensuel';
    final tags = (circle['tags'] as List<dynamic>?)?.cast<String>() ?? ['Standard'];

    final bool canJoin = currentMembers < maxMembers;

    final myRequests = ref.watch(circleProvider).myJoinRequests;
    final hasPendingRequest = myRequests.any((r) => r.circleId == circle['id'] && r.status == JoinRequestStatus.pending);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      color: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: AppTheme.marineBlue.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                  child: Text(tags.isNotEmpty ? tags[0] : 'Tontine', style: TextStyle(fontSize: 10, color: Theme.of(context).brightness == Brightness.dark ? AppTheme.gold : AppTheme.marineBlue, fontWeight: FontWeight.bold)),
                ),
                Text('$currentMembers/$maxMembers places', style: TextStyle(color: canJoin ? Colors.green : Colors.red, fontSize: 12, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (ctx) => CircleDetailsScreen(
                    circleId: circle['id'],
                    circleName: name,
                    isJoined: false,
                  ),
                ),
              ),
              child: Text(
                name,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).brightness == Brightness.dark ? AppTheme.gold : AppTheme.marineBlue),
                maxLines: 1, overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.refresh, size: 14, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(frequency, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
              ],
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0),
              child: Divider(),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Cotisation', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                    Text(
                      '${amount.toInt()} ${circle['currency'] ?? 'FCFA'}',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.gold),
                    ),
                  ],
                ),
                if (hasPendingRequest)
                  ElevatedButton(
                    onPressed: null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[300],
                      foregroundColor: Colors.grey[700],
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                    ),
                    child: const Text('En attente...', style: TextStyle(fontSize: 12)),
                  )
                else
                  ElevatedButton(
                    onPressed: canJoin ? () => _joinTontine(circle) : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.marineBlue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                    ),
                    child: Text(canJoin ? 'Rejoindre' : 'Complet', style: const TextStyle(fontSize: 12)),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _joinTontine(Map<String, dynamic> circle) {
    final user = ref.read(userProvider);

    if (user.status == AccountStatus.guest) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Créer un compte'),
          content: const Text('Pour rejoindre une tontine et cotiser, vous devez avoir un compte vérifié.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                context.push('/auth');
              },
              child: const Text('S\'inscrire')
            ),
          ],
        )
      );
      return;
    }

    final plans = ref.read(activePlansProvider).valueOrNull ?? [];
    Plan currentPlan;
    try {
      currentPlan = plans.firstWhere((p) => p.code == user.planId);
    } catch (_) {
      currentPlan = Plan.free();
    }

    final creationError = SubscriptionService.getCreationErrorMessage(
      plan: currentPlan,
      activeCirclesCount: user.activeCirclesCount,
    );

    if (creationError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Limite atteinte (${currentPlan.name}) !'),
          backgroundColor: Colors.red,
          action: SnackBarAction(label: 'UPGRADE', textColor: Colors.white, onPressed: () => context.push('/subscription')),
        )
      );
      return;
    }

    _showJoinRequestDialog(context, circle);
  }

  void _showJoinRequestDialog(BuildContext context, Map<String, dynamic> circle) {
    final messageController = TextEditingController();
    final String circleId = circle['id'];
    final String circleName = circle['name'];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.person_add, color: AppTheme.marineBlue),
            SizedBox(width: 12),
            Text('Demande d\'adhésion'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark ? Colors.blue.withValues(alpha: 0.2) : Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Le créateur du cercle doit approuver votre demande. Une fois approuvé, vous devrez signer la charte pour finaliser.',
                style: TextStyle(fontSize: 12),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: messageController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Message au créateur (optionnel)...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () async {
              final user = ref.read(userProvider);
              Navigator.pop(context);

              await ref.read(circleProvider.notifier).requestToJoin(
                circleId: circleId,
                circleName: circleName,
                requesterId: user.uid,
                requesterName: user.displayName,
                message: messageController.text,
              );

              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Demande envoyée !')));
              }
            },
            child: const Text('ENVOYER')
          ),
        ],
      ),
    );
  }
}

class _CommunityTab extends ConsumerStatefulWidget {
  const _CommunityTab();

  @override
  ConsumerState<_CommunityTab> createState() => _CommunityTabState();
}

class _CommunityTabState extends ConsumerState<_CommunityTab> {
  Future<List<SuggestionResult>>? _suggestionsFuture;
  final Set<String> _hiddenUserIds = {};
  bool _isSyncingContacts = false;

  // Search functionality
  String _searchQuery = '';
  List<SuggestionResult> _searchResults = [];
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSuggestions();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _loadSuggestions() {
    final user = ref.read(userProvider);
    if (user.uid.isNotEmpty) {
      setState(() {
        _suggestionsFuture = ref.read(suggestionServiceProvider).getSuggestions(user.uid);
      });
    }
  }

  Future<void> _onSearch(String query) async {
    setState(() {
      _searchQuery = query;
    });

    if (query.isNotEmpty && query.length >= 2) {
      setState(() => _isSearching = true);
      try {
        final results = await ref.read(socialProvider.notifier).searchUsers(query);
        if (mounted) {
          setState(() {
            _searchResults = results;
            _isSearching = false;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isSearching = false);
        }
      }
    } else {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
    }
  }

  Future<void> _syncContacts() async {
    setState(() => _isSyncingContacts = true);
    try {
      final contactService = ref.read(contactServiceProvider);
      final matches = await contactService.findRegisteredContacts();

      if (matches.isEmpty) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Aucun contact trouvé sur Tontetic.')));
      } else {
        final newSuggestions = matches.map((m) => SuggestionResult(
          userId: m.userId,
          userName: m.userData['fullName'] ?? m.userData['pseudo'] ?? m.contactName,
          userAvatar: m.userData['photoUrl'],
          reason: 'Contact: ${m.contactName}',
          mutualFriendsCount: 0,
        )).toList();

        final currentSuggestions = await _suggestionsFuture ?? [];
        final uniqueNew = newSuggestions.where((n) => !currentSuggestions.any((c) => c.userId == n.userId)).toList();
        final List<SuggestionResult> merged = [...uniqueNew, ...currentSuggestions];

        setState(() {
          _suggestionsFuture = Future.value(merged);
        });

        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${uniqueNew.length} contacts trouvés !')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur synchro: $e')));
    } finally {
      if (mounted) setState(() => _isSyncingContacts = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        // Search Bar
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          height: 44,
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: isDark ? Colors.white30 : Colors.grey.shade300),
            boxShadow: !isDark ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))] : null,
          ),
          child: Row(
            children: [
              Icon(Icons.search, color: isDark ? Colors.white70 : Colors.grey, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _searchController,
                  style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 14),
                  onChanged: _onSearch,
                  decoration: InputDecoration(
                    hintText: 'Rechercher un utilisateur...',
                    hintStyle: TextStyle(color: isDark ? Colors.white.withValues(alpha: 0.4) : Colors.grey),
                    border: InputBorder.none,
                  ),
                ),
              ),
              if (_searchQuery.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: () {
                    _searchController.clear();
                    _onSearch('');
                  },
                ),
            ],
          ),
        ),

        // Content
        Expanded(
          child: _isSearching
            ? const Center(child: CircularProgressIndicator())
            : _searchQuery.isNotEmpty
              ? _buildSearchResults()
              : _buildSuggestionsList(),
        ),
      ],
    );
  }

  Widget _buildSearchResults() {
    final visibleResults = _searchResults.where((s) => !_hiddenUserIds.contains(s.userId)).toList();

    if (visibleResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.search_off, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              'Aucun utilisateur trouvé pour "$_searchQuery"',
              style: const TextStyle(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 0),
      itemCount: visibleResults.length,
      itemBuilder: (context, index) => _buildSuggestionCard(context, visibleResults[index]),
    );
  }

  Widget _buildSuggestionsList() {
    return FutureBuilder<List<SuggestionResult>>(
      future: _suggestionsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Erreur: ${snapshot.error}'));
        }

        final suggestions = snapshot.data ?? [];
        final visibleSuggestions = suggestions.where((s) => !_hiddenUserIds.contains(s.userId)).toList();

        if (visibleSuggestions.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.people_outline, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                const Text('Aucune suggestion pour le moment', style: TextStyle(color: Colors.grey)),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _loadSuggestions,
                  child: const Text('Actualiser'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _syncContacts,
                  icon: const Icon(Icons.contacts),
                  label: const Text('Synchroniser contacts'),
                ),
              ],
            ),
          );
        }

        return CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Connaissez-vous ?',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).brightness == Brightness.dark ? AppTheme.gold : AppTheme.marineBlue,
                      ),
                    ),
                    Row(
                      children: [
                        if (_isSyncingContacts)
                          const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        else
                          IconButton(
                            icon: const Icon(Icons.contacts, color: AppTheme.marineBlue),
                            tooltip: 'Synchroniser contacts',
                            onPressed: _syncContacts,
                          ),
                        IconButton(
                          icon: const Icon(Icons.refresh, color: AppTheme.marineBlue),
                          tooltip: 'Actualiser',
                          onPressed: _loadSuggestions,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final person = visibleSuggestions[index];
                  return _buildSuggestionCard(context, person);
                },
                childCount: visibleSuggestions.length,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSuggestionCard(BuildContext context, SuggestionResult person) {
    final social = ref.watch(socialProvider);
    final isFollowing = social.following.contains(person.userId);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundImage: person.userAvatar != null && person.userAvatar!.isNotEmpty
                ? NetworkImage(person.userAvatar!)
                : null,
            backgroundColor: AppTheme.marineBlue.withAlpha(30),
            child: person.userAvatar == null || person.userAvatar!.isEmpty
                ? Text(person.userName.isNotEmpty ? person.userName[0].toUpperCase() : '?', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.marineBlue))
                : null,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  person.userName,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.group, size: 14, color: Colors.grey),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        person.reason,
                        style: const TextStyle(color: Colors.grey, fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                if (person.jobTitle != null && person.jobTitle!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      person.jobTitle!,
                      style: const TextStyle(color: Colors.grey, fontSize: 11),
                    ),
                  ),
              ],
            ),
          ),
          Column(
            children: [
              ElevatedButton(
                onPressed: () {
                   ref.read(socialProvider.notifier).toggleFollow(person.userId);
                   ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isFollowing ? 'Retiré !' : 'Invitation envoyée !')));
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: isFollowing ? Colors.white : AppTheme.marineBlue,
                  foregroundColor: isFollowing ? AppTheme.marineBlue : Colors.white,
                  side: isFollowing ? const BorderSide(color: AppTheme.marineBlue) : null,
                  minimumSize: const Size(80, 32),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  elevation: 0,
                ),
                child: Text(isFollowing ? 'Suivi' : 'Ajouter', style: const TextStyle(fontSize: 12)),
              ),
              const SizedBox(height: 4),
              InkWell(
                onTap: () {
                   setState(() {
                     _hiddenUserIds.add(person.userId);
                   });
                },
                child: const Padding(
                  padding: EdgeInsets.all(4.0),
                  child: Text('Retirer', style: TextStyle(fontSize: 11, color: Colors.grey)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
void _showAuthRequiredDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Connexion requise'),
      content: const Text('Vous devez créer un compte ou vous connecter pour accéder à cette fonctionnalité.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Annuler'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(ctx);
            context.go('/auth');
          },
          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.marineBlue),
          child: const Text('Se connecter'),
        ),
      ],
    ),
  );
}
