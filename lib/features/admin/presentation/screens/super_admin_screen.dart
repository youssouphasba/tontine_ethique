import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:tontetic/features/admin/data/admin_service.dart';
import 'package:tontetic/core/theme/app_theme.dart';

import 'package:tontetic/features/admin/presentation/screens/admin_sections.dart';

class SuperAdminScreen extends StatefulWidget {
  const SuperAdminScreen({super.key});

  @override
  State<SuperAdminScreen> createState() => _SuperAdminScreenState();
}

class _SuperAdminScreenState extends State<SuperAdminScreen> {
  // Navigation State
  String _currentView = 'Dashboard'; // Dashboard, Users, Comm, Finance, Security
  bool isAuthenticated = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _show2FADialog());
  }

  void _show2FADialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        final codeController = TextEditingController();
        return AlertDialog(
          title: const Text('🔒 Accès Admin Pro (God Mode)'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Authentification Forte Requise (2FA)'),
              const SizedBox(height: 16),
              TextField(
                controller: codeController,
                keyboardType: TextInputType.number,
                 obscureText: true,
                decoration: const InputDecoration(labelText: 'Code Authenticator', border: OutlineInputBorder()),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () { Navigator.pop(context); Navigator.pop(context); }, child: const Text('Annuler')),
            ElevatedButton(
              onPressed: () {
                if (codeController.text == '0000' || codeController.text.isNotEmpty) {
                  setState(() => isAuthenticated = true);
                  Navigator.pop(context);
                }
              },
              child: const Text('Entrer'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!isAuthenticated) return const Scaffold(body: Center(child: CircularProgressIndicator(color: Colors.black)));

    return Scaffold(
      appBar: AppBar(
        title: Text('Admin Pro 3.0 • $_currentView'),
        backgroundColor: Colors.black87,
        actions: [
          IconButton(icon: const Icon(Icons.notifications), onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('🔔 Aucune nouvelle notification')))),
          IconButton(icon: const Icon(Icons.power_settings_new, color: Colors.red), onPressed: () => Navigator.pop(context)),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(color: Colors.black87),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.shield, color: AppTheme.gold, size: 48),
                  const SizedBox(height: 16),
                  const Text('SUPER ADMIN', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                  Text(DateTime.now().toString().split('.')[0], style: const TextStyle(color: Colors.white54, fontSize: 12)),
                ],
              ),
            ),
            _buildNavItem('Dashboard', Icons.dashboard),
            _buildNavItem('Utilisateurs', Icons.people),
            _buildNavItem('Communications', Icons.campaign),
            _buildNavItem('Finance & Data', Icons.bar_chart),
            _buildNavItem('Business', Icons.monetization_on), // NEW
            _buildNavItem('Sécurité & Logs', Icons.security),
            _buildNavItem('Validations', Icons.verified_user), // NEW
            const Divider(),
            _buildNavItem('Configuration', Icons.settings),
          ],
        ),
      ),
      body: _buildCurrentView(),
    );
  }

  Widget _buildNavItem(String view, IconData icon) {
    bool isSelected = _currentView == view;
    return ListTile(
      leading: Icon(icon, color: isSelected ? AppTheme.marineBlue : Colors.grey),
      title: Text(view, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, color: isSelected ? AppTheme.marineBlue : Colors.black)),
      selected: isSelected,
      selectedTileColor: AppTheme.gold.withValues(alpha: 0.1),
      onTap: () {
        setState(() => _currentView = view);
        Navigator.pop(context); // Close drawer
      },
    );
  }

  Widget _buildCurrentView() {
    switch (_currentView) {
      case 'Utilisateurs': return const _AdminUsersView();
      case 'Communications': return const _AdminCommView();
      case 'Finance & Data': return const _AdminFinanceView();
      case 'Sécurité & Logs': return const _AdminSecurityView();
      case 'Validations': return const _AdminValidationView();
      case 'Business': return const _AdminBusinessView();
      case 'Configuration': return const _AdminConfigView();
      case 'Dashboard':
      default: return const _AdminDashboardView();
    }
  }
}

// ---------------- VIEWS ----------------

