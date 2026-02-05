import 'package:flutter/material.dart';

import 'package:cloud_firestore/cloud_firestore.dart';

/// Admin Dashboard - Additional Sections
/// Merchants, Enterprises, Payments, Reports, Audit, Settings
/// 
/// CRITICAL: NO FUND ACCESS - Payments section is READ ONLY

// ==================== SECTION 5: MERCHANTS ====================

class AdminMerchantsSection extends StatelessWidget {
  const AdminMerchantsSection({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('shops').orderBy('createdAt', descending: true).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return Text('Erreur: ${snapshot.error}');
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

        final shops = snapshot.data?.docs ?? [];
        final totalShops = shops.length;
        final pendingShops = shops.where((doc) => (doc.data() as Map)['status'] == 'pending').length;
        final activeShops = shops.where((doc) => (doc.data() as Map)['status'] == 'active').length;
        final suspendedShops = shops.where((doc) => (doc.data() as Map)['status'] == 'suspended').length;

        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Gestion des marchands', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
              const SizedBox(height: 24),

              // Stats
              Row(
                children: [
                  _buildStatCard('En attente', '$pendingShops', Colors.orange, Icons.pending),
                  const SizedBox(width: 16),
                  _buildStatCard('Actifs', '$activeShops', Colors.green, Icons.store),
                  const SizedBox(width: 16),
                  _buildStatCard('Suspendus', '$suspendedShops', Colors.red, Icons.block),
                  const SizedBox(width: 16),
                  _buildStatCard('Total Boutiques', '$totalShops', Colors.purple, Icons.inventory),
                ],
              ),
              const SizedBox(height: 24),

              // Merchants list
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: shops.length,
                    itemBuilder: (ctx, i) {
                      final shop = shops[i].data() as Map<String, dynamic>;
                      final shopId = shops[i].id;
                      return _buildMerchantCard(context, shop, shopId);
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      }
    );
  }

  Widget _buildStatCard(String label, String value, Color color, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
                Text(label, style: const TextStyle(color: Colors.grey)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMerchantCard(BuildContext context, Map<String, dynamic> shop, String shopId) {
    final status = shop['status'] ?? 'pending';
    final name = shop['name'] ?? 'Boutique Inconnue';
    final description = shop['description'] ?? '';
    final hasIban = shop['payoutDetails'] != null; // Simplified check

    Color statusColor;
    IconData statusIcon;
    switch(status) {
      case 'active': statusColor = Colors.green; statusIcon = Icons.check_circle; break;
      case 'suspended': statusColor = Colors.red; statusIcon = Icons.block; break;
      default: statusColor = Colors.orange; statusIcon = Icons.pending;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: Colors.deepPurple.shade100,
          backgroundImage: shop['logoUrl'] != null ? NetworkImage(shop['logoUrl']) : null,
          child: shop['logoUrl'] == null ? const Icon(Icons.store, color: Colors.deepPurple) : null,
        ),
        title: Text(name),
        subtitle: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                 mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(statusIcon, size: 12, color: statusColor),
                  const SizedBox(width: 4),
                  Text(status.toUpperCase(), style: TextStyle(fontSize: 10, color: statusColor)),
                ],
              ),
            ),
            const SizedBox(width: 8),
             Icon(hasIban ? Icons.credit_card : Icons.credit_card_off, size: 14, color: hasIban ? Colors.green : Colors.orange),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('ID: $shopId', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                if(description.isNotEmpty) ...[
                   const SizedBox(height: 4),
                   Text(description),
                ],
                const Divider(),
                Row(
                  children: [
                    TextButton.icon(icon: const Icon(Icons.visibility), label: const Text('Voir produits'), onPressed: () {
                      // TODO: Navigate to products with filter
                    }),
                    const Spacer(),
                    if (status == 'pending')
                      ElevatedButton.icon(
                        icon: const Icon(Icons.check),
                        label: const Text('Valider'),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                        onPressed: () {
                          FirebaseFirestore.instance.collection('shops').doc(shopId).update({'status': 'active'});
                        },
                      ),
                    if (status != 'suspended')
                      Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.block, color: Colors.red),
                          label: const Text('Suspendre', style: TextStyle(color: Colors.red)),
                          onPressed: () {
                             FirebaseFirestore.instance.collection('shops').doc(shopId).update({'status': 'suspended'});
                          },
                        ),
                      ),
                    if (status == 'suspended')
                       Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.refresh, color: Colors.green),
                          label: const Text('Réactiver', style: TextStyle(color: Colors.green)),
                          onPressed: () {
                             FirebaseFirestore.instance.collection('shops').doc(shopId).update({'status': 'active'});
                          },
                        ),
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

