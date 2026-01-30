import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tontetic/core/providers/user_provider.dart';
import 'package:tontetic/core/theme/app_theme.dart';
import 'package:tontetic/core/providers/localization_provider.dart';
import 'package:tontetic/core/services/security_service.dart';
import 'package:tontetic/features/social/data/social_provider.dart';
import 'package:tontetic/features/social/data/suggestion_service.dart';
import 'package:tontetic/features/social/presentation/screens/profile_screen.dart';
import 'package:tontetic/features/tontine/presentation/screens/circle_details_screen.dart';

class ExplorerScreen extends ConsumerStatefulWidget {
  const ExplorerScreen({super.key});

  @override
  ConsumerState<ExplorerScreen> createState() => _ExplorerScreenState();
}

class _ExplorerScreenState extends ConsumerState<ExplorerScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedObjective = 'Pour vous';
  final List<String> _filters = ['Pour vous', 'Proximité', '🏠 Maison', '🚗 Transport', '📦 Business'];
  final Set<String> _hiddenUserIds = {};
  Future<List<SuggestionResult>>? _suggestionsFuture;

  String _searchQuery = '';
  


  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    
    // Legal Gatekeeper: Check on first load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showLegalWarning();
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

  void _showLegalWarning() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('🛡️ Avertissement Technologique'),
        content: const Text(
          'Tontetic est un prestataire technique. Les cercles affichés ici sont créés par des utilisateurs indépendants. '
          'L\'Éditeur ne garantit pas la solvabilité des participants. En continuant, vous reconnaissez que Tontetic n\'est pas un service financier.'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('J\'AI COMPRIS ET J\'ACCEPTE'),
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
              title: const Text('🔐 Rejoindre un cercle privé'),
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
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _onSearch(String query) {
    setState(() {
      _searchQuery = query;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? Colors.black : AppTheme.offWhite,
      body: Column(
        children: [
          // Header with Tabs
          Container(
            padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  isDark ? Colors.black : AppTheme.offWhite, 
                  (isDark ? Colors.black : AppTheme.offWhite).withValues(alpha: 0.8), 
                  Colors.transparent,
                ],
              ),
            ),
            child: Column(
              children: [
                // Search Bar
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  height: 40,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: isDark ? Colors.white30 : Colors.grey.shade300),
                    boxShadow: !isDark ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))] : null,
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.search, color: isDark ? Colors.white70 : Colors.grey, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 13),
                          onChanged: _onSearch,
                          decoration: InputDecoration(
                            hintText: ref.watch(localizationProvider).translate('search_placeholder'),
                            hintStyle: TextStyle(color: isDark ? Colors.white.withValues(alpha: 0.4) : Colors.grey),
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.vpn_key, color: AppTheme.gold, size: 18),
                        onPressed: () => _showJoinByCodeDialog(),
                        tooltip: 'Rejoindre par code',
                      ),
                    ],
                  ),
                ),
                
                // Tab Bar
                TabBar(
                  controller: _tabController,
                  indicatorColor: AppTheme.gold,
                  labelColor: isDark ? Colors.white : AppTheme.marineBlue,
                  unselectedLabelColor: isDark ? Colors.white54 : Colors.grey,
                  labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  tabs: [
                    Tab(icon: const Icon(Icons.explore), text: ref.watch(localizationProvider).translate('tab_circles')),
                    Tab(icon: const Icon(Icons.people), text: ref.watch(localizationProvider).translate('tab_community')),
                  ],
                ),

                // Technical Platform Banner
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  color: Colors.amber.withAlpha(200),
                  child: const Text(
                    '⚠️ Plateforme technique uniquement. Tontetic ne gère pas les fonds.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          
          // Tab Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Tab 1: Circles Feed
                _buildCirclesFeed(),
                // Tab 2: Community
                _buildCommunityTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildCirclesFeed() {



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
        
        // Filter logic
        var feedItems = docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          data['id'] = doc.id;
          // BUGFIX: Use correct Firestore fields
          data['members'] = (data['memberIds'] as List?)?.length ?? 0;
          data['maxMembers'] = data['maxParticipants'] ?? 12;
          data['location'] = data['location'] ?? 'Universel';
          data['currency'] = data['currency'] ?? 'FCFA';

          // Ensure imageUrl defaults if missing
          if (data['imageUrl'] == null || data['imageUrl'].isEmpty) {
             data['imageUrl'] = 'https://images.unsplash.com/photo-1573164713714-d95e436ab8d6?q=80&w=1000';
          }
           // Ensure tags is list
          if (data['tags'] == null) {
            data['tags'] = ['Divers'];
          }
          return data;
        }).where((data) {
           final user = ref.read(userProvider);
           // V16: Exclude my own circles and circles I already joined
           if (data['creatorId'] == user.uid) return false;
           if ((data['memberIds'] as List).contains(user.uid)) return false;
           
           // 1. Search Filter
           if (_searchQuery.isNotEmpty) {
             final name = data['name'].toString().toLowerCase();
             if (!name.contains(_searchQuery.toLowerCase())) return false;
           }
           
           // 2. Objective Filter
            if (_selectedObjective != 'Pour vous') {
              final filterTag = _selectedObjective.split(' ').last.toLowerCase();
              final tags = (data['tags'] as List).map((t) => t.toString().toLowerCase()).toList();
              bool matches = false;
              for(var t in tags) {
                if (t.contains(filterTag)) matches = true;
              }
              // Special case for 'Business' matching 'projet' or similar if needed
              if (!matches) return false;
            }
            
            // 3. (Optional) Mutual Follower logic could go here
            // For now, we show ALL public tontines for data validation
            // final isPublic = data['privacy'] == 'public'; // If we had this field
            
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
              ],
            ),
          );
        }

        return Stack(
          children: [
            PageView.builder(
              scrollDirection: Axis.vertical,
              itemCount: feedItems.length,
              itemBuilder: (context, index) {
                final item = feedItems[index];
                // Check if it's an ad (not implementing ads from Firestore yet, skipping ad logic or keeping if mixed)
                // Assuming all docs are tontines
                return _buildFullCircleCard(item);
              },
            ),
            
            // Floating Filters
            Positioned(
              top: 8,
              left: 0,
              right: 0,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: _filters.map((f) => _buildGlassChip(f)).toList(),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCommunityTab() {
    final user = ref.watch(userProvider);
    // Refresh suggestions if user changed and future is null (or mismatch?) 
    // For now, rely on initial load and manual refresh.
    
    if (_suggestionsFuture == null && user.uid.isNotEmpty) {
       // Trigger load if missing
       Future.microtask(() => _loadSuggestions());
    }

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
                child: Text(
                  'Connaissez-vous ?',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).brightness == Brightness.dark ? AppTheme.gold : AppTheme.marineBlue,
                  ),
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
                // Social Proof / Reason
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
                   Text(
                    person.jobTitle!,
                    style: const TextStyle(color: Colors.grey, fontSize: 11),
                  ),
              ],
            ),
          ),
          // Action Buttons
          Column(
            children: [
              ElevatedButton(
                onPressed: () {
                   ref.read(socialProvider.notifier).toggleFollow(person.userId);
                   ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invitation envoyée !')));
                   setState(() {});
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.marineBlue,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(80, 32),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
                child: const Text('Ajouter', style: TextStyle(fontSize: 12)),
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


  Color _getScoreColor(int score) {
    if (score >= 90) return Colors.green;
    if (score >= 70) return Colors.orange;
    return Colors.red;
  }

  Widget _buildGlassChip(String label) {
    final isSelected = _selectedObjective == label;
    return GestureDetector(
      onTap: () => setState(() {
        _selectedObjective = label;
      }),
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected 
              ? AppTheme.gold.withValues(alpha: 0.3) 
              : (Theme.of(context).brightness == Brightness.dark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.05)),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? AppTheme.gold : (Theme.of(context).brightness == Brightness.dark ? Colors.white30 : Colors.black12)),
        ),
        child: Text(
          label, 
          style: TextStyle(
            color: Theme.of(context).brightness == Brightness.dark ? Colors.white : (isSelected ? AppTheme.marineBlue : Colors.black87), 
            fontSize: 13, 
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildFullCircleCard(Map<String, dynamic> circle) {
    // Organic Circle Design (Immersive)
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.network(circle['imageUrl'], fit: BoxFit.cover),
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
          bottom: 100, // Above button area
          left: 20,
          right: 20,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                color: AppTheme.marineBlue,
                child: Text('Cercle Tontine', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
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
                  child: Text(circle['name'], style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 4),
                 Row(
                   children: [
                     const Icon(Icons.location_on, color: Colors.white70, size: 14),
                     const SizedBox(width: 4),
                     Text(circle['location'], style: const TextStyle(color: Colors.white70)),
                     const SizedBox(width: 16),
                     const Icon(Icons.group, color: Colors.white70, size: 14),
                     const SizedBox(width: 4),
                     Text('${circle['members']}/${circle['maxMembers']} places', style: const TextStyle(color: Colors.white70)),
                   ],
                 ),
                const SizedBox(height: 16),
               Text('${circle['amount']} ${circle['currency'] ?? 'FCFA'} / mois', style: const TextStyle(color: AppTheme.gold, fontSize: 20, fontWeight: FontWeight.bold)),
            ],
          ),
        ),

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
                     isJoined: false, // We look at it from outside
                   )
                 )
               );
            },
          ),
        )
      ],
    );
  }
}