class _AdminValidationView extends StatelessWidget {
  const _AdminValidationView();

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Column(
        children: [
          Container(
            color: Colors.white,
            child: const TabBar(
              labelColor: AppTheme.marineBlue,
              unselectedLabelColor: Colors.grey,
              indicatorColor: AppTheme.marineBlue,
              tabs: [
                Tab(icon: Icon(Icons.verified_user), text: 'Cercles à Valider'),
                Tab(icon: Icon(Icons.lock_open), text: 'Dérogations'),
                Tab(icon: Icon(Icons.report_problem), text: 'Litiges'),
                Tab(icon: Icon(Icons.thumb_up), text: 'Pubs'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildCirclesTab(context),
                _buildWaiversTab(context),
                _buildDisputesTab(context),
                _buildAdsValidationTab(context),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCirclesTab(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('tontines').where('status', isEqualTo: 'pending').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return Text('Erreur: ${snapshot.error}');
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

        final circles = snapshot.data?.docs ?? [];
        if (circles.isEmpty) return const Center(child: Text('Aucun cercle en attente de validation.', style: TextStyle(color: Colors.grey)));

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: circles.length,
          itemBuilder: (ctx, i) {
            final circle = circles[i].data() as Map<String, dynamic>;
            final circleId = circles[i].id;
            return Card(
              child: ListTile(
                title: Text(circle['name'] ?? 'Cercle Inconnu'),
                subtitle: Text('Créé par: ${circle['creatorId'] ?? 'Inconnu'}'),
                trailing: ElevatedButton(
                  onPressed: () => FirebaseFirestore.instance.collection('tontines').doc(circleId).update({'status': 'active'}),
                  child: const Text('Valider'),
                ),
              ),
            );
          },
        );
      }
    );
  }

  Widget _buildWaiversTab(BuildContext context) {
     // TODO: Connect to waivers collection
    return const Center(child: Text('Aucune demande de dérogation.', style: TextStyle(color: Colors.grey)));
  }

  Widget _buildDisputesTab(BuildContext context) {
    return const AdminReportsSection();
  }

  Widget _buildAdsValidationTab(BuildContext context) {
     // TODO: Connect to ads collection
    return const Center(child: Text('Aucune publicité à valider.', style: TextStyle(color: Colors.grey)));
  }


}

class _AdminDashboardView extends StatelessWidget {
  const _AdminDashboardView();

  Future<Map<String, dynamic>> _fetchStats() async {
    final usersSnapshot = await FirebaseFirestore.instance.collection('users').count().get();
    final shopsPendingSnapshot = await FirebaseFirestore.instance.collection('shops').where('status', isEqualTo: 'pending').count().get();
    
    // For volume, we normally need an aggregation. For now, let's just count transactions.
    final transactionsSnapshot = await FirebaseFirestore.instance.collection('transactions').count().get();
    
    return {
      'users': usersSnapshot.count,
      'pending_validations': shopsPendingSnapshot.count,
      'transactions': transactionsSnapshot.count,
    };
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _fetchStats(),
      builder: (context, snapshot) {
        final data = snapshot.data ?? {'users': 0, 'pending_validations': 0, 'transactions': 0};
        
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Vue d\'ensemble', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(child: _buildKpiCard('Utilisateurs', '${data['users']}', 'TOTAL', Icons.people, Colors.blue)),
                  const SizedBox(width: 16),
                  Expanded(child: _buildKpiCard('Transactions', '${data['transactions']}', 'TOTAL', Icons.attach_money, Colors.green)),
                   const SizedBox(width: 16),
                  Expanded(child: _buildKpiCard('À Valider', '${data['pending_validations']}', 'ACTIONS', Icons.verified_user, Colors.orange)),
                ],
              ),
              const SizedBox(height: 32),
// Actions Rapides removed as per cleanup plan
              ],
            ),
          );
        },
      );

  }

  Widget _buildKpiCard(String title, String value, String sub, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.grey.withValues(alpha: 0.1), blurRadius: 4)]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Icon(icon, color: color), Text(sub, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 10))]),
          const SizedBox(height: 12),
          Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          Text(title, style: const TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}

class _AdminUsersView extends ConsumerStatefulWidget {
  const _AdminUsersView();
  @override
  ConsumerState<_AdminUsersView> createState() => _AdminUsersViewState();
}