// ==================== SECTION 6: ENTERPRISES ====================

class AdminEnterprisesSection extends StatelessWidget {
  const AdminEnterprisesSection({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('enterprises').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return Text('Erreur: ${snapshot.error}');
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

        final enterprises = snapshot.data?.docs ?? [];
        final totalCompanies = enterprises.length;
        // Calculating approximate employee count if data available, else 0
        final totalEmployees = enterprises.fold<int>(0, (prev, doc) => prev + ((doc.data() as Map)['employeesCount'] as int? ?? 0));

        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Gestion des entreprises', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
              const SizedBox(height: 24),

              // Stats
              Row(
                children: [
                  _buildStatCard('Entreprises', '$totalCompanies', Colors.indigo),
                  const SizedBox(width: 16),
                  _buildStatCard('Salariés (Total)', '$totalEmployees', Colors.blue),
                  const SizedBox(width: 16),
                  _buildStatCard('Tontines actives', 'N/A', Colors.green), // Difficult to count without extra query
                  const SizedBox(width: 16),
                  _buildStatCard('Revenus', 'Premium', Colors.teal),
                ],
              ),
              const SizedBox(height: 24),

              // Enterprises list
              Expanded(
                child: Container(
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: enterprises.length,
                    itemBuilder: (ctx, i) {
                      final company = enterprises[i].data() as Map<String, dynamic>;
                      return _buildCompanyCard(context, company);
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      }
    );
  }

  Widget _buildCompanyCard(BuildContext context, Map<String, dynamic> company) {
    final name = company['name'] ?? 'Entreprise Inconnue';
    final plan = company['plan'] ?? 'Free';
    final employees = company['employeesCount'] ?? 0;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: Colors.indigo.shade100,
          child: Text(name.isNotEmpty ? name[0] : '?', style: const TextStyle(color: Colors.indigo, fontWeight: FontWeight.bold)),
        ),
        title: Text(name),
        subtitle: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: Colors.indigo.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
              child: Text(plan, style: const TextStyle(fontSize: 10, color: Colors.indigo)),
            ),
            const SizedBox(width: 8),
            Text('$employees salariés'),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Email: ${company['email'] ?? 'N/A'}'),
                    Text('Inscrit le: N/A'),
                  ],
                ),
                const Divider(),
                Row(
                  children: [
                    TextButton.icon(icon: const Icon(Icons.people), label: const Text('Salariés'), onPressed: () => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('👥 Liste des salariés de $name...')))),
                    const Spacer(),
                    OutlinedButton(onPressed: () => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('📦 Changement de formule pour $name...'))), child: const Text('Changer formule')),
                  ],
                ),
              ],
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
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
            Text(label, style: const TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}

// ==================== SECTION 7: PAYMENTS (READ ONLY) ====================

