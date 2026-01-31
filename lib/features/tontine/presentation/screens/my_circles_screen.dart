import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tontetic/core/theme/app_theme.dart';
import 'package:tontetic/core/providers/user_provider.dart';

import 'package:tontetic/features/social/data/social_provider.dart';
import 'package:tontetic/features/social/data/contact_service.dart';
import 'package:tontetic/features/social/data/suggestion_service.dart';
import 'package:tontetic/features/social/presentation/screens/profile_screen.dart';
import 'package:tontetic/features/social/presentation/screens/conversations_list_screen.dart';
import 'package:tontetic/core/business/subscription_service.dart';
import 'package:tontetic/features/tontine/presentation/screens/legal_commitment_screen.dart';
// import 'package:tontetic/core/services/pdf_export_service.dart'; // V10.1 PDF - UNUSED
import 'package:tontetic/core/services/notification_service.dart'; // V10.1 Notifications
import 'package:tontetic/features/tontine/presentation/screens/qr_scanner_screen.dart';
import 'package:tontetic/core/providers/localization_provider.dart';
import 'package:tontetic/core/providers/circle_provider.dart';
import 'package:tontetic/core/providers/auth_provider.dart';
import 'package:tontetic/features/tontine/presentation/screens/circle_chat_screen.dart';
import 'package:tontetic/features/tontine/presentation/screens/circle_details_screen.dart'; // V16 Import
import 'package:go_router/go_router.dart';
import 'package:tontetic/core/models/plan_model.dart';
import 'package:tontetic/core/providers/plans_provider.dart';
import 'package:tontetic/core/services/security_service.dart';

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
        final activityFeedHeight = isLandscape ? 100.0 : 145.0;
        // final dashboardHeight = isLandscape ? 100.0 : null; - UNUSED

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
                      value: 0.5,
                      backgroundColor: Colors.grey[200],
                      color: AppTheme.gold,
                      strokeWidth: 6,
                    ),
                  ),
                  Text(
                    '50',
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
                      l10n.translate('honor_score_status'),
                      style: const TextStyle(fontSize: 12, color: AppTheme.gold, fontWeight: FontWeight.w600),
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
  String _selectedAmount = 'Tous';
  String _selectedLocation = 'Tous';
  
  List<String> get _amountFilters {
    final user = ref.read(userProvider);
    final isEuro = user.currencySymbol == '€';
    
    if (isEuro) {
      return ['Tous', '50-100€', '100-300€', '300-500€', '+500€'];
    } else {
      // FCFA Defaults
      return ['Tous', '10k-50k', '50k-100k', '100k-200k', '+200k'];
    }
  }

  final List<String> _locationFilters = ['Tous', 'Dakar', 'Paris', 'Universel'];

  @override
  Widget build(BuildContext context) {
    // Determine currency symbol for display consistency
    final user = ref.watch(userProvider);
    final isEuro = user.currencySymbol == '€';

    return Column(
      children: [
        // V15: Enhanced User Dashboard (Point 6)
        _buildUserDashboardCard(context, ref),

        // Filtres
        Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          color: Colors.white,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                const Text('Montant:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                const SizedBox(width: 8),
                ..._amountFilters.map((f) => _buildFilterChip(f, _selectedAmount, (v) => setState(() => _selectedAmount = v))),
                const SizedBox(width: 16),
                 Text('Lieu:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Theme.of(context).brightness == Brightness.dark ? AppTheme.gold : Colors.grey)),
                const SizedBox(width: 8),
                ..._locationFilters.map((f) => _buildFilterChip(f, _selectedLocation, (v) => setState(() => _selectedLocation = v))),
              ],
            ),
          ),
        ),
        
        // Dynamic List from Firestore
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('tontines')
                .where('isPublic', isEqualTo: true) // Ensure we only show public circles
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

              // Client-side filtering for complex logic or unimplemented indexes
              final circles = docs.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                data['id'] = doc.id;
                // BUGFIX: Use memberIds length instead of participants
                data['members'] = (data['memberIds'] as List?)?.length ?? 0;
                data['maxMembers'] = data['maxParticipants'] ?? 12;
                data['tags'] = data['tags'] ?? ['Tontine'];
                data['trustScoreRequired'] = data['trustScoreRequired'] ?? 0;
                data['location'] = data['location'] ?? 'Universel';
                return data;
              }).where((circle) {
                 final user = ref.read(userProvider);
                 
                 // V16: Exclude my own circles and circles I already joined
                 if (circle['creatorId'] == user.uid) return false;
                 if ((circle['memberIds'] as List).contains(user.uid)) return false;

                 final isEuro = user.currencySymbol == '€';
                 
                 // Amount Filter Logic (Ranges)
                 if (_selectedAmount != 'Tous') {
                   final amount = (circle['amount'] as num).toDouble();
                   
                   if (isEuro) {
                     if (_selectedAmount == '50-100€') return amount >= 50 && amount <= 100;
                     if (_selectedAmount == '100-300€') return amount > 100 && amount <= 300;
                     if (_selectedAmount == '300-500€') return amount > 300 && amount <= 500;
                     if (_selectedAmount == '+500€') return amount > 500;
                   } else {
                     // FCFA
                     if (_selectedAmount == '10k-50k') return amount >= 10000 && amount <= 50000;
                     if (_selectedAmount == '50k-100k') return amount > 50000 && amount <= 100000;
                     if (_selectedAmount == '100k-200k') return amount > 100000 && amount <= 200000;
                     if (_selectedAmount == '+200k') return amount > 200000;
                   }
                   return true; 
                 }
                 
                 // Location Filter
                 if (_selectedLocation != 'Tous') {
                    // Simple string match, ideally normalized
                    if (circle['location'] != _selectedLocation) return false;
                 }
                 return true;
              }).toList();

              if (circles.isEmpty) {
                return const Center(child: Text("Aucun résultat pour ces filtres."));
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: circles.length,
                itemBuilder: (context, index) => _buildTontineItem(circles[index]),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String label, String groupValue, ValueChanged<String> onSelected) {
    final isSelected = groupValue == label;
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (v) => onSelected(label),
        selectedColor: AppTheme.gold.withValues(alpha: 0.2),
        checkmarkColor: AppTheme.marineBlue,
        labelStyle: TextStyle(
          color: isSelected ? AppTheme.marineBlue : Colors.grey[700], 
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          fontSize: 12,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 4),
        visualDensity: VisualDensity.compact,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: isSelected ? AppTheme.gold : Colors.grey.shade200)),
      ),
    );
  }

  Widget _buildTontineItem(Map<String, dynamic> circle, {bool isHorizontal = false}) {

    
    // Safety checks
    final int currentMembers = circle['members'] ?? 0;
    final int maxMembers = circle['maxMembers'] ?? 10;
    final double amount = (circle['amount'] as num).toDouble();
    final String name = circle['name'] ?? 'Tontine';
    final String adminName = circle['creatorName'] ?? 'Admin'; 
    final String location = circle['location'] ?? 'Universel';
    final String frequency = circle['frequency'] ?? 'Mensuel';
    final tags = (circle['tags'] as List<dynamic>?)?.cast<String>() ?? ['Standard'];
    // final int requiredScore = circle['trustScoreRequired'] ?? 0; - UNUSED

    final bool canJoin = currentMembers < maxMembers;
    final bool trustOk = true; 
    
    // Check if I have a pending request
    final myRequests = ref.watch(circleProvider).myJoinRequests;
    final hasPendingRequest = myRequests.any((r) => r.circleId == circle['id'] && r.status == JoinRequestStatus.pending); 

    return Card(
      margin: isHorizontal ? const EdgeInsets.only(right: 8, bottom: 4, left: 4) : const EdgeInsets.only(bottom: 16),
      elevation: 2,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        padding: const EdgeInsets.all(16.0),
        width: isHorizontal ? 280 : null, // Fix width for carousel
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min, // Compact
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: AppTheme.marineBlue.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                  child: Text(tags.isNotEmpty ? tags[0] : 'Tontine', style: TextStyle(fontSize: 10, color: Theme.of(context).brightness == Brightness.dark ? AppTheme.gold : AppTheme.marineBlue, fontWeight: FontWeight.bold)),
                ),
                /* if (!trustOk) 
                  const Tooltip(message: 'Score insuffisant', child: Icon(Icons.lock, color: Colors.orange, size: 20))
                else */
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
                    isJoined: false, // Explorer view is always false initially
                  ),
                ),
              ),
              child: Text(
                name,
                style: TextStyle(fontSize: isHorizontal ? 16 : 18, fontWeight: FontWeight.bold, color: Theme.of(context).brightness == Brightness.dark ? AppTheme.gold : AppTheme.marineBlue),
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
                    onPressed: canJoin && trustOk ? () => _joinTontine(circle) : null,
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

    // Guest Check (V3.5)
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
                // Trigger onboarding flow if needed
              }, 
              child: const Text('S\'inscrire')
            ),
          ],
        )
      );
      return;
    }

    // V17: Fetch Plan object dynamically
    // V17: Fetch Plan object dynamically
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

    // V16: New Flow - Request First, Sign Later (Approval Phase)
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSuggestions();
    });
  }

  void _loadSuggestions() {
    final user = ref.read(userProvider);
    if (user.uid.isNotEmpty) {
      setState(() {
        _suggestionsFuture = ref.read(suggestionServiceProvider).getSuggestions(user.uid);
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
              ],
            ),
          );
        }

        return CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
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
                    if (_isSyncingContacts)
                      const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    else
                      IconButton(
                        icon: const Icon(Icons.sync, color: AppTheme.marineBlue),
                        tooltip: 'Synchroniser contacts',
                        onPressed: _syncContacts,
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
              ],
            ),
          ),
          Column(
            children: [
              ElevatedButton(
                onPressed: () {
                   ref.read(socialProvider.notifier).toggleFollow(person.userId);
                   ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isFollowing ? 'Retiré !' : 'Suggestion ajoutée !')));
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