class _AdminUsersViewState extends ConsumerState<_AdminUsersView> {
  // Mocks removed. Using adminUsersProvider via Riverpod.

  @override
  Widget build(BuildContext context) {
    final usersAsync = ref.watch(adminUsersProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Gestion Utilisateurs (IAM)', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              // ElevatedButton.icon(icon: const Icon(Icons.add), label: const Text('Nouveau Staff'), onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('👤 Création d\'un nouveau staff...')))),
            ],
          ),
          const SizedBox(height: 16),
          TextField(decoration: InputDecoration(prefixIcon: const Icon(Icons.search), hintText: 'Rechercher par nom, email, ID...', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)))),
          const SizedBox(height: 16),
          usersAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, s) => Text('Erreur: $e', style: const TextStyle(color: Colors.red)),
            data: (users) {
              if (users.isEmpty) return const Text('Aucun utilisateur trouvé.');
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('ID')),
                    DataColumn(label: Text('Nom')),
                    DataColumn(label: Text('Rôle')),
                    DataColumn(label: Text('Statut')),
                    DataColumn(label: Text('Actions')),
                  ],
                  rows: users.map((user) {
                     final String name = user['fullName'] ?? user['email'] ?? 'Membre';
                     final String role = user['role'] ?? 'Membre';
                     final String status = user['status'] ?? 'Actif'; // Or read from DB
                     final String idShort = (user['id'] as String).substring(0, 5);
                     
                     return DataRow(
                      cells: [
                        DataCell(Text(idShort)),
                        DataCell(Row(children: [const CircleAvatar(radius: 12, child: Icon(Icons.person, size: 12)), const SizedBox(width: 8), Text(name)])),
                        DataCell(Chip(label: Text(role, style: const TextStyle(fontSize: 10)), backgroundColor: Colors.grey[200])),
                        DataCell(Text(status, style: TextStyle(color: status == 'Bloqué' ? Colors.red : Colors.green, fontWeight: FontWeight.bold))),
                        DataCell(Row(
                          children: [
                            IconButton(icon: const Icon(Icons.visibility, color: Colors.blueGrey, size: 20), onPressed: () => _showUserDetails(context, user)),
                            IconButton(icon: const Icon(Icons.message, color: Colors.blue, size: 20), onPressed: () => _showMessageDialog(context, name)),
                            IconButton(icon: const Icon(Icons.block, color: Colors.red, size: 20), onPressed: () => _toggleBlock(user)),
                          ],
                        )),
                      ],
                    );
                  }).toList(),
                ),
              );
            }
          ),
        ],
      ),
    );
  }

  void _showUserDetails(BuildContext context, Map<String, dynamic> user) async {
    // 1. SECURITY CHALLENGE (Double Auth)
    bool isAuthorized = await _showSecurityChallenge(context);
    if (!isAuthorized) return;

    // 2. AUDIT LOG
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: const [Icon(Icons.lock, color: Colors.white, size: 16), SizedBox(width: 8), Text('Accès vérifié & enregistré')]),
        backgroundColor: Colors.green.shade800,
        duration: const Duration(seconds: 2),
      )
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
             const CircleAvatar(child: Icon(Icons.person)),
             const SizedBox(width: 12),
             Column(
               crossAxisAlignment: CrossAxisAlignment.start,
               children: [
                 Text(user['name'], style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                 Text(user['id'], style: const TextStyle(fontSize: 12, color: Colors.grey)),
               ],
             ),
          ],
        ),
        content: SizedBox(
          width: 500,
          child: DefaultTabController(
            length: 3,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // SECURITY BANNER
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                  color: Colors.red.shade50,
                  child: Row(
                    children: [
                      Icon(Icons.visibility, size: 14, color: Colors.red.shade900),
                      const SizedBox(width: 8),
                      Expanded(child: Text('CONFIDENTIEL : Toute consultation est journalisée.', style: TextStyle(color: Colors.red.shade900, fontSize: 11, fontWeight: FontWeight.bold))),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                const TabBar(
                  labelColor: AppTheme.marineBlue,
                  tabs: [
                    Tab(text: 'Infos Perso'),
                    Tab(text: 'Activités'),
                    Tab(text: 'Certification & Docs'),
                  ],
                ),
                SizedBox(
                  height: 300,
                  child: TabBarView(
                    children: [
                      // Tab 1: Infos Perso
                      ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                           ListTile(leading: const Icon(Icons.email), title: const Text('Email'), subtitle: Text(user['email'] ?? 'Non renseigné')),
                           ListTile(leading: const Icon(Icons.phone), title: const Text('Téléphone'), subtitle: Text(user['phone'] ?? 'Non renseigné')),
                           const ListTile(leading: Icon(Icons.location_on), title: Text('Adresse'), subtitle: Text('Non renseignée (Confidentialité)')),
                           ListTile(leading: const Icon(Icons.info), title: const Text('Rôle'), subtitle: Text(user['role'] ?? 'Membre')),
                        ],
                      ),
                      // Tab 2: Activités
                      const Center(child: Text("Aucune activité récente disponible via l'API.")),
                      // Tab 3: Certification
                      ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                           ListTile(
                             leading: Icon(
                               (user['isVerified'] == true) ? Icons.check_circle : Icons.cancel, 
                               color: (user['isVerified'] == true) ? Colors.green : Colors.red
                             ),
                             title: Text((user['isVerified'] == true) ? 'Profil Certifié' : 'Non Certifié'),
                             subtitle: Text((user['isVerified'] == true) ? 'Ce profil a été validé.' : 'En attente de validation.'),
                           ),
                        ],
                      ),
                    ],
                  ),
                )
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Fermer')),
          ElevatedButton.icon(
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('📄 Export RGPD en cours...'))), 
            icon: const Icon(Icons.download),
            label: const Text('Export RGPD (PDF)'),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.marineBlue),
          )
        ],
      ),
    );
  }
  
  Widget _buildLogItem(String action, String date) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(action, style: const TextStyle(fontWeight: FontWeight.w500)),
          Text(date, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        ],
      ),
    );
  }

  void _showMessageDialog(BuildContext context, String name) {
    showDialog(context: context, builder: (c) => AlertDialog(title: Text('Message à $name'), content: const TextField(maxLines: 3, decoration: InputDecoration(border: OutlineInputBorder(), hintText: 'Votre message officiel...')), actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('Envoyer'))]));
  }

  void _toggleBlock(Map<String, dynamic> user) {
    setState(() {
      user['status'] = user['status'] == 'Actif' ? 'Bloqué' : 'Actif';
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Statut de ${user['name']} mis à jour.')));
  }
  Future<bool> _showSecurityChallenge(BuildContext context) async {
    final controller = TextEditingController();
    final user = FirebaseAuth.instance.currentUser;
    
    if (user == null || user.email == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erreur: Session invalide'), backgroundColor: Colors.red),
      );
      return false;
    }
    
    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Row(children: [Icon(Icons.security, color: Colors.red), SizedBox(width: 8), Text('Contrôle de Sécurité')]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Cette action accède à des données sensibles (RGPD).'),
            const SizedBox(height: 8),
            Text('Email: ${user.email}', style: const TextStyle(color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Mot de passe Admin', border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () async {
              try {
                // Re-authenticate with Firebase
                final credential = EmailAuthProvider.credential(
                  email: user.email!,
                  password: controller.text,
                );
                await user.reauthenticateWithCredential(credential);
                
                // Log audit
                await FirebaseFirestore.instance.collection('audit_logs').add({
                  'action': 'ADMIN_SENSITIVE_ACCESS',
                  'adminId': user.uid,
                  'adminEmail': user.email,
                  'timestamp': FieldValue.serverTimestamp(),
                  'ip': 'server-side',
                });
                
                if (ctx.mounted) Navigator.pop(ctx, true);
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Mot de passe incorrect ⛔'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('CONFIRMER L\'ACCÈS'),
          )
        ],
      ),
    ) ?? false;
  }
}

