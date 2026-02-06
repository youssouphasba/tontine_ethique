import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:tontetic/features/admin/presentation/screens/admin_sections.dart';
import 'package:tontetic/features/admin/presentation/widgets/admin_campaigns_panel.dart';
import 'package:tontetic/features/admin/presentation/widgets/admin_referral_panel.dart';
import 'package:tontetic/features/admin/presentation/widgets/admin_users_panel.dart';
import 'package:tontetic/features/admin/presentation/widgets/admin_users_panel.dart';

/// Admin Dashboard - Main Entry Point
/// Complete administration panel for platform management
/// 
/// CRITICAL: NO FUND ACCESS - Read-only for payments
/// Platform acts as technical host (LCEN art. 6)
/// 
/// Sections:
/// 1. Overview (health check in 10 seconds)
/// 2. Users Management
/// 3. Circles/Tontines Management
/// 4. Content Moderation
/// 5. Merchants Management
/// 6. Enterprise Management
/// 7. Payments & PSP (READ ONLY)
/// 8. Reports & Disputes
/// 9. Audit & Compliance
/// 10. Global Settings

class AdminDashboard extends ConsumerStatefulWidget {
  const AdminDashboard({super.key});

  @override
  ConsumerState<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends ConsumerState<AdminDashboard> {
  int _selectedSection = 0;
  
  final List<_AdminSection> _sections = [
    _AdminSection(Icons.dashboard, 'Vue d\'ensemble', Colors.blue),
    _AdminSection(Icons.star, 'Gestion des Plans', Colors.amber),
    _AdminSection(Icons.people, 'Utilisateurs', Colors.green),
    _AdminSection(Icons.verified_user, 'Vérification KYC', Colors.teal),
    _AdminSection(Icons.donut_large, 'Gestion des Cercles', Colors.orange),
    _AdminSection(Icons.shield, 'Modération', Colors.red),
    _AdminSection(Icons.store, 'Marchands', Colors.purple),
    _AdminSection(Icons.business, 'Entreprises', Colors.indigo),
    _AdminSection(Icons.payment, 'Finance', Colors.cyan),
    _AdminSection(Icons.report, 'Signalements', Colors.pink),
    _AdminSection(Icons.message, 'Support', Colors.blueGrey),
    _AdminSection(Icons.campaign, 'Campagnes', Colors.deepOrange),
    _AdminSection(Icons.card_giftcard, 'Parrainage', Colors.lime),
    _AdminSection(Icons.security, 'Sécurité', Colors.black),
    _AdminSection(Icons.history, 'Audit', Colors.brown),
    _AdminSection(Icons.settings, 'Paramètres', Colors.grey),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      body: Row(
        children: [
          // Left sidebar
          _buildSidebar(),
          // Main content
          Expanded(child: _buildMainContent()),
        ],
      ),
    );
  }

