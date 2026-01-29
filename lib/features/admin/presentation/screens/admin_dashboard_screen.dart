import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tontetic/features/admin/data/admin_service.dart';
import 'package:tontetic/core/theme/app_theme.dart';
import 'package:tontetic/features/chat/presentation/screens/support_chat_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SUPER ADMIN 🛡️', style: TextStyle(color: AppTheme.gold, fontWeight: FontWeight.bold)),
        backgroundColor: AppTheme.marineBlue,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: const [
          _OverviewTab(),
          _MessagesTab(), // Nouvel onglet de communication
          _PlansTab(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (idx) => setState(() => _selectedIndex = idx),
        selectedItemColor: AppTheme.marineBlue,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Vue d\'ensemble'),
          BottomNavigationBarItem(icon: Icon(Icons.message), label: 'Messages'),
          BottomNavigationBarItem(icon: Icon(Icons.tune), label: 'Plans & Config'),
        ],
      ),
    );
  }
}

// ... imports


// ... AdminDashboardScreen class stays mostly the same, import Riverpod if needed for children

class _OverviewTab extends ConsumerWidget {
  const _OverviewTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(adminStatsProvider);

    return statsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Erreur stats: $err')),
      data: (stats) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _buildStatCard('Utilisateurs Total', stats.totalUsers.toString(), Colors.blue),
              const SizedBox(height: 12),
              _buildStatCard('Tontines Actives', stats.activeTontines.toString(), Colors.green),
              const SizedBox(height: 12),
              _buildStatCard('Tickets en attente', stats.pendingTickets.toString(), Colors.orange),
              const SizedBox(height: 24),
              
              const Divider(),
              const SizedBox(height: 24),
              
              ElevatedButton.icon(
                icon: const Icon(Icons.mark_email_read),
                label: const Text('Envoyer Newsletter Sociale 📤'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.marineBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                ),
                onPressed: () => _showNewsletterDialog(context, ref),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatCard(String title, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      width: double.infinity,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        border: Border.all(color: color.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(value, style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 4),
          Text(title, style: TextStyle(fontSize: 14, color: color)),
        ],
      ),
    );
  }

  void _showNewsletterDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Newsletter Mensuelle Impact 🌍'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
             Text('Contenu automatiquement généré et envoyé à TOUS les utilisateurs :', style: TextStyle(fontWeight: FontWeight.bold)),
             SizedBox(height: 12),
             Text('Chers membres,\n\nCe mois-ci, la solidarité Tontetic a permis de financer :\n- 🏡 15 Projets Immobiliers\n- 🎓 8 Études Supérieures\n- 💊 4 Urgences Santé\n\nMerci de faire vivre cette finance éthique !'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              // Real Call
              await ref.read(adminServiceProvider).sendGlobalNewsletter(
                'Newsletter Mensuelle Impact', 
                'Chers membres...\n(Contenu complet)'
              );
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Newsletter diffusée globalement ! 🚀')));
              }
            },
            child: const Text('Envoyer'),
          ),
        ],
      ),
    );
  }
}

class _PlansTab extends ConsumerWidget {
  const _PlansTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plansAsync = ref.watch(plansProvider);

    return plansAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Erreur: $err')),
      data: (plans) {
        if (plans.isEmpty) {
          return const Center(child: Text('Aucun plan configuré via Firestore.'));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: plans.length,
          itemBuilder: (context, index) {
            final plan = plans[index];
            final limits = plan['limits'] as Map<String, dynamic>? ?? {};
            
            return Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppTheme.gold,
                  child: Text(plan['code']?.toString().substring(0,1) ?? 'P'),
                ),
                title: Text(plan['name'] ?? 'Plan Inconnu', style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(
                  'Prix: ${_formatPrice(plan['priceCents'])}\n'
                  'Cercles Max: ${limits['maxActiveCircles'] ?? "∞"} | Membres: ${limits['maxMembers'] ?? "∞"}',
                ),
                isThreeLine: true,
                trailing: IconButton(
                  icon: const Icon(Icons.edit, color: AppTheme.marineBlue),
                  onPressed: () => _editPlan(context, ref, plan),
                ),
              ),
            );
          },
        );
      },
    );
  }

  String _formatPrice(dynamic priceCents) {
    if (priceCents == null) return 'Gratuit';
    int price = (priceCents is int) ? priceCents : int.tryParse(priceCents.toString()) ?? 0;
    if (price == 0) return 'Gratuit';
    return '${(price / 100).toStringAsFixed(0)}€ / mois';
  }

  void _editPlan(BuildContext context, WidgetRef ref, Map<String, dynamic> plan) {
    final limits = Map<String, dynamic>.from(plan['limits'] as Map? ?? {});
    final maxCirclesCtrl = TextEditingController(text: limits['maxActiveCircles']?.toString() ?? '1');
    final maxMembersCtrl = TextEditingController(text: limits['maxMembers']?.toString() ?? '10');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Configurer ${plan['name']}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: maxCirclesCtrl,
              decoration: const InputDecoration(labelText: 'Max Cercles Actifs', suffixText: 'cercles'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: maxMembersCtrl,
              decoration: const InputDecoration(labelText: 'Max Membres / Cercle', suffixText: 'membres'),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () {
              // Update Logic
              final updatedLimits = {
                ...limits,
                'maxActiveCircles': int.tryParse(maxCirclesCtrl.text) ?? 1,
                'maxMembers': int.tryParse(maxMembersCtrl.text) ?? 10,
              };
              
              ref.read(adminServiceProvider).updatePlan(plan['id'], {
                'limits': updatedLimits,
                // Add other fields if needed
              });
              
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Plan mis à jour !')));
            },
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
  }
}

final plansProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  return ref.watch(adminServiceProvider).getPlans();
});

class _MessagesTab extends ConsumerWidget {
  const _MessagesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final messagesAsync = ref.watch(supportMessagesProvider);

    return messagesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Erreur chargement messages: $err')),
      data: (messages) {
        if (messages.isEmpty) {
          return const Center(child: Text('Aucun message de support.', style: TextStyle(color: Colors.grey)));
        }
        
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: messages.length,
          itemBuilder: (context, index) {
            final ticket = messages[index];
            final String name = ticket['userName'] ?? 'Utilisateur Inconnu';
            final String msg = ticket['message'] ?? '...';
            // final String time = ticket['createdAt'] != null ? (ticket['createdAt'] as Timestamp).toDate().toString() : 'Récemment'; // Simplify date
            
            return Card(
              elevation: 2,
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                leading: CircleAvatar(backgroundColor: AppTheme.marineBlue, child: Text(name.isNotEmpty ? name.substring(0,1) : '?')),
                title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(msg, maxLines: 2, overflow: TextOverflow.ellipsis),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                   // Open chat detail
                   Navigator.push(context, MaterialPageRoute(builder: (_) => const SupportChatScreen())); 
                },
              ),
            );
          },
        );
      },
    );
  }
}
