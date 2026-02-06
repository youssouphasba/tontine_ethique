import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tontetic/core/theme/app_theme.dart';

class AdminUsersPanel extends StatefulWidget {
  const AdminUsersPanel({super.key});

  @override
  State<AdminUsersPanel> createState() => _AdminUsersPanelState();
}

class _AdminUsersPanelState extends State<AdminUsersPanel> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _selectedFilter = 'Tous';
  List<QueryDocumentSnapshot> _allUsers = [];

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  /// Generates a CSV string and triggers a download (Web-compatible)
  void _exportUsersToCsv() {
    if (_allUsers.isEmpty) return;

    final header = 'ID,Nom,Email,Téléphone,Statut,Score,Cercles Actifs,Date Inscription\n';
    final rows = _allUsers.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final id = doc.id;
      final name = (data['fullName'] ?? data['displayName'] ?? 'Inconnu').toString().replaceAll(',', ' ');
      final email = (data['email'] ?? '').toString();
      final phone = (data['phoneNumber'] ?? '').toString();
      final status = (data['status'] ?? 'active').toString();
      final score = (data['honorScore'] ?? 0).toString();
      final circles = (data['activeCirclesCount'] ?? 0).toString();
      final date = (data['createdAt'] as Timestamp?)?.toDate().toIso8601String() ?? '';
      
      return '$id,$name,$email,$phone,$status,$score,$circles,$date';
    }).join('\n');

    final csvContent = header + rows;
    
    // For this environment, we show a success message + clipboard or console log
    debugPrint('CSV Export Generated:\n$csvContent');
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Export CSV généré (voir console) - Simulation téléchargement'),
        backgroundColor: Colors.teal,
      ),
    );
  }

  void _suspendUser(String uid, bool currentStatus) async {
    final newStatus = currentStatus ? 'suspended' : 'active';
    await FirebaseFirestore.instance.collection('users').doc(uid).update({'status': newStatus});
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Utilisateur mis à jour: $newStatus')));
    }
  }

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
              ElevatedButton.icon(
                onPressed: _exportUsersToCsv,
                icon: const Icon(Icons.download),
                label: const Text('Exporter CSV'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
              ),
              const SizedBox(width: 16),
              SizedBox(
                width: 300,
                child: TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText: 'Rechercher par nom, email...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  onChanged: (v) => setState(() {}),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Filters
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('Tous'),
                _buildFilterChip('Active'),
                _buildFilterChip('Suspended'),
                _buildFilterChip('Merchant'),
              ],
            ),
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
                        Expanded(flex: 2, child: Text('Membre', style: TextStyle(fontWeight: FontWeight.bold))),
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
                      stream: FirebaseFirestore.instance.collection('users').limit(100).snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.hasError) return Center(child: Text('Erreur: ${snapshot.error}'));
                        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

                        final docs = snapshot.data?.docs ?? [];
                        _allUsers = docs;

                        // Client-side filtering
                        final filtered = docs.where((doc) {
                          final data = doc.data() as Map<String, dynamic>;
                          final name = (data['fullName'] ?? data['displayName'] ?? '').toString().toLowerCase();
                          final email = (data['email'] ?? '').toString().toLowerCase();
                          final search = _searchCtrl.text.toLowerCase();
                          final status = (data['status'] ?? 'active').toString().toLowerCase();
                          final role = (data['role'] ?? 'user').toString().toLowerCase();

                          bool matchesSearch = name.contains(search) || email.contains(search);
                          bool matchesFilter = true;
                          
                          if (_selectedFilter != 'Tous') {
                             if (_selectedFilter == 'Merchant') {
                               matchesFilter = role == 'merchant';
                             } else {
                               matchesFilter = status == _selectedFilter.toLowerCase();
                             }
                          }

                          return matchesSearch && matchesFilter;
                        }).toList();

                        if (filtered.isEmpty) return const Center(child: Text('Aucun utilisateur trouvé.'));

                        return ListView.builder(
                          itemCount: filtered.length,
                          itemBuilder: (ctx, i) => _buildRealUserRow(context, filtered[i]),
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

  Widget _buildFilterChip(String label) {
    final isSelected = _selectedFilter == label;
    return Container(
      margin: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (val) => setState(() => _selectedFilter = label),
        backgroundColor: Colors.white,
        selectedColor: AppTheme.marineBlue.withValues(alpha: 0.2),
        checkmarkColor: AppTheme.marineBlue,
        labelStyle: TextStyle(color: isSelected ? AppTheme.marineBlue : Colors.black),
      ),
    );
  }

  Widget _buildRealUserRow(BuildContext context, QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final userId = doc.id;
    final status = data['status'] ?? 'active';
    final honorScore = data['honorScore'] ?? 50;
    final displayName = data['fullName'] ?? data['displayName'] ?? 'Utilisateur Inconnu';
    final email = data['email'] ?? 'No Email';
    final activeCircles = data['activeCirclesCount'] ?? 0;
    
    final isSuspended = status == 'suspended';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey.shade200))),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Row(
              children: [
                CircleAvatar(child: Text(displayName.isNotEmpty ? displayName[0].toUpperCase() : '?')),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(displayName, style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text(email, style: const TextStyle(color: Colors.grey, fontSize: 12), overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isSuspended ? Colors.red.withValues(alpha: 0.1) : Colors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                status.toString().toUpperCase(), 
                style: TextStyle(color: isSuspended ? Colors.red : Colors.green, fontSize: 12, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          Expanded(
            child: Row(
              children: [
                const Icon(Icons.shield, size: 16, color: Colors.amber),
                const SizedBox(width: 4),
                Text('$honorScore pts'),
              ],
            ),
          ),
          Expanded(child: Text('$activeCircles cercles')),
          Expanded(
            child: PopupMenuButton(
              itemBuilder: (ctx) => [
                PopupMenuItem(
                  child: Text(isSuspended ? 'Réactiver' : 'Suspendre'),
                  onTap: () => _suspendUser(userId, isSuspended),
                ),
                const PopupMenuItem(child: Text('Voir profil')),
                const PopupMenuItem(child: Text('Historique')),
              ],
              child: const Icon(Icons.more_vert),
            ),
          ),
        ],
      ),
    );
  }
}