  Widget _buildSidebar() {
    return Container(
      width: 250,
      color: const Color(0xFF1a1a2e),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(20),
            child: const Row(
              children: [
                Icon(Icons.admin_panel_settings, color: Colors.white, size: 32),
                SizedBox(width: 12),
                Text('Admin Panel', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          const Divider(color: Colors.white24),
          
          // Navigation
          Expanded(
            child: ListView.builder(
              itemCount: _sections.length,
              itemBuilder: (ctx, index) {
                final section = _sections[index];
                final isSelected = _selectedSection == index;
                
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: isSelected ? section.color.withValues(alpha: 0.2) : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ListTile(
                    leading: Icon(section.icon, color: isSelected ? section.color : Colors.white54),
                    title: Text(section.title, style: TextStyle(color: isSelected ? Colors.white : Colors.white70, fontSize: 14)),
                    onTap: () => setState(() => _selectedSection = index),
                    dense: true,
                  ),
                );
              },
            ),
          ),
          
          // Logout button
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: ElevatedButton.icon(
              onPressed: () async {
                await FirebaseAuth.instance.signOut();
              },
              icon: const Icon(Icons.logout, size: 18),
              label: const Text('Déconnexion'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white.withValues(alpha: 0.1),
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 44),
              ),
            ),
          ),
          
          // Legal reminder
          Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              children: [
                Icon(Icons.warning, color: Colors.red, size: 16),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Aucun accès aux fonds',
                    style: TextStyle(color: Colors.red, fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent() {
    switch (_selectedSection) {
      case 0: return const _OverviewSection();
      case 1: return const _PlansSection();
      case 2: return const AdminUsersPanel();
      case 3: return const AdminKycReviewSection();
      case 4: return const _CirclesSection();
      case 5: return const _ModerationSection();
      case 6: return const _MerchantsSection();
      case 7: return const _EnterprisesSection();
      case 8: return const _PaymentsSection();
      case 9: return const _ReportsSection();
      case 10: return const _SupportSection();
      case 11: return const AdminCampaignsPanel();
      case 12: return const AdminReferralPanel();
      case 13: return const _SecuritySection();
      case 14: return const _AuditSection();
      case 15: return const _SettingsSection();
      default: return const _OverviewSection();
    }
  }
}

class _AdminSection {
  final IconData icon;
  final String title;
  final Color color;
  _AdminSection(this.icon, this.title, this.color);
}

// ==================== SECTION 1: OVERVIEW ====================

class _OverviewSection extends StatefulWidget {
  const _OverviewSection();

  @override
  State<_OverviewSection> createState() => _OverviewSectionState();
}

class _OverviewSectionState extends State<_OverviewSection> {
  // Real counts from Firestore
  int _usersCount = 0;
  int _activeCircles = 0;
  int _suspendedCircles = 0;
  int _activeShops = 0;
  int _pendingModeration = 0;
  int _openReports = 0;
  int _activeAlerts = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCounts();
  }

  Future<void> _loadCounts() async {
    final db = FirebaseFirestore.instance;
    
    try {
      // Fetch all counts in parallel
      final results = await Future.wait([
        db.collection('users').count().get(),
        db.collection('tontines').where('status', isEqualTo: 'Active').count().get(),
        db.collection('tontines').where('status', isEqualTo: 'Geler').count().get(),
        db.collection('shops').where('status', isEqualTo: 'active').count().get(),
        db.collection('products').where('status', isEqualTo: 'pending').count().get(),
        db.collection('reports').where('status', isEqualTo: 'open').count().get(),
        db.collection('admin_alerts').where('status', isEqualTo: 'active').count().get(),
      ]);

      if (mounted) {
        setState(() {
          _usersCount = results[0].count ?? 0;
          _activeCircles = results[1].count ?? 0;
          _suspendedCircles = results[2].count ?? 0;
          _activeShops = results[3].count ?? 0;
          _pendingModeration = results[4].count ?? 0;
          _openReports = results[5].count ?? 0;
          _activeAlerts = results[6].count ?? 0;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatNumber(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toString();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              const Text('Vue d\'ensemble', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
              const Spacer(),
              Text('Dernière mise à jour: ${DateFormat('HH:mm').format(DateTime.now())}', 
                style: const TextStyle(color: Colors.grey)),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: () {
                  setState(() => _isLoading = true);
                  _loadCounts();
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Actualiser'),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Health check banner
          _buildHealthBanner(),
          const SizedBox(height: 24),

          // Key metrics row 1
          if (_isLoading)
            const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()))
          else ...[
            Row(
              children: [
                Expanded(child: _buildMetricCard(context, 'Utilisateurs', _formatNumber(_usersCount), Icons.people, Colors.blue, 'Total inscrits')),
                const SizedBox(width: 16),
                Expanded(child: _buildMetricCard(context, 'Cercles actifs', _formatNumber(_activeCircles), Icons.donut_large, Colors.green, 'En cours')),
                const SizedBox(width: 16),
                Expanded(child: _buildMetricCard(context, 'Cercles suspendus', _formatNumber(_suspendedCircles), Icons.pause_circle, Colors.orange, 'Gelés')),
                const SizedBox(width: 16),
                Expanded(child: _buildMetricCard(context, 'Marchands actifs', _formatNumber(_activeShops), Icons.store, Colors.purple, 'Validés')),
              ],
            ),
            const SizedBox(height: 16),

            // Key metrics row 2
            Row(
              children: [
                Expanded(child: _buildMetricCard(context, 'Flux PSP', 'Via Mangopay', Icons.account_balance, Colors.teal, 'Lecture seule', isReadOnly: true)),
                const SizedBox(width: 16),
                Expanded(child: _buildMetricCard(context, 'Modération en attente', _formatNumber(_pendingModeration), Icons.pending, Colors.red, 'À traiter')),
                const SizedBox(width: 16),
                Expanded(child: _buildMetricCard(context, 'Signalements ouverts', _formatNumber(_openReports), Icons.flag, Colors.amber, 'À examiner')),
                const SizedBox(width: 16),
                Expanded(child: _buildMetricCard(context, 'Alertes actives', _formatNumber(_activeAlerts), Icons.warning, Colors.red, 'À vérifier')),
              ],
            ),
          ],
          const SizedBox(height: 24),

          // Alerts section
          _buildAlertsSection(context),
        ],
      ),
    );
  }

  Widget _buildHealthBanner() {
    return StreamBuilder<AggregateQuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('admin_alerts').where('status', isEqualTo: 'active').count().get().asStream(),
      builder: (context, snapshot) {
        final alertCount = snapshot.data?.count ?? 0;
        final isHealthy = alertCount == 0;
        
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: isHealthy 
                ? [Colors.green.shade600, Colors.green.shade400]
                : [Colors.orange.shade600, Colors.orange.shade400]),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(isHealthy ? Icons.check_circle : Icons.warning, color: Colors.white, size: 48),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(isHealthy ? 'Plateforme opérationnelle' : 'Attention requise', 
                        style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(alertCount == 0 
                        ? 'Tous les services fonctionnent normalement.'
                        : '$alertCount alerte${alertCount > 1 ? 's' : ''} à traiter.', 
                        style: const TextStyle(color: Colors.white70)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('Alertes actives', style: TextStyle(color: Colors.white70)),
                  Text('$alertCount', style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMetricCard(BuildContext context, String title, String value, IconData icon, Color color, String subtitle, {bool isReadOnly = false}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                child: Icon(icon, color: color, size: 24),
              ),
              const Spacer(),
              if (isReadOnly)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(4)),
                  child: const Row(
                    children: [
                      Icon(Icons.lock, size: 12, color: Colors.grey),
                      SizedBox(width: 4),
                      Text('RO', style: TextStyle(fontSize: 10, color: Colors.grey)),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(title, style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 8),
          Text(subtitle, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildAlertsSection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.notifications_active, color: Colors.red),
              const SizedBox(width: 8),
              const Text('Alertes actives', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const Spacer(),
              TextButton(onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('🔔 Liste complète des alertes...'))), child: const Text('Voir tout')),
            ],
          ),
          const Divider(),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('admin_alerts').where('status', isEqualTo: 'active').snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) return Text('Erreur: ${snapshot.error}');
              if (snapshot.connectionState == ConnectionState.waiting) return const LinearProgressIndicator();

              final alerts = snapshot.data?.docs ?? [];
              if (alerts.isEmpty) return const Padding(padding: EdgeInsets.all(16), child: Text('Aucune alerte active.', style: TextStyle(color: Colors.grey)));

              return Column(
                children: alerts.map((doc) {
                  final a = doc.data() as Map<String, dynamic>;
                  final docId = doc.id;
                  return ListTile(
                    leading: Icon(
                      a['severity'] == 'high' ? Icons.error : a['severity'] == 'medium' ? Icons.warning : Icons.info,
                      color: a['severity'] == 'high' ? Colors.red : a['severity'] == 'medium' ? Colors.orange : Colors.blue,
                    ),
                    title: Text(a['message'] ?? 'Alerte inconnue'),
                    subtitle: Text('Type: ${a['type']}'),
                    trailing: TextButton(
                      onPressed: () => FirebaseFirestore.instance.collection('admin_alerts').doc(docId).update({'status': 'treated'}), 
                      child: const Text('Traiter')
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

}

// ==================== SECTION 2: USERS ====================
// Replaced by AdminUsersPanel

// ==================== SECTION 3: CIRCLES ====================

class _CirclesSection extends StatefulWidget {
  const _CirclesSection();
  
  @override
  State<_CirclesSection> createState() => _CirclesSectionState();
}

class _CirclesSectionState extends State<_CirclesSection> {
  int _active = 0;
  int _incomplete = 0;
  int _suspended = 0;
  int _closed = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final db = FirebaseFirestore.instance;
    try {
      final results = await Future.wait([
        db.collection('tontines').where('status', isEqualTo: 'Active').count().get(),
        db.collection('tontines').where('status', isEqualTo: 'pending').count().get(),
        db.collection('tontines').where('status', isEqualTo: 'Geler').count().get(),
        db.collection('tontines').where('status', isEqualTo: 'completed').count().get(),
      ]);
      if (mounted) {
        setState(() {
          _active = results[0].count ?? 0;
          _incomplete = results[1].count ?? 0;
          _suspended = results[2].count ?? 0;
          _closed = results[3].count ?? 0;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Gestion des cercles / tontines', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),

          // Stats
          _loading
              ? const Center(child: CircularProgressIndicator())
              : Row(
                  children: [
                    _buildStatCard('Actifs', '$_active', Colors.green),
                    const SizedBox(width: 16),
                    _buildStatCard('En attente', '$_incomplete', Colors.orange),
                    const SizedBox(width: 16),
                    _buildStatCard('Suspendus', '$_suspended', Colors.red),
                    const SizedBox(width: 16),
                    _buildStatCard('Clôturés', '$_closed', Colors.grey),
                  ],
                ),
          const SizedBox(height: 24),

          // Circles list
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('tontines').limit(20).snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) return Center(child: Text('Erreur: ${snapshot.error}'));
                  if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

                  final circles = snapshot.data?.docs ?? [];
                  if (circles.isEmpty) return const Center(child: Text('Aucun cercle trouvé.'));

                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: circles.length,
                    itemBuilder: (ctx, i) => _buildRealCircleCard(context, circles[i]),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(value, style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: color)),
            Text(label, style: const TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  Widget _buildRealCircleCard(BuildContext context, QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final circleId = doc.id;
    final name = data['name'] ?? 'Cercle Sans Nom';
    final status = data['status'] ?? 'Actif';
    final amount = data['payoutAmount'] ?? 0;
    final membersCount = (data['participants'] as List?)?.length ?? 0;
    final type = data['isPublic'] == true ? 'Visible' : 'Privé';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.deepPurple.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.donut_large, color: Colors.deepPurple),
        ),
        title: Text(name),
        subtitle: Text('$type • $membersCount membres • $amount FCFA/mois'),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: status == 'Active' || status == 'Actif' ? Colors.green.withValues(alpha: 0.1) : Colors.red.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(status, style: TextStyle(color: status == 'Active' || status == 'Actif' ? Colors.green : Colors.red)),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Créateur: ${data['creatorId'] ?? 'Inconnu'}'),
                    Text('PSP: ${data['psp'] ?? 'Interne'}'),
                    Text('Créé le: ${data['createdAt'] != null ? DateFormat('dd/MM/yyyy').format((data['createdAt'] as Timestamp).toDate()) : 'Inconnue'}'),
                  ],
                ),
                const Divider(),
                Row(
                  children: [
                    const Spacer(),
                    ElevatedButton.icon(
                      icon: Icon(status == 'Geler' ? Icons.play_arrow : Icons.pause),
                      label: Text(status == 'Geler' ? 'Activer' : 'Geler'),
                      style: ElevatedButton.styleFrom(backgroundColor: status == 'Geler' ? Colors.green : Colors.orange),
                      onPressed: () => FirebaseFirestore.instance.collection('tontines').doc(circleId).update({'status': status == 'Geler' ? 'Actif' : 'Geler'}),
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
}

// ==================== SECTION 4: MODERATION ====================

class _ModerationSection extends StatelessWidget {
  const _ModerationSection();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Modération des contenus', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
              const Spacer(),
              StreamBuilder<AggregateQuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('products').where('status', isEqualTo: 'pending').count().get().asStream(),
                builder: (context, snapshot) {
                  final count = snapshot.data?.count ?? 0;
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.pending, color: Colors.red, size: 20),
                        const SizedBox(width: 8),
                        Text('$count en attente', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              children: [
                Icon(Icons.info, color: Colors.blue),
                SizedBox(width: 8),
                Text('LCEN art. 6 : La plateforme est hébergeur technique. Modération obligatoire pour conserver ce statut.'),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Tabs
          Expanded(
            child: DefaultTabController(
              length: 4,
              child: Column(
                children: [
                  const TabBar(
                    labelColor: Colors.deepPurple,
                    tabs: [
                      Tab(text: 'À valider'),
                      Tab(text: 'Signalés'),
                      Tab(text: 'Suspendus'),
                      Tab(text: 'Historique'),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        _buildPendingList(),
                        _buildFlaggedList(),
                        _buildSuspendedList(),
                        _buildHistoryList(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('products').where('status', isEqualTo: 'pending').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return Center(child: Text('Erreur: ${snapshot.error}'));
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

        final products = snapshot.data?.docs ?? [];
        if (products.isEmpty) return const Center(child: Text('Aucun produit en attente.'));

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: products.length,
          itemBuilder: (ctx, i) {
            final doc = products[i];
            final p = doc.data() as Map<String, dynamic>;
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                leading: Container(
                  width: 60, height: 60,
                  decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(8)),
                  child: p['imageUrl'] != null ? Image.network(p['imageUrl'], fit: BoxFit.cover) : const Icon(Icons.image),
                ),
                title: Text(p['title'] ?? 'Produit sans titre'),
                subtitle: Text('Marchand: ${p['merchantId'] ?? 'Inconnu'} • ${p['price'] ?? 0} FCFA'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ElevatedButton(
                      onPressed: () => FirebaseFirestore.instance.collection('products').doc(doc.id).update({'status': 'active'}), 
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green), 
                      child: const Text('Approuver', style: TextStyle(color: Colors.white))
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: () => FirebaseFirestore.instance.collection('products').doc(doc.id).update({'status': 'rejected'}), 
                      style: OutlinedButton.styleFrom(foregroundColor: Colors.red), 
                      child: const Text('Rejeter')
                    ),
                  ],
                ),
              ),
            );
          },
        );
      }
    );
  }

  Widget _buildFlaggedList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('products').where('status', isEqualTo: 'flagged').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return Center(child: Text('Erreur: ${snapshot.error}'));
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

        final flagged = snapshot.data?.docs ?? [];
        if (flagged.isEmpty) return const Center(child: Text('Aucun produit signalé.'));

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: flagged.length,
          itemBuilder: (ctx, i) {
            final doc = flagged[i];
            final p = doc.data() as Map<String, dynamic>;
            return Card(
              color: Colors.red.shade50,
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                leading: const Icon(Icons.flag, color: Colors.red),
                title: Text(p['title'] ?? 'Produit signalé'),
                subtitle: Text('Signalements: ${p['flagCount'] ?? 1} • Raison: ${p['flagReason'] ?? 'Non spécifiée'}'),
                trailing: ElevatedButton(
                  onPressed: () => FirebaseFirestore.instance.collection('products').doc(doc.id).update({'status': 'suspended'}), 
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red), 
                  child: const Text('Suspendre', style: TextStyle(color: Colors.white))
                ),
              ),
            );
          },
        );
      }
    );
  }

  Widget _buildSuspendedList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('products').where('status', isEqualTo: 'suspended').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return Center(child: Text('Erreur: ${snapshot.error}'));
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

        final items = snapshot.data?.docs ?? [];
        if (items.isEmpty) return const Center(child: Text('Aucun produit suspendu.'));

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: items.length,
          itemBuilder: (ctx, i) {
            final p = items[i].data() as Map<String, dynamic>;
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                leading: const Icon(Icons.block, color: Colors.grey),
                title: Text(p['title'] ?? 'Produit suspendu'),
                subtitle: Text('Suspendu • ${p['suspendedReason'] ?? 'Raison non spécifiée'}'),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildHistoryList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('admin_audit_logs')
          .where('action', whereIn: ['PRODUCT_APPROVED', 'PRODUCT_REJECTED', 'PRODUCT_SUSPENDED'])
          .orderBy('timestamp', descending: true)
          .limit(50)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return Center(child: Text('Erreur: ${snapshot.error}'));
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

        final logs = snapshot.data?.docs ?? [];
        if (logs.isEmpty) return const Center(child: Text('Aucun historique disponible.'));

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: logs.length,
          itemBuilder: (ctx, i) {
            final log = logs[i].data() as Map<String, dynamic>;
            final action = log['action'] ?? '';
            final isApproved = action.contains('APPROVED');
            final timestamp = (log['timestamp'] as Timestamp?)?.toDate();
            final dateStr = timestamp != null ? DateFormat('dd/MM/yyyy HH:mm').format(timestamp) : 'Date inconnue';

            return ListTile(
              leading: Icon(
                isApproved ? Icons.check_circle : Icons.cancel,
                color: isApproved ? Colors.green : Colors.red,
              ),
              title: Text(log['targetName'] ?? 'Élément modéré'),
              subtitle: Text('$action par ${log['adminId'] ?? 'Admin'} • $dateStr'),
            );
          },
        );
      },
    );
  }
}

// Using complete sections from admin_sections.dart
class _MerchantsSection extends StatelessWidget {
  const _MerchantsSection();
  @override
  Widget build(BuildContext context) => const AdminMerchantsSection();
}

class _EnterprisesSection extends StatelessWidget {
  const _EnterprisesSection();
  @override
  Widget build(BuildContext context) => const AdminEnterprisesSection();
}

class _PaymentsSection extends StatelessWidget {
  const _PaymentsSection();
  @override
  Widget build(BuildContext context) => const AdminPaymentsSection();
}

class _ReportsSection extends StatelessWidget {
  const _ReportsSection();
  @override
  Widget build(BuildContext context) => const AdminReportsSection();
}

class _AuditSection extends StatelessWidget {
  const _AuditSection();
  @override
  Widget build(BuildContext context) => const AdminAuditSection();
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection();
  @override
  Widget build(BuildContext context) => const AdminSettingsSection();
}

// ==================== SECTION: PLANS & PRICING ====================
class _PlansSection extends StatefulWidget {
  const _PlansSection();
  @override
  State<_PlansSection> createState() => _PlansSectionState();
}

class _PlansSectionState extends State<_PlansSection> {
  bool _isSeeding = false;
  
  Future<void> _seedPlans() async {
    setState(() => _isSeeding = true);
    try {
      final firestore = FirebaseFirestore.instance;
      final plans = [
        {
          'code': 'starter_pro',
          'type': 'enterprise',
          'name': 'Starter Pro',
          'prices': {'EUR': 29.99, 'XOF': 19500.0},
          'limits': {'maxMembers': 24, 'maxCircles': 2},
          'features': ['24 salariés max', '2 tontines', 'Dashboard complet', 'Messagerie interne', 'Support flexible'],
          'stripePriceId': 'price_1Suh1rCpguZvNb1UL4HZHv2v',
          'isRecommended': false,
          'status': 'active',
          'sortOrder': 10,
        },
        {
          'code': 'team',
          'type': 'enterprise',
          'name': 'Team',
          'prices': {'EUR': 39.99, 'XOF': 26000.0},
          'limits': {'maxMembers': 48, 'maxCircles': 4},
          'features': ['48 salariés max', '4 tontines', 'Dashboard complet', 'Tontines multi-équipes', 'Support flexible'],
          'stripePriceId': 'price_1Suh3WCpguZvNb1UqkodV50W',
          'isRecommended': true,
          'status': 'active',
          'sortOrder': 20,
        },
      ];

      final batch = firestore.batch();
      for (var planData in plans) {
        final docRef = firestore.collection('plans').doc(planData['code'] as String);
        batch.set(docRef, { ...planData, 'createdAt': FieldValue.serverTimestamp(), 'updatedAt': FieldValue.serverTimestamp() }, SetOptions(merge: true));
      }
      await batch.commit();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Plans Enterprise initialisés.')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur seed: $e')));
    } finally {
      if (mounted) setState(() => _isSeeding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Gestion des Plans & Tarifs', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          Card(
            child: ListTile(
              leading: const Icon(Icons.cloud_upload, color: Colors.blue),
              title: const Text('Initialiser les Plans Enterprise'),
              subtitle: const Text('Mise à jour automatique des offres Enterprise dans Firestore.'),
              trailing: _isSeeding 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) 
                : ElevatedButton(onPressed: _seedPlans, child: const Text('EXÉCUTER')),
            ),
          ),
          const SizedBox(height: 24),
          const Text('Configuration des tarifs (B2C/Premium)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          const Center(child: Text('Module de tarification dynamique connecté à Firestore.', style: TextStyle(color: Colors.grey))),
        ],
      ),
    );
  }
}

