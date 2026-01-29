import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tontetic/features/admin/presentation/screens/admin_sections.dart';

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
    _AdminSection(Icons.people, 'Utilisateurs', Colors.green),
    _AdminSection(Icons.donut_large, 'Cercles', Colors.orange),
    _AdminSection(Icons.shield, 'Modération', Colors.red),
    _AdminSection(Icons.store, 'Marchands', Colors.purple),
    _AdminSection(Icons.business, 'Entreprises', Colors.indigo),
    _AdminSection(Icons.payment, 'Paiements (RO)', Colors.teal),
    _AdminSection(Icons.report, 'Signalements', Colors.amber),
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
      case 1: return const _UsersSection();
      case 2: return const _CirclesSection();
      case 3: return const _ModerationSection();
      case 4: return const _MerchantsSection();
      case 5: return const _EnterprisesSection();
      case 6: return const _PaymentsSection();
      case 7: return const _ReportsSection();
      case 8: return const _AuditSection();
      case 9: return const _SettingsSection();
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

class _OverviewSection extends StatelessWidget {
  const _OverviewSection();

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
                onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('🔄 Actualisation des données admin...'))),
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
          Row(
            children: [
              Expanded(child: _buildMetricCard(context, 'Utilisateurs', '12,458', Icons.people, Colors.blue, '+2.3%')),
              const SizedBox(width: 16),
              Expanded(child: _buildMetricCard(context, 'Cercles actifs', '1,234', Icons.donut_large, Colors.green, '+5.1%')),
              const SizedBox(width: 16),
              Expanded(child: _buildMetricCard(context, 'Cercles suspendus', '12', Icons.pause_circle, Colors.orange, '-')),
              const SizedBox(width: 16),
              Expanded(child: _buildMetricCard(context, 'Marchands actifs', '456', Icons.store, Colors.purple, '+8.2%')),
            ],
          ),
          const SizedBox(height: 16),

          // Key metrics row 2
          Row(
            children: [
              Expanded(child: _buildMetricCard(context, 'Flux PSP (total)', '234.5M FCFA', Icons.account_balance, Colors.teal, 'Lecture seule', isReadOnly: true)),
              const SizedBox(width: 16),
              Expanded(child: _buildMetricCard(context, 'Modération en attente', '23', Icons.pending, Colors.red, 'À traiter')),
              const SizedBox(width: 16),
              Expanded(child: _buildMetricCard(context, 'Signalements ouverts', '8', Icons.flag, Colors.amber, '3 urgents')),
              const SizedBox(width: 16),
              Expanded(child: _buildMetricCard(context, 'Alertes conformité', '2', Icons.warning, Colors.red, 'À vérifier')),
            ],
          ),
          const SizedBox(height: 24),

          // Alerts section
          _buildAlertsSection(context),
          const SizedBox(height: 24),

          // Quick actions
          _buildQuickActionsSection(context),
        ],
      ),
    );
  }

  Widget _buildHealthBanner() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [Colors.green.shade600, Colors.green.shade400]),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        children: [
          Icon(Icons.check_circle, color: Colors.white, size: 48),
          SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Plateforme opérationnelle', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                SizedBox(height: 4),
                Text('Tous les services fonctionnent normalement. 2 alertes mineures à traiter.', style: TextStyle(color: Colors.white70)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('Uptime', style: TextStyle(color: Colors.white70)),
              Text('99.98%', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
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

  Widget _buildQuickActionsSection(BuildContext context) {
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
          const Text('Actions rapides', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _buildQuickAction(context, Icons.person_search, 'Rechercher utilisateur', Colors.blue),
              _buildQuickAction(context, Icons.pending_actions, 'Modération en attente', Colors.red),
              _buildQuickAction(context, Icons.storefront, 'Valider marchand', Colors.purple),
              _buildQuickAction(context, Icons.download, 'Export conformité', Colors.teal),
              _buildQuickAction(context, Icons.history, 'Logs audit', Colors.brown),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickAction(BuildContext context, IconData icon, String label, Color color) {
    return ElevatedButton.icon(
      onPressed: () => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('🚀 Action: $label'))),
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withValues(alpha: 0.1),
        foregroundColor: color,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }
}

// ==================== SECTION 2: USERS ====================

class _UsersSection extends StatelessWidget {
  const _UsersSection();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              const Text('Gestion des utilisateurs', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
              const Spacer(),
              SizedBox(
                width: 300,
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Rechercher par nom, email, téléphone...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Filters
          Row(
            children: [
              _buildFilterChip('Tous', true),
              _buildFilterChip('Actifs', false),
              _buildFilterChip('Suspendus', false),
              _buildFilterChip('Restreints', false),
              _buildFilterChip('Marchands', false),
              _buildFilterChip('Salariés', false),
            ],
          ),
          const SizedBox(height: 24),

          // Users table
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
              ),
              child: Column(
                children: [
                  // Table header
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                    ),
                    child: const Row(
                      children: [
                        Expanded(flex: 2, child: Text('Utilisateur', style: TextStyle(fontWeight: FontWeight.bold))),
                        Expanded(child: Text('Statut', style: TextStyle(fontWeight: FontWeight.bold))),
                        Expanded(child: Text('Score', style: TextStyle(fontWeight: FontWeight.bold))),
                        Expanded(child: Text('Cercles', style: TextStyle(fontWeight: FontWeight.bold))),
                        Expanded(child: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))),
                      ],
                    ),
                  ),
                  // Table rows from Firestore
                  Expanded(
                    child: StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance.collection('users').limit(20).snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.hasError) return Center(child: Text('Erreur: ${snapshot.error}'));
                        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

                        final users = snapshot.data?.docs ?? [];
                        if (users.isEmpty) return const Center(child: Text('Aucun utilisateur trouvé.'));

                        return ListView.builder(
                          itemCount: users.length,
                          itemBuilder: (ctx, i) => _buildRealUserRow(context, users[i]),
                        );
                      },
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

  Widget _buildFilterChip(String label, bool selected) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: selected,
        onSelected: (val) {},
      ),
    );
  }

  Widget _buildRealUserRow(BuildContext context, QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final userId = doc.id;
    final status = data['status'] ?? 'Actif';
    final honorScore = data['honorScore'] ?? 50;
    final displayName = data['fullName'] ?? data['displayName'] ?? 'Utilisateur Inconnu';
    final phone = data['phoneNumber'] ?? 'Non renseigné';
    final activeCircles = data['activeCirclesCount'] ?? 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey.shade200))),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Row(
              children: [
                CircleAvatar(child: Text(displayName[0].toUpperCase())),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(displayName, style: const TextStyle(fontWeight: FontWeight.w500)),
                    Text(phone, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: status == 'Actif' ? Colors.green.withValues(alpha: 0.1) : status == 'Suspendu' ? Colors.red.withValues(alpha: 0.1) : Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(status, style: TextStyle(color: status == 'Actif' ? Colors.green : status == 'Suspendu' ? Colors.red : Colors.orange, fontSize: 12)),
            ),
          ),
          Expanded(child: Text('$honorScore%')),
          Expanded(child: Text('$activeCircles')),
          Expanded(
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.visibility, size: 18), 
                  onPressed: () => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('👁️ Détails de l\'utilisateur $displayName'))), 
                  tooltip: 'Voir détails'
                ),
                IconButton(
                  icon: Icon(Icons.block, size: 18, color: status == 'Suspendu' ? Colors.grey : Colors.red), 
                  onPressed: status == 'Suspendu' 
                    ? null 
                    : () => FirebaseFirestore.instance.collection('users').doc(userId).update({'status': 'Suspendu'}), 
                  tooltip: 'Suspendre'
                ),
                IconButton(
                  icon: const Icon(Icons.history, size: 18), 
                  onPressed: () => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('📜 Historique de l\'utilisateur $displayName'))), 
                  tooltip: 'Historique'
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ==================== SECTION 3: CIRCLES ====================

