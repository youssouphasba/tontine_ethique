import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tontetic/core/theme/app_theme.dart';
import 'package:tontetic/core/providers/subscription_provider.dart';
import 'package:tontetic/core/providers/plans_provider.dart';
import 'package:tontetic/features/corporate/presentation/screens/employee_invitation_screen.dart';
import 'package:tontetic/features/corporate/presentation/widgets/enterprise_support_widget.dart';
import 'package:tontetic/features/corporate/presentation/screens/enterprise_subscription_screen.dart';
import 'package:tontetic/core/providers/auth_provider.dart';
import 'package:intl/intl.dart';
import 'package:tontetic/core/providers/user_provider.dart';

/// Corporate Dashboard Screen
/// Complete enterprise management dashboard
/// 
/// Features:
/// 1. Overview (KPIs, alerts)
/// 2. Tontine management (list, create, modify)
/// 3. Employee tracking (participants, scores)
/// 4. Reporting & export (PDF/CSV)
/// 5. Notifications & alerts
/// 6. Legal disclaimer (PSP only handles funds)

class CorporateDashboardScreen extends ConsumerStatefulWidget {
  const CorporateDashboardScreen({super.key});

  @override
  ConsumerState<CorporateDashboardScreen> createState() => _CorporateDashboardScreenState();
}

class _CorporateDashboardScreenState extends ConsumerState<CorporateDashboardScreen> {
  int _selectedIndex = 0;