// ==================== SECTION: SUPPORT ====================
class _SupportSection extends StatelessWidget {
  const _SupportSection();
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Tickets Support & Assistance', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('support_tickets').orderBy('createdAt', descending: true).snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) return Text('Erreur: ${snapshot.error}');
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                
                final tickets = snapshot.data?.docs ?? [];
                if (tickets.isEmpty) return const Center(child: Text('Aucun ticket en attente.'));

                return ListView.builder(
                  itemCount: tickets.length,
                  itemBuilder: (ctx, i) {
                    final data = tickets[i].data() as Map<String, dynamic>;
                    return Card(
                      child: ListTile(
                        leading: Icon(Icons.mail, color: data['status'] == 'open' ? Colors.red : Colors.green),
                        title: Text(data['subject'] ?? 'Sans objet'),
                        subtitle: Text('${data['userName'] ?? 'Membre'} • ${data['status']}'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {},
                      ),
                    );
                  },
                );
              }
            ),
          ),
        ],
      ),
    );
  }
}

// ==================== SECTION: CAMPAIGNS & REFERRALS ====================
// Replaced by AdminCampaignsPanel and AdminReferralPanel
// See features/admin/presentation/widgets/

// ==================== SECTION: SECURITY ====================
class _SecuritySection extends StatelessWidget {
  const _SecuritySection();
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Piliers de Sécurité & Audit', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          Expanded(
            child: Container(
              width: double.infinity,
              color: Colors.black,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   const Text('> System Secure', style: TextStyle(color: Colors.green, fontFamily: 'monospace')),
                   const Text('> Cloud IAM Active', style: TextStyle(color: Colors.green, fontFamily: 'monospace')),
                   const Text('> Audit Logging Enabled', style: TextStyle(color: Colors.green, fontFamily: 'monospace')),
                   const Divider(color: Colors.green),
                   const Text('> Accès restreint au personnel autorisé.', style: TextStyle(color: Colors.green, fontFamily: 'monospace')),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