class _CirclesSection extends StatelessWidget {
  const _CirclesSection();

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
          Row(
            children: [
              _buildStatCard('Actifs', '1,234', Colors.green),
              const SizedBox(width: 16),
              _buildStatCard('Incomplets', '56', Colors.orange),
              const SizedBox(width: 16),
              _buildStatCard('Suspendus', '12', Colors.red),
              const SizedBox(width: 16),
              _buildStatCard('Clôturés', '890', Colors.grey),
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
                    TextButton.icon(icon: const Icon(Icons.visibility), label: const Text('Détails'), onPressed: () => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('👁️ Détails du cercle $name')))),
                    TextButton.icon(icon: const Icon(Icons.people), label: const Text('Membres'), onPressed: () => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('👥 Membres du cercle $name')))),
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
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.pending, color: Colors.red, size: 20),
                    SizedBox(width: 8),
                    Text('23 en attente', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                  ],
                ),
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
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 2,
      itemBuilder: (ctx, i) => Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: ListTile(
          leading: const Icon(Icons.block, color: Colors.grey),
          title: Text('Produit suspendu ${i + 1}'),
          subtitle: const Text('Suspendu le 03/01/2026 • Boost non remboursé'),
        ),
      ),
    );
  }

  Widget _buildHistoryList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 10,
      itemBuilder: (ctx, i) => ListTile(
        leading: Icon(i % 2 == 0 ? Icons.check_circle : Icons.cancel, color: i % 2 == 0 ? Colors.green : Colors.red),
        title: Text('Action sur Produit ${i + 1}'),
        subtitle: Text('${i % 2 == 0 ? "Approuvé" : "Rejeté"} par Admin1 • 0${i + 1}/01/2026'),
      ),
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