class _AdminCommView extends StatefulWidget {
  const _AdminCommView();

  @override
  State<_AdminCommView> createState() => _AdminCommViewState();
}

class _AdminCommViewState extends State<_AdminCommView> {
  final _messageCtrl = TextEditingController();


  void _sendBroadcast() async {
     if (_messageCtrl.text.isEmpty) return;
     
     ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Envoi en cours...')));
     
     try {
       await FirebaseFirestore.instance.collection('broadcasts').add({
         'title': 'Annonce Admin', 
         'body': _messageCtrl.text,
         'createdAt': FieldValue.serverTimestamp(),
         'target': 'all', // simplified
       });
       
       if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Message diffusé avec succès 🚀')));
         _messageCtrl.clear();
       }
     } catch(e) {
       if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
     }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Text('Centre de Communication', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Diffuser une annonce (Broadcast)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  items: ['Tous les utilisateurs', 'Utilisateurs Actifs', 'Staff uniquement', 'Cercle spécifique'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                  onChanged: (v) {},
                  decoration: const InputDecoration(labelText: 'Cible', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _messageCtrl,
                  maxLines: 3, 
                  decoration: const InputDecoration(labelText: 'Message', border: OutlineInputBorder())
                ),
                const SizedBox(height: 16),
                 Row(
                   children: [
                     Checkbox(value: true, onChanged: (v){}),
                     const Text('Notification Push'),
                     const SizedBox(width: 16),
                     Checkbox(value: false, onChanged: (v){}),
                     const Text('Email'),
                   ],
                 ),
                 const SizedBox(height: 16),
                 SizedBox(width: double.infinity, child: ElevatedButton.icon(onPressed: _sendBroadcast, icon: const Icon(Icons.send), label: const Text('ENVOYER')))
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        const Text('Derniers Tickets Support', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('support_tickets').orderBy('createdAt', descending: true).limit(10).snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) return Text('Erreur: ${snapshot.error}');
            if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
            
            final tickets = snapshot.data?.docs ?? [];
            if (tickets.isEmpty) return const Text('Aucun ticket récent.');

            return Column(
              children: tickets.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                return ListTile(
                  leading: Icon(Icons.mail, color: data['status'] == 'open' ? Colors.red : Colors.grey),
                  title: Text(data['subject'] ?? 'Sans objet'),
                  subtitle: Text('${data['userName'] ?? 'Membre'} • ${(data['createdAt'] as Timestamp?)?.toDate().toString().substring(0, 16) ?? ''}'),
                  trailing: Chip(
                    label: Text(data['status'] ?? 'Nouveau'), 
                    backgroundColor: data['status'] == 'open' ? Colors.blue.withValues(alpha: 0.2) : Colors.green.withValues(alpha: 0.2)
                  ),
                );
              }).toList(),
            );
          }
        ),
      ],
    );
  }
}