  final List<_NavItem> _navItems = [
    _NavItem(Icons.dashboard, 'Accueil'),
    _NavItem(Icons.group_work, 'Tontines'),
    _NavItem(Icons.people, 'Salariés'),
    _NavItem(Icons.analytics, 'Reporting'),
    _NavItem(Icons.settings, 'Paramètres'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF121212) : AppTheme.offWhite,
      appBar: AppBar(
        title: const Text('Dashboard Entreprise'),
        backgroundColor: Theme.of(context).brightness == Brightness.dark ? Colors.indigo.shade900 : Colors.indigo,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications),
            onPressed: () => _showNotifications(ref),
          ),
          const SizedBox(width: 8),
        ],
      ),
      drawer: _buildDrawer(),
      body: Column(
        children: [
          // Legal Disclaimer Banner
          _buildLegalBanner(),
          // Content
          Expanded(child: _buildContent()),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (i) => setState(() => _selectedIndex = i),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.indigo,
        items: _navItems.map((n) => BottomNavigationBarItem(icon: Icon(n.icon), label: n.label)).toList(),
      ),
    );
  }

  // =============== LEGAL BANNER ===============
  Widget _buildLegalBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Theme.of(context).brightness == Brightness.dark ? Colors.blue.withValues(alpha: 0.2) : Colors.blue.shade50,
      child: Row(
        children: [
          Icon(Icons.info_outline, color: Theme.of(context).brightness == Brightness.dark ? Colors.blue.shade200 : Colors.blue, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Les fonds sont détenus et gérés uniquement par le PSP agréé. Tontetic agit comme prestataire technique.',
              style: TextStyle(fontSize: 11, color: Theme.of(context).brightness == Brightness.dark ? Colors.blue.shade100 : Colors.blue),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    switch (_selectedIndex) {
      case 0: return _buildOverview();
      case 1: return _buildTontineManagement();
      case 2: return _buildEmployeeTracking();
      case 3: return _buildReporting();
      case 4: return _buildSettings();
      default: return _buildOverview();
    }
  }

  // =============== DRAWER ===============
  Widget _buildDrawer() {
    return Drawer(
      child: ListView(
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(color: Colors.indigo),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                const CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.white,
                  child: Icon(Icons.business, color: Colors.indigo, size: 30),
                ),
                const SizedBox(height: 12),
                Text(ref.watch(userProvider).company.isNotEmpty ? ref.watch(userProvider).company : 'Mon Entreprise', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                Text(ref.watch(userProvider).organizationId ?? 'ID: Non défini', style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 12)),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.person_add),
            title: const Text('Inviter des salariés'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const EmployeeInvitationScreen()));
            },
          ),
          ListTile(
            leading: const Icon(Icons.add_circle),
            title: const Text('Nouvelle tontine'),
            onTap: () {
              Navigator.pop(context);
              _showCreateTontineDialog();
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.history),
            title: const Text('Journal d\'audit'),
            onTap: () {
              Navigator.pop(context);
              _showAuditLog();
            },
          ),
          ListTile(
            leading: const Icon(Icons.download),
            title: const Text('Exporter les données'),
            onTap: () {
              Navigator.pop(context);
              _showExportDialog();
            },
          ),
        ],
      ),
    );
  }

  // =============== 1. OVERVIEW ===============
  Widget _buildOverview() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Vue générale', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.indigo)),
          const SizedBox(height: 16),

          // KPIs
          Row(
            children: [
              Expanded(child: _buildKpiCard('Tontines actives', '4', Icons.group_work, Colors.indigo)),
              const SizedBox(width: 12),
              Expanded(child: _buildKpiCard('Salariés', '47', Icons.people, Colors.teal)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildKpiCard('Cotisations/mois', '2.3M FCFA', Icons.trending_up, Colors.green)),
              const SizedBox(width: 12),
              Expanded(child: _buildKpiCard('Score moyen', '92%', Icons.star, Colors.orange)),
            ],
          ),
          const SizedBox(height: 24),

          // Alerts from Firestore
          const Text('Alertes', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),
          Consumer(
            builder: (context, ref, child) {
              final user = ref.watch(userProvider);
              final companyId = user.organizationId;
              
              if (companyId == null || companyId.isEmpty) {
                 return const Text('Aucune entreprise associée.', style: TextStyle(color: Colors.grey));
              }

              return StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('enterprise_alerts').where('enterpriseId', isEqualTo: companyId).limit(3).snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) return Text('Erreur: ${snapshot.error}');
                  if (snapshot.connectionState == ConnectionState.waiting) return const LinearProgressIndicator();

                  final alerts = snapshot.data?.docs ?? [];
                  if (alerts.isEmpty) return const Text('Aucune alerte récente.', style: TextStyle(color: Colors.grey, fontSize: 12));

                  return Column(
                    children: alerts.map((doc) {
                      final a = doc.data() as Map<String, dynamic>;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: _buildAlertCard(
                          a['title'] ?? 'Alerte', 
                          a['message'] ?? '', 
                          a['severity'] == 'high' ? Colors.red : Colors.orange
                        ),
                      );
                    }).toList(),
                  );
                },
              );
            },
          ),
          const SizedBox(height: 24),

          // Quick Actions
          const Text('Actions rapides', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildQuickAction(Icons.person_add, 'Inviter', Colors.indigo, () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const EmployeeInvitationScreen()));
              })),
              Expanded(child: _buildQuickAction(Icons.add_circle, 'Créer tontine', Colors.teal, _showCreateTontineDialog)),
              Expanded(child: _buildQuickAction(Icons.download, 'Exporter', Colors.green, _showExportDialog)),
              Expanded(child: _buildQuickAction(Icons.history, 'Audit', Colors.orange, _showAuditLog)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildKpiCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10)],
        border: Border.all(color: Theme.of(context).brightness == Brightness.dark ? Colors.white12 : Colors.transparent),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
                Text(title, style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertCard(String title, String subtitle, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark ? color.withValues(alpha: 0.2) : color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).brightness == Brightness.dark ? color.withValues(alpha: 0.4) : color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ),
          Icon(Icons.arrow_forward_ios, size: 16, color: color),
        ],
      ),
    );
  }

  Widget _buildQuickAction(IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
              child: Icon(icon, color: color),
            ),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(fontSize: 11)),
          ],
        ),
      ),
    );
  }

  // =============== 2. TONTINE MANAGEMENT ===============
  Widget _buildTontineManagement() {
    final subscription = ref.watch(subscriptionProvider);
    final canCreate = ref.watch(canCreateTontineProvider);
    final user = ref.watch(userProvider);
    
    // Safety check for organizationId
    if (user.organizationId == null) {
      return const Center(child: Text("Erreur: Aucune organisation associée."));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(child: Text('Gestion des Tontines', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.indigo))),
              ElevatedButton.icon(
                onPressed: canCreate ? _showCreateTontineDialog : () => _showLimitReachedDialog('tontines'),
                icon: Icon(canCreate ? Icons.add : Icons.lock, size: 18),
                label: const Text('Nouvelle'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: canCreate ? Colors.indigo : Colors.grey,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Usage bar
          if (subscription != null) _buildUsageBar(
            'Tontines',
            subscription.currentTontines,
            subscription.maxTontines,
            subscription.tontineUsagePercent,
          ),
          const SizedBox(height: 16),

          // Tontine list (Real Data)
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('tontines')
                .where('enterpriseId', isEqualTo: user.organizationId)
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
                return const Center(child: Padding(padding: EdgeInsets.all(32), child: Text('Aucune tontine active.', style: TextStyle(color: Colors.grey))));
              }

              return Column(
                children: docs.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  // Map Firestore data to UI model or use directly
                  return _buildTontineCard(
                    _TontineData(
                      id: doc.id,
                      name: data['name'] ?? 'Nom inconnu',
                      department: data['purpose'] ?? 'Département', // Mapping purpose or desc
                      members: (data['memberIds'] as List?)?.length ?? 0,
                      amount: (data['amountPerPerson'] ?? 0).toString(),
                      status: data['status'] ?? 'active',
                    )
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, bool selected) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) {},
      selectedColor: Colors.indigo.withValues(alpha: Theme.of(context).brightness == Brightness.dark ? 0.3 : 0.2),
      labelStyle: TextStyle(color: selected ? (Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.indigo) : null),
    );
  }

  Widget _buildTontineCard(_TontineData t) {
    final isActive = t.status == 'active';
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isActive ? Colors.indigo.withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.group_work, color: isActive ? Colors.indigo : Colors.grey),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(t.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text(t.department, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isActive ? Colors.green.withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    isActive ? 'Active' : 'Terminée',
                    style: TextStyle(fontSize: 11, color: isActive ? Colors.green : Colors.grey),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildTontineInfo(Icons.people, '${t.members} membres'),
                const SizedBox(width: 24),
                _buildTontineInfo(Icons.payments, '${t.amount} FCFA/mois'),
              ],
            ),
            if (isActive) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✏️ Modification de la tontine...'))),
                      child: const Text('Modifier'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('⚠️ Clôture de la tontine...'))),
                      style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                      child: const Text('Clôturer'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTontineInfo(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 14, color: Colors.grey),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }

  // =============== 3. EMPLOYEE TRACKING ===============
  Widget _buildEmployeeTracking() {
    final subscription = ref.watch(subscriptionProvider);
    final canAdd = ref.watch(canAddEmployeeProvider);
    final user = ref.watch(userProvider);
    
    if (user.organizationId == null) return const SizedBox.shrink();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(child: Text('Suivi des Salariés', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.indigo))),
              ElevatedButton.icon(
                onPressed: canAdd 
                  ? () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EmployeeInvitationScreen()))
                  : () => _showLimitReachedDialog('salariés'),
                icon: Icon(canAdd ? Icons.person_add : Icons.lock, size: 18),
                label: const Text('Inviter'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: canAdd ? Colors.indigo : Colors.grey,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Usage bar
          if (subscription != null) _buildUsageBar(
            'Salariés',
            subscription.currentEmployees,
            subscription.maxEmployees,
            subscription.employeeUsagePercent,
          ),
          const SizedBox(height: 8),
          const Text('Les IBAN et données bancaires ne sont jamais exposés.', style: TextStyle(fontSize: 11, color: Colors.grey)),
          const SizedBox(height: 16),

          // Search
          TextField(
            decoration: InputDecoration(
              hintText: 'Rechercher un salarié...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              filled: true,
              fillColor: Colors.white,
            ),
          ),
          const SizedBox(height: 16),

          // Employee list (Real Data)
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('enterprises')
                .doc(user.organizationId)
                .collection('employees')
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) return Text('Erreur: ${snapshot.error}');
              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

              final docs = snapshot.data?.docs ?? [];
              if (docs.isEmpty) {
                 return const Center(child: Padding(padding: EdgeInsets.all(32), child: Text('Aucun salarié enregistré.', style: TextStyle(color: Colors.grey))));
              }

              return Column(
                children: docs.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  // We might need to fetch user details (name/email) if not fully stored in the link
                  // Ideally, ContextProvider stores email/name in the link doc
                  return _buildEmployeeCard(
                    _EmployeeData(
                      id: doc.id,
                      name: data['name'] ?? data['email'] ?? 'Utilisateur', // Fallback
                      email: data['email'] ?? '',
                      department: data['department'] ?? 'Général',
                      score: (data['trustScore'] ?? 100).toInt(),
                      status: data['status'] ?? 'active',
                    )
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildEmployeeCard(_EmployeeData e) {
    final isActive = e.status == 'active';
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isActive ? Colors.indigo.withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.1),
          child: Text(e.name[0], style: TextStyle(color: isActive ? Colors.indigo : Colors.grey)),
        ),
        title: Text(e.name),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(e.email, style: const TextStyle(fontSize: 12)),
            const SizedBox(height: 4),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(e.department, style: const TextStyle(fontSize: 10)),
                ),
                const SizedBox(width: 8),
                Icon(Icons.star, size: 12, color: _getScoreColor(e.score)),
                Text(' ${e.score}%', style: TextStyle(fontSize: 11, color: _getScoreColor(e.score))),
              ],
            ),
          ],
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: isActive ? Colors.green.withValues(alpha: 0.1) : Colors.orange.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            isActive ? 'Actif' : 'Pause',
            style: TextStyle(fontSize: 10, color: isActive ? Colors.green : Colors.orange),
          ),
        ),
      ),
    );
  }

  Color _getScoreColor(int score) {
    if (score >= 90) return Colors.green;
    if (score >= 70) return Colors.orange;
    return Colors.red;
  }

  // =============== 4. REPORTING ===============
  Widget _buildReporting() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Reporting & Export', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.indigo)),
          const SizedBox(height: 8),
          const Text('Statistiques de participation. Les montants sont affichés à titre informatif uniquement.', style: TextStyle(fontSize: 11, color: Colors.grey)),
          const SizedBox(height: 24),

          // Charts placeholder
          Container(
            height: 200,
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1E1E1E) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Theme.of(context).brightness == Brightness.dark ? Colors.white12 : Colors.grey.shade200),
            ),
            child: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.bar_chart, size: 48, color: Colors.grey),
                  SizedBox(height: 8),
                  Text('Graphique des cotisations', style: TextStyle(color: Colors.grey)),
                  Text('Par cercle / mois', style: TextStyle(fontSize: 11, color: Colors.grey)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Export options
          const Text('Exporter les données', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          _buildExportOption(Icons.picture_as_pdf, 'Export PDF', 'Rapport complet avec graphiques', Colors.red),
          const SizedBox(height: 8),
          _buildExportOption(Icons.table_chart, 'Export CSV', 'Données brutes pour Excel', Colors.green),
          const SizedBox(height: 24),

          // Disclaimer
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Les exports contiennent : statistiques de participation, dates des tours, nombre de cotisations.\n\n« Fonds détenus et gérés exclusivement par le PSP agréé »',
                    style: TextStyle(fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExportOption(IconData icon, String title, String subtitle, Color color) {
    return Card(
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark ? color.withValues(alpha: 0.2) : color.withValues(alpha: 0.1), 
            shape: BoxShape.circle
          ),
          child: Icon(icon, color: Theme.of(context).brightness == Brightness.dark && color is MaterialColor ? color.shade200 : color),
        ),
        title: Text(title),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
        trailing: const Icon(Icons.download),
        onTap: _showExportDialog,
      ),
    );
  }

  // =============== 5. SETTINGS ===============
  Widget _buildSettings() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Paramètres', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.indigo)),
          const SizedBox(height: 16),

          _buildSettingSection('Entreprise', [
            _SettingItem(Icons.business, 'Informations', 'Modifier raison sociale, NIF'),
            _SettingItem(Icons.admin_panel_settings, 'Administrateurs', 'Gérer les accès'),
          ]),
          _buildSettingSection('Notifications', [
            _SettingItem(Icons.email, 'Email', 'Alertes par email'),
            _SettingItem(Icons.notifications, 'Push', 'Notifications mobiles'),
          ]),
          _buildSettingSection('Sécurité', [
            _SettingItem(Icons.history, 'Journal d\'audit', 'Voir toutes les actions'),
            _SettingItem(Icons.security, 'Permissions', 'Rôles et accès'),
          ]),
          _buildSettingSection('Plan', [
            _SettingItem(Icons.credit_card, 'Abonnement', 'Business - 75 000 FCFA/mois'),
            _SettingItem(Icons.upgrade, 'Changer de plan', 'Voir les nouveaux paliers'),
          ], onPlanTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const EnterpriseSubscriptionScreen()),
            );
          }),

          // V17: Support widget for limit adjustments
          const SizedBox(height: 8),
          _buildSupportContact(),
        ],
      ),
    );
  }

  Widget _buildSettingSection(String title, List<_SettingItem> items, {VoidCallback? onPlanTap}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
        const SizedBox(height: 8),
        Card(
          child: Column(
            children: items.map((item) => ListTile(
              leading: Icon(item.icon, color: Colors.indigo),
              title: Text(item.title),
              subtitle: Text(item.subtitle, style: const TextStyle(fontSize: 12)),
              trailing: const Icon(Icons.chevron_right),
              onTap: item.title == 'Changer de plan' ? onPlanTap : () {},
            )).toList(),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  // =============== SUPPORT CONTACT ===============
  Widget _buildSupportContact() {
    final subscription = ref.watch(subscriptionProvider);
    if (subscription == null) return const SizedBox.shrink();

    return EnterpriseSupportWidget(
      companyId: subscription.companyId,
      companyName: ref.watch(userProvider).company.isNotEmpty ? ref.watch(userProvider).company : 'Mon Entreprise', // Dynamic
      requesterId: ref.watch(userProvider).uid, // Dynamic
      currentEmployees: subscription.currentEmployees,
      maxEmployees: subscription.maxEmployees,
      currentTontines: subscription.currentTontines,
      maxTontines: subscription.maxTontines,
    );
  }

  // =============== DIALOGS ===============
  void _showNotifications(WidgetRef ref) {
    final user = ref.read(authStateProvider).value;
    if (user == null) return;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Notifications Entreprise', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const Divider(),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(user.uid)
                    .collection('notifications')
                    .where('type', isEqualTo: 'corporate')
                    .orderBy('timestamp', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) return Text('Erreur: ${snapshot.error}');
                  if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

                  final notes = snapshot.data?.docs ?? [];
                  if (notes.isEmpty) return const Center(child: Text('Aucune notification.', style: TextStyle(color: Colors.grey)));

                  return ListView.builder(
                    itemCount: notes.length,
                    itemBuilder: (ctx, i) {
                      final n = notes[i].data() as Map<String, dynamic>;
                      return ListTile(
                        leading: const Icon(Icons.business, color: Colors.indigo),
                        title: Text(n['title'] ?? 'Note'),
                        subtitle: Text(n['message'] ?? ''),
                        trailing: Text(n['timestamp'] != null ? DateFormat('HH:mm').format((n['timestamp'] as Timestamp).toDate()) : ''),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAuditLog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text('Journal d\'audit', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const Text('Toutes les actions administratives', style: TextStyle(color: Colors.grey, fontSize: 12)),
            const Divider(),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('audit_logs')
                    .where('enterpriseId', isEqualTo: 'techcorp_001')
                    .orderBy('timestamp', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) return Text('Erreur: ${snapshot.error}');
                  if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

                  final logs = snapshot.data?.docs ?? [];
                  if (logs.isEmpty) return const Center(child: Text('Aucun log trouvé.'));

                  return ListView.builder(
                    itemCount: logs.length,
                    itemBuilder: (ctx, i) {
                      final l = logs[i].data() as Map<String, dynamic>;
                      return ListTile(
                        leading: const Icon(Icons.history_edu),
                        title: Text(l['action'] ?? 'Action inconnue'),
                        subtitle: Text('${l['userEmail'] ?? 'Admin'} • ${DateFormat('dd/MM HH:mm').format((l['timestamp'] as Timestamp).toDate())}'),
                        dense: true,
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }



  void _showCreateTontineDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nouvelle Tontine'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(decoration: const InputDecoration(labelText: 'Nom du cercle')),
            const SizedBox(height: 12),
            TextField(decoration: const InputDecoration(labelText: 'Service/Équipe')),
            const SizedBox(height: 12),
            TextField(decoration: const InputDecoration(labelText: 'Montant max autorisé (FCFA)')),
            const SizedBox(height: 12),
            const Text('Note: Vous ne définissez que les paramètres. Les fonds sont gérés par le PSP.', style: TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx), child: const Text('Créer')),
        ],
      ),
    );
  }

  void _showExportDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Exporter'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
              title: const Text('PDF'),
              onTap: () {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Export PDF en cours...')));
              },
            ),
            ListTile(
              leading: const Icon(Icons.table_chart, color: Colors.green),
              title: const Text('CSV'),
              onTap: () {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Export CSV en cours...')));
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAuditItem(String action, String details, String user, String time) {
    return ListTile(
      leading: const Icon(Icons.history, color: Colors.blue, size: 20),
      title: Text(action, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
      subtitle: Text('$user • $details', style: const TextStyle(fontSize: 11)),
      trailing: Text(time, style: const TextStyle(fontSize: 10, color: Colors.grey)),
    );
  }


  // =============== SUBSCRIPTION HELPERS ===============
  Widget _buildUsageBar(String label, int current, int max, double percent) {
    final isUnlimited = max > 9999;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              const Spacer(),
              Text(
                isUnlimited ? '$current / ∞' : '$current / $max',
                style: TextStyle(
                  fontSize: 12,
                  color: percent > 0.9 ? Colors.red : Colors.grey,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: isUnlimited ? 0.1 : percent,
            backgroundColor: Colors.grey.shade200,
            valueColor: AlwaysStoppedAnimation(
              percent > 0.9 ? Colors.red : (percent > 0.7 ? Colors.orange : Colors.green),
            ),
          ),
        ],
      ),
    );
  }

  void _showLimitReachedDialog(String resource) {
    final subscription = ref.read(subscriptionProvider);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.orange),
            const SizedBox(width: 8),
            const Text('Limite atteinte'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Vous avez atteint la limite de $resource pour votre formule actuelle.'),
            const SizedBox(height: 16),
            if (subscription != null) ...[
              Text('Formule actuelle : ${subscription.plan.name}', style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('• Max salariés : ${subscription.maxEmployees}'),
              Text('• Max tontines : ${subscription.maxTontines}'),
            ],
            const SizedBox(height: 16),
            const Text('👉 Passez à une formule supérieure pour augmenter vos limites.', style: TextStyle(color: Colors.indigo)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Fermer')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() => _selectedIndex = 4); // Go to settings
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo),
            child: const Text('Voir les formules'),
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    // PRODUCTION: No demo subscription - all data from Firestore
    // If no subscription exists, user should go through proper enrollment flow
  }
}

// =============== DATA CLASSES ===============
class _NavItem {
  final IconData icon;
  final String label;
  _NavItem(this.icon, this.label);
}

class _TontineData {
  final String id;
  final String name;
  final String department;
  final int members;
  final String amount;
  final String status;

  _TontineData({
    required this.id,
    required this.name,
    required this.department,
    required this.members,
    required this.amount,
    required this.status,
  });
}

class _EmployeeData {
  final String id;
  final String name;
  final String email;
  final String department;
  final int score;
  final String status;

  _EmployeeData({
    required this.id,
    required this.name,
    required this.email,
    required this.department,
    required this.score,
    required this.status,
  });
}

class _SettingItem {
  final IconData icon;
  final String title;
  final String subtitle;
  _SettingItem(this.icon, this.title, this.subtitle);
}