class AdminPaymentsSection extends StatelessWidget {
  const AdminPaymentsSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Paiements & PSP', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
              const SizedBox(width: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.lock, size: 16, color: Colors.grey),
                    SizedBox(width: 4),
                    Text('LECTURE SEULE', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              children: [
                Icon(Icons.warning, color: Colors.red),
                SizedBox(width: 8),
                Text('⚠️ AUCUN ACCÈS AUX FONDS - Toute action de paiement doit se faire directement chez le PSP'),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // PSP Status
          Row(
            children: [
              Expanded(child: _buildPspCard('Stripe', 'Actif', true, '156 webhooks OK', Colors.purple)),
              const SizedBox(width: 16),
              Expanded(child: _buildPspCard('Wave', 'Actif', true, '89 webhooks OK', Colors.blue)),
              const SizedBox(width: 16),
              Expanded(child: _buildPspCard('PayPal', 'Erreur', false, '2 webhooks KO', Colors.amber)),
            ],
          ),
          const SizedBox(height: 24),

          // Error logs
          Expanded(
            child: Container(
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline, color: Colors.red),
                        SizedBox(width: 8),
                        Text('Erreurs de paiement (dernières 24h)', style: TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  const Divider(height: 1),
                  Expanded(
                    child: StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('webhook_logs')
                          .orderBy('timestamp', descending: true)
                          .limit(20)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.hasError) return Text('Erreur: ${snapshot.error}');
                        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

                        final logs = snapshot.data?.docs ?? [];

                        if (logs.isEmpty) {
                          return const Center(child: Text('Aucune erreur récente.', style: TextStyle(color: Colors.grey)));
                        }

                        return ListView.builder(
                          itemCount: logs.length,
                          itemBuilder: (ctx, i) {
                            final log = logs[i].data() as Map<String, dynamic>;
                            final provider = log['provider'] ?? 'Unknown';
                            final eventId = log['eventId'] ?? logs[i].id;
                            final status = log['status'] ?? 'unknown';
                            final time = (log['timestamp'] as Timestamp?)?.toDate().toString().substring(0, 16) ?? 'N/A';
                            final isError = status == 'failed' || status == 'error';

                            return ListTile(
                              leading: Icon(
                                isError ? Icons.close : Icons.check, 
                                color: isError ? Colors.red.shade300 : Colors.green.shade300
                              ),
                              title: Text('${isError ? "Erreur" : "Info"} Webhook'),
                              subtitle: Text('PSP: $provider • Event: $eventId • $time'),
                              trailing: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: (isError ? Colors.red : Colors.green).withValues(alpha: 0.1), 
                                  borderRadius: BorderRadius.circular(4)
                                ),
                                child: Text(status.toUpperCase(), style: TextStyle(fontSize: 10, color: isError ? Colors.red : Colors.green)),
                              ),
                            );
                          },
                        );
                      }
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

  Widget _buildPspCard(String name, String status, bool isOk, String info, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isOk ? Colors.green : Colors.red, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(isOk ? Icons.check_circle : Icons.error, color: isOk ? Colors.green : Colors.red),
              const SizedBox(width: 8),
              Text(name, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
            ],
          ),
          const SizedBox(height: 8),
          Text(status, style: TextStyle(color: isOk ? Colors.green : Colors.red)),
          Text(info, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ),
    );
  }
}

// ==================== SECTION 8: REPORTS & DISPUTES ====================