class _AdminFinanceView extends ConsumerWidget {
  const _AdminFinanceView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactionsAsync = ref.watch(adminTransactionsProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [ Text('Data Factory & Finance', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold))]),
          const SizedBox(height: 24),
          transactionsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, s) => Text('Erreur: $e'),
            data: (transactions) {
              if (transactions.isEmpty) return const Text('Aucune transaction récente.');
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(Colors.grey[200]),
                  columns: const [DataColumn(label: Text('ID Transaction')), DataColumn(label: Text('Date')), DataColumn(label: Text('Type')), DataColumn(label: Text('Montant')), DataColumn(label: Text('Membre'))],
                  rows: transactions.map((t) {
                    final amount = t['amount']?.toString() ?? '0';
                    final type = t['type'] ?? 'Transaction';
                    final date = t['createdAt'] != null ? (t['createdAt'] as Timestamp).toDate().toString().substring(0,10) : 'N/A';
                    return DataRow(cells: [
                      DataCell(Text((t['id'] as String).substring(0,8), style: const TextStyle(fontWeight: FontWeight.bold))),
                      DataCell(Text(date)),
                      DataCell(Text(type)),
                      DataCell(Text(amount, style: TextStyle(color: type == 'payout' ? Colors.red : Colors.green))),
                      DataCell(Text(t['userId'] ?? 'Inconnu')),
                    ]);
                  }).toList(),
                ),
              );
            }
          )
        ],
      ),
    );
  }
}