class AdminReportsSection extends StatelessWidget {
  const AdminReportsSection({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('reports').orderBy('createdAt', descending: true).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return Text('Erreur: ${snapshot.error}');
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

        final reports = snapshot.data?.docs ?? [];
        final openReports = reports.where((doc) => (doc.data() as Map)['status'] == 'open').length;
        final inProgressReports = reports.where((doc) => (doc.data() as Map)['status'] == 'in_progress').length;
        final resolvedReports = reports.where((doc) => (doc.data() as Map)['status'] == 'resolved').length;

        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Signalements & litiges', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
              const SizedBox(height: 24),

              // Stats
              Row(
                children: [
                  _buildStatCard('Ouverts', '$openReports', Colors.red),
                  const SizedBox(width: 16),
                  _buildStatCard('En cours', '$inProgressReports', Colors.orange),
                  const SizedBox(width: 16),
                  _buildStatCard('Résolus', '$resolvedReports', Colors.green),
                  const SizedBox(width: 16),
                  _buildStatCard('Escalade', '0', Colors.purple),
                ],
              ),
              const SizedBox(height: 24),

              // Reports list
              Expanded(
                child: Container(
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: reports.length,
                    itemBuilder: (ctx, i) {
                      final report = reports[i].data() as Map<String, dynamic>;
                      final reportId = reports[i].id;
                      return _buildReportCard(report, reportId);
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      }
    );
  }

  Widget _buildReportCard(Map<String, dynamic> report, String reportId) {
    final type = report['type'] ?? 'Autre';
    final severity = report['severity'] ?? 'low';
    final status = report['status'] ?? 'open';
    final description = report['description'] ?? 'Pas de description';
    final createdAt = (report['createdAt'] as Timestamp?)?.toDate().toString() ?? 'Date inconnue';

    Color severityColor;
    switch(severity) {
      case 'high': severityColor = Colors.red; break;
      case 'medium': severityColor = Colors.orange; break;
      default: severityColor = Colors.blue;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: severity == 'high' ? Colors.red.shade50 : null,
      child: ListTile(
        leading: Icon(
          severity == 'high' ? Icons.error : severity == 'medium' ? Icons.warning : Icons.info,
          color: severityColor,
        ),
        title: Text('Signalement #$reportId'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(description, maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(4)),
                  child: Text(type, style: const TextStyle(fontSize: 10)),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: severityColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(severity.toUpperCase(), style: TextStyle(fontSize: 10, color: severityColor)),
                ),
                const SizedBox(width: 8),
                Text(createdAt, style: const TextStyle(fontSize: 10, color: Colors.grey)),
              ],
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (status != 'resolved')
              ElevatedButton(
                onPressed: () {
                   FirebaseFirestore.instance.collection('reports').doc(reportId).update({'status': 'resolved'});
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                child: const Text('Résoudre', style: TextStyle(color: Colors.white, fontSize: 12)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
        child: Column(
          children: [
            Text(value, style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: color)),
            Text(label, style: const TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}

// ==================== SECTION 9: AUDIT & COMPLIANCE ====================

class AdminAuditSection extends StatelessWidget {
  const AdminAuditSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Audit & Conformité', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('📄 Export juridique ACPR en cours...'))),
                icon: const Icon(Icons.download),
                label: const Text('Export juridique (ACPR)'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Tabs
          Expanded(
            child: DefaultTabController(
              length: 4,
              child: Column(
                children: [
                  const TabBar(
                    labelColor: Colors.brown,
                    tabs: [
                      Tab(text: 'Actions admin'),
                      Tab(text: 'CGU Historique'),
                      Tab(text: 'Consentements'),
                      Tab(text: 'Export'),
                    ],
                  ),
                  Expanded(
                    child: Container(
                      margin: const EdgeInsets.only(top: 16),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                      child: TabBarView(
                        children: [
                          _buildAdminActionsLog(),
                          _buildCguHistory(context),
                          _buildConsentsLog(),
                          _buildExportOptions(context),
                        ],
                      ),
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

  Widget _buildAdminActionsLog() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('admin_audit_logs').orderBy('timestamp', descending: true).limit(50).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return Text('Erreur: ${snapshot.error}');
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

        final logs = snapshot.data?.docs ?? [];

        if (logs.isEmpty) {
           return const Center(child: Text('Aucune action enregistrée.'));
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
              child: const Row(
                children: [
                   Icon(Icons.lock, color: Colors.green),
                  SizedBox(width: 8),
                  Text('Journal immuable - Ces données ne peuvent pas être modifiées', style: TextStyle(color: Colors.green)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            ...logs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final admin = data['adminId'] ?? 'Admin';
              final action = data['action'] ?? 'Action Inconnue';
              final target = data['target'] ?? '';
              final time = (data['timestamp'] as Timestamp?)?.toDate().toString() ?? '';
              
              return ListTile(
                leading: CircleAvatar(child: Text(admin.length > 0 ? admin[0] : 'A')),
                title: Text(action),
                subtitle: Text('$target - $admin'),
                trailing: Text(time, style: const TextStyle(color: Colors.grey, fontSize: 10)),
              );
            }),
          ],
        );
      }
    );
  }

  Widget _buildCguHistory(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ListTile(
          leading: const Icon(Icons.description, color: Colors.blue),
          title: const Text('CGU v3.2'),
          subtitle: const Text('Publiée le 01/01/2026 • 12,458 acceptations'),
          trailing: const Text('Active', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
        ),
        ListTile(
          leading: const Icon(Icons.description, color: Colors.grey),
          title: const Text('CGU v3.1'),
          subtitle: const Text('Publiée le 15/12/2025 • 11,234 acceptations'),
          trailing: TextButton(onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('📄 Affichage CGU v3.1...'))), child: const Text('Voir')),
        ),
        ListTile(
          leading: const Icon(Icons.description, color: Colors.grey),
          title: const Text('CGU v3.0'),
          subtitle: const Text('Publiée le 01/11/2025 • 9,876 acceptations'),
          trailing: TextButton(onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('📄 Affichage CGU v3.0...'))), child: const Text('Voir')),
        ),
      ],
    );
  }

  Widget _buildConsentsLog() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const ListTile(
          title: Text('Consentements CGU', style: TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text('12,458 utilisateurs ont accepté la version actuelle'),
        ),
        const Divider(),
        ...List.generate(5, (i) => ListTile(
          leading: const Icon(Icons.check_circle, color: Colors.green),
          title: Text('Utilisateur ${1000 + i}'),
          subtitle: Text('CGU v3.2 acceptée le 0${i + 1}/01/2026 à 14:${30 + i}'),
        )),
      ],
    );
  }

  Widget _buildExportOptions(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildExportTile(context, 'Export conformité ACPR', 'Format PDF - Contrôle régulateur', Icons.gavel, Colors.teal),
        _buildExportTile(context, 'Export banque partenaire', 'Format CSV - Réconciliation', Icons.account_balance, Colors.blue),
        _buildExportTile(context, 'Export actions admin', 'Format JSON - Audit interne', Icons.history, Colors.brown),
        _buildExportTile(context, 'Export utilisateurs', 'Format CSV - RGPD', Icons.people, Colors.green),
        _buildExportTile(context, 'Export signalements', 'Format PDF - Juridique', Icons.flag, Colors.red),
      ],
    );
  }

  Widget _buildExportTile(BuildContext context, String title, String subtitle, IconData icon, Color color) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, color: color),
        ),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: ElevatedButton.icon(
          onPressed: () => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('⬇️ Téléchargement $title...'))),
          icon: const Icon(Icons.download),
          label: const Text('Télécharger'),
        ),
      ),
    );
  }
}

// ==================== SECTION 10: SETTINGS ====================

class AdminSettingsSection extends StatelessWidget {
  const AdminSettingsSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Paramètres globaux', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),

          Expanded(
            child: Row(
              children: [
                // Left column
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Limites utilisateurs', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        const Divider(),
                        _buildSettingRow('Montant max par cercle', '500,000 FCFA'),
                        _buildSettingRow('Tontines max par utilisateur', '5'),
                        _buildSettingRow('Participants max par cercle', '20'),
                        _buildSettingRow('Score min pour créer un cercle', '70%'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 24),
                // Right column
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Règles marchands', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        const Divider(),
                        _buildSettingRow('Produits max (nouveau)', '10'),
                        _buildSettingRow('Produits max (vérifié)', '100'),
                        _buildSettingRow('Boost max simultanés', '3'),
                        _buildSettingRow('Délai modération', '24h'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Countries
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Pays actifs', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const Divider(),
                Wrap(
                  spacing: 12,
                  children: [
                    _buildCountryChip('🇸🇳 Sénégal', true),
                    _buildCountryChip('🇨🇮 Côte d\'Ivoire', true),
                    _buildCountryChip('🇲🇱 Mali', true),
                    _buildCountryChip('🇧🇫 Burkina Faso', false),
                    _buildCountryChip('🇬🇳 Guinée', false),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildSettingRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(4)),
            child: Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildCountryChip(String label, bool active) {
    return Chip(
      label: Text(label),
      backgroundColor: active ? Colors.green.withValues(alpha: 0.1) : Colors.grey.shade200,
      avatar: Icon(active ? Icons.check_circle : Icons.cancel, size: 16, color: active ? Colors.green : Colors.grey),
    );
  }
}

// ==================== KYC REVIEW SECTION ====================

class AdminKycReviewSection extends StatelessWidget {
  const AdminKycReviewSection({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .where('kycStatus', isEqualTo: 'pending')
          .orderBy('kycLastUpdate', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        // Also get counts for all statuses
        return FutureBuilder<Map<String, int>>(
          future: _getKycStats(),
          builder: (context, statsSnapshot) {
            final stats = statsSnapshot.data ?? {'pending': 0, 'verified': 0, 'rejected': 0};

            if (snapshot.hasError) {
              return Center(child: Text('Erreur: ${snapshot.error}'));
            }
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final pendingUsers = snapshot.data?.docs ?? [];

            return Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Vérification KYC',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Examinez les demandes de vérification d\'identité des utilisateurs',
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 24),

                  // Stats Row
                  Row(
                    children: [
                      _buildStatCard(
                        'En attente',
                        '${pendingUsers.length}',
                        Colors.orange,
                        Icons.pending_actions,
                      ),
                      const SizedBox(width: 16),
                      _buildStatCard(
                        'Vérifiés',
                        '${stats['verified']}',
                        Colors.green,
                        Icons.verified_user,
                      ),
                      const SizedBox(width: 16),
                      _buildStatCard(
                        'Rejetés',
                        '${stats['rejected']}',
                        Colors.red,
                        Icons.cancel,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Pending list
                  Expanded(
                    child: pendingUsers.isEmpty
                        ? _buildEmptyState()
                        : Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: pendingUsers.length,
                              itemBuilder: (ctx, i) {
                                final userData = pendingUsers[i].data() as Map<String, dynamic>;
                                final userId = pendingUsers[i].id;
                                return _buildKycReviewCard(context, userData, userId);
                              },
                            ),
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<Map<String, int>> _getKycStats() async {
    final db = FirebaseFirestore.instance;

    final verifiedCount = await db
        .collection('users')
        .where('kycStatus', isEqualTo: 'verified')
        .count()
        .get();

    final rejectedCount = await db
        .collection('users')
        .where('kycStatus', isEqualTo: 'rejected')
        .count()
        .get();

    return {
      'verified': verifiedCount.count ?? 0,
      'rejected': rejectedCount.count ?? 0,
    };
  }

  Widget _buildStatCard(String label, String value, Color color, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                Text(label, style: const TextStyle(color: Colors.grey)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.verified_user, size: 80, color: Colors.green.shade200),
          const SizedBox(height: 16),
          const Text(
            'Aucune demande en attente',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Toutes les demandes KYC ont été traitées.',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildKycReviewCard(BuildContext context, Map<String, dynamic> userData, String userId) {
    final fullName = userData['fullName'] ?? userData['displayName'] ?? 'Utilisateur';
    final email = userData['email'] ?? 'Non renseigné';
    final phone = userData['phoneNumber'] ?? 'Non renseigné';
    final createdAt = userData['createdAt'] as Timestamp?;
    final kycSubmittedAt = userData['kycLastUpdate'] as Timestamp?;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User Info Header
            Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: Colors.blue.shade100,
                  backgroundImage: userData['photoUrl'] != null
                      ? NetworkImage(userData['photoUrl'])
                      : null,
                  child: userData['photoUrl'] == null
                      ? Text(
                          fullName.isNotEmpty ? fullName[0].toUpperCase() : '?',
                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                        )
                      : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fullName,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      Text(email, style: const TextStyle(color: Colors.grey)),
                      Text(phone, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.orange),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.pending, size: 16, color: Colors.orange),
                      SizedBox(width: 4),
                      Text(
                        'EN ATTENTE',
                        style: TextStyle(
                          color: Colors.orange,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 12),

            // Metadata
            Row(
              children: [
                _buildMetaItem(Icons.calendar_today, 'Inscription', _formatDate(createdAt)),
                const SizedBox(width: 24),
                _buildMetaItem(Icons.upload, 'Demande KYC', _formatDate(kycSubmittedAt)),
                const SizedBox(width: 24),
                _buildMetaItem(Icons.fingerprint, 'ID', userId.substring(0, 8)),
              ],
            ),

            const SizedBox(height: 16),

            // Action Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _showRejectDialog(context, userId, fullName),
                  icon: const Icon(Icons.close, color: Colors.red),
                  label: const Text('Rejeter', style: TextStyle(color: Colors.red)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.red),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: () => _approveKyc(context, userId, fullName),
                  icon: const Icon(Icons.check),
                  label: const Text('Approuver'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetaItem(IconData icon, String label, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: Colors.grey),
        const SizedBox(width: 4),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
            Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
          ],
        ),
      ],
    );
  }

  String _formatDate(Timestamp? timestamp) {
    if (timestamp == null) return 'N/A';
    final date = timestamp.toDate();
    return '${date.day}/${date.month}/${date.year}';
  }

  Future<void> _approveKyc(BuildContext context, String userId, String userName) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'kycStatus': 'verified',
        'kycLastUpdate': FieldValue.serverTimestamp(),
        'kycApprovedAt': FieldValue.serverTimestamp(),
      });

      // Log admin action
      await FirebaseFirestore.instance.collection('admin_audit_logs').add({
        'action': 'KYC_APPROVED',
        'target': userId,
        'targetName': userName,
        'adminId': 'admin', // Should come from auth context in production
        'timestamp': FieldValue.serverTimestamp(),
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('KYC approuvé pour $userName'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showRejectDialog(BuildContext context, String userId, String userName) {
    final reasonController = TextEditingController();
    String? selectedReason;

    final commonReasons = [
      'Document illisible',
      'Document expiré',
      'Document non conforme',
      'Information incomplète',
      'Suspicion de fraude',
      'Autre',
    ];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Rejeter la demande KYC'),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Rejet pour: $userName',
                  style: const TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 16),
                const Text('Raison du rejet:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: commonReasons.map((reason) {
                    final isSelected = selectedReason == reason;
                    return ChoiceChip(
                      label: Text(reason),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() {
                          selectedReason = selected ? reason : null;
                        });
                      },
                      selectedColor: Colors.red.shade100,
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                if (selectedReason == 'Autre')
                  TextField(
                    controller: reasonController,
                    decoration: const InputDecoration(
                      labelText: 'Précisez la raison',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 2,
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: selectedReason == null
                  ? null
                  : () async {
                      final reason = selectedReason == 'Autre'
                          ? reasonController.text
                          : selectedReason!;

                      Navigator.pop(ctx);
                      await _rejectKyc(context, userId, userName, reason);
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Confirmer le rejet'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _rejectKyc(BuildContext context, String userId, String userName, String reason) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'kycStatus': 'rejected',
        'kycLastUpdate': FieldValue.serverTimestamp(),
        'kycRejectionReason': reason,
        'kycRejectedAt': FieldValue.serverTimestamp(),
      });

      // Log admin action
      await FirebaseFirestore.instance.collection('admin_audit_logs').add({
        'action': 'KYC_REJECTED',
        'target': userId,
        'targetName': userName,
        'reason': reason,
        'adminId': 'admin', // Should come from auth context in production
        'timestamp': FieldValue.serverTimestamp(),
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('KYC rejeté pour $userName'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