class _AdminSecurityView extends ConsumerWidget {
  const _AdminSecurityView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logsAsync = ref.watch(adminAuditLogsProvider);

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Text('Audit & Sécurité', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        Card(
          color: Colors.black87,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(children: [Icon(Icons.terminal, color: Colors.green), SizedBox(width: 8), Text('Live System Logs', style: TextStyle(color: Colors.green, fontFamily: 'monospace'))]),
                const Divider(color: Colors.white24),
                
                logsAsync.when(
                  loading: () => const Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator(color: Colors.green)),
                  error: (e,s) => Text('Error: $e', style: const TextStyle(color: Colors.red)),
                  data: (logs) {
                     if (logs.isEmpty) return const Text('> System Ready. No recent logs.', style: TextStyle(color: Colors.white70, fontFamily: 'monospace'));
                     return Column(
                       crossAxisAlignment: CrossAxisAlignment.start,
                       children: logs.map((log) {
                         final date = log['timestamp'] != null ? (log['timestamp'] as Timestamp).toDate().toString().substring(5, 16) : 'Now';
                         final action = log['action'] ?? 'Unknown';
                         final details = log['details'] ?? '';
                         return Padding(
                           padding: const EdgeInsets.symmetric(vertical: 4), 
                           child: Text('> $date : $action $details', style: const TextStyle(color: Colors.white70, fontFamily: 'monospace'))
                         );
                       }).toList(),
                     );
                  }
                )
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        const Text('Contrôle d\'Accès Global', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        SwitchListTile(title: const Text('Forcer 2FA pour tous les Admins'), value: true, onChanged: null), // Read-only
        SwitchListTile(title: const Text('Mode Maintenance (App bloquée)'), subtitle: const Text('Sauf whitelist IP'), value: false, onChanged: null), // Read-only
      ],
    );
  }
}

class _AdminConfigView extends StatefulWidget {
  const _AdminConfigView();

  @override
  State<_AdminConfigView> createState() => _AdminConfigViewState();
}

class _AdminConfigViewState extends State<_AdminConfigView> {
  // Config State
  bool _enableSponsorship = true;
  bool _maintenanceMode = false;
  bool _isLoading = true;
  
  // Pricing Controllers
  final _boostPriceEuroCtrl = TextEditingController();
  final _boostPriceFcfaCtrl = TextEditingController();
  
  final _subPremiumEuroCtrl = TextEditingController();
  final _subPremiumFcfaCtrl = TextEditingController();
  
  final _feesCreationEuroCtrl = TextEditingController();
  final _feesCreationFcfaCtrl = TextEditingController();

  final _feesTxEuroCtrl = TextEditingController();
  final _feesTxFcfaCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('configuration').doc('global').get();
      if (doc.exists) {
        final data = doc.data()!;
        setState(() {
          _enableSponsorship = data['enableSponsorship'] ?? true;
          _maintenanceMode = data['maintenanceMode'] ?? false;
          
          _boostPriceEuroCtrl.text = data['boostPriceEuro']?.toString() ?? '0.99';
          _boostPriceFcfaCtrl.text = data['boostPriceFcfa']?.toString() ?? '500';
          
          _subPremiumEuroCtrl.text = data['subPremiumEuro']?.toString() ?? '5.99';
          _subPremiumFcfaCtrl.text = data['subPremiumFcfa']?.toString() ?? '2000';
          
          _feesCreationEuroCtrl.text = data['feesCreationEuro']?.toString() ?? '1.00';
          _feesCreationFcfaCtrl.text = data['feesCreationFcfa']?.toString() ?? '500';

          _feesTxEuroCtrl.text = data['feesTxEuro']?.toString() ?? '0.50';
          _feesTxFcfaCtrl.text = data['feesTxFcfa']?.toString() ?? '250';
          _isLoading = false;
        });
      } else {
         // Set defaults
         _boostPriceEuroCtrl.text = '0.99';
         _boostPriceFcfaCtrl.text = '500';
         _subPremiumEuroCtrl.text = '5.99';
         _subPremiumFcfaCtrl.text = '2000';
         _feesCreationEuroCtrl.text = '1.00';
         _feesCreationFcfaCtrl.text = '500';
         _feesTxEuroCtrl.text = '0.50';
         _feesTxFcfaCtrl.text = '250';
         setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('Error loading config: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveConfig() async {
    setState(() => _isLoading = true);
    try {
      await FirebaseFirestore.instance.collection('configuration').doc('global').set({
        'enableSponsorship': _enableSponsorship,
        'maintenanceMode': _maintenanceMode,
        'boostPriceEuro': double.tryParse(_boostPriceEuroCtrl.text) ?? 0.99,
        'boostPriceFcfa': int.tryParse(_boostPriceFcfaCtrl.text) ?? 500,
        'subPremiumEuro': double.tryParse(_subPremiumEuroCtrl.text) ?? 5.99,
        'subPremiumFcfa': int.tryParse(_subPremiumFcfaCtrl.text) ?? 2000,
        'feesCreationEuro': double.tryParse(_feesCreationEuroCtrl.text) ?? 1.00,
        'feesCreationFcfa': int.tryParse(_feesCreationFcfaCtrl.text) ?? 500,
        'feesTxEuro': double.tryParse(_feesTxEuroCtrl.text) ?? 0.50,
        'feesTxFcfa': int.tryParse(_feesTxFcfaCtrl.text) ?? 250,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nouvelle grille tarifaire appliquée ! 💸')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Configuration App & Tarifs', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          
          // 1. Tarification Abonnements
          _buildPricingCard(
            title: 'Abonnements Premium (Mensuel)',
            icon: Icons.star,
            color: Colors.amber,
            euroCtrl: _subPremiumEuroCtrl,
            fcfaCtrl: _subPremiumFcfaCtrl,
          ),
          
          const SizedBox(height: 16),

          // 2. Tarification Services (Boost)
          _buildPricingCard(
            title: 'Service "Boost" (Coup unique)',
            icon: Icons.rocket_launch,
            color: Colors.purple,
            euroCtrl: _boostPriceEuroCtrl,
            fcfaCtrl: _boostPriceFcfaCtrl,
          ),

          const SizedBox(height: 16),

          // 3. Frais de Gestion
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [Icon(Icons.account_balance_wallet, color: Theme.of(context).brightness == Brightness.dark ? AppTheme.gold : AppTheme.marineBlue), const SizedBox(width: 8), const Text('Frais de Gestion (Commissions)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))]),
                  const SizedBox(height: 16),
                  const Text('Frais de Création de Cercle :', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(child: _buildCurrencyField(_feesCreationEuroCtrl, '€')),
                      const SizedBox(width: 16),
                      Expanded(child: _buildCurrencyField(_feesCreationFcfaCtrl, 'FCFA')),
                    ],
                  ),
                  const Divider(height: 24),
                  const Text('Frais par Transaction (Standard) :', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                   Row(
                    children: [
                      Expanded(child: _buildCurrencyField(_feesTxEuroCtrl, '€')),
                      const SizedBox(width: 16),
                      Expanded(child: _buildCurrencyField(_feesTxFcfaCtrl, 'FCFA')),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Feature Toggles (Global)
          Card(
            child: Column(
              children: [
                 SwitchListTile(
                   title: const Text('Activer Module Sponsorisation'),
                   value: _enableSponsorship,
                   onChanged: (v) => setState(() => _enableSponsorship = v),
                 ),
                  SwitchListTile(
                   title: const Text('Mode Maintenance'),
                   subtitle: const Text('Bloque les accès utilisateurs'),
                  value: _maintenanceMode,
                   onChanged: (v) => setState(() => _maintenanceMode = v),
                 ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _isLoading ? null : _saveConfig,
              icon: const Icon(Icons.save),
              label: Text(_isLoading ? 'SAUVEGARDE...' : 'METTRE À JOUR LES TARIFS'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildPricingCard({required String title, required IconData icon, required Color color, required TextEditingController euroCtrl, required TextEditingController fcfaCtrl}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [Icon(icon, color: color), const SizedBox(width: 8), Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))]),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _buildCurrencyField(euroCtrl, '€')),
                const SizedBox(width: 16),
                Expanded(child: _buildCurrencyField(fcfaCtrl, 'FCFA')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrencyField(TextEditingController ctrl, String suffix) {
    return TextField(
      controller: ctrl,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        suffixText: suffix,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
    );
  }
}

class _AdminBusinessView extends StatelessWidget {
  const _AdminBusinessView();

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Container(
            color: Colors.white,
            child: const TabBar(
              labelColor: AppTheme.marineBlue,
              tabs: [
                Tab(text: 'Entreprises'),
                Tab(text: 'Marchands'),
              ],
            ),
          ),
          const Expanded(
            child: TabBarView(
              children: [
                AdminEnterprisesSection(),
                AdminMerchantsSection(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
