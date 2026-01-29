import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tontetic/features/advertising/data/moderation_service.dart';
import 'package:tontetic/core/theme/app_theme.dart';

/// Admin Content Moderation Dashboard
/// For reviewing reported content and moderating merchants
/// 
/// Features:
/// - Pending reports queue
/// - Content approval/rejection
/// - Merchant account suspension
/// - Modification history

class ContentModerationDashboard extends ConsumerStatefulWidget {
  const ContentModerationDashboard({super.key});

  @override
  ConsumerState<ContentModerationDashboard> createState() => _ContentModerationDashboardState();
}

class _ContentModerationDashboardState extends ConsumerState<ContentModerationDashboard> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Modération Contenu'),
        backgroundColor: Colors.red.shade700,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(icon: Icon(Icons.pending), text: 'En attente'),
            Tab(icon: Icon(Icons.flag), text: 'Signalements'),
            Tab(icon: Icon(Icons.history), text: 'Historique'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Stats bar
          _buildStatsBar(),
          // Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildPendingTab(),
                _buildReportsTab(),
                _buildHistoryTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsBar() {
    final moderation = ref.watch(moderationProvider);
    final pendingCount = moderation.pendingCases.length;
    final totalCases = moderation.cases.length;
    
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.red.shade50,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem('En attente', '$pendingCount', Colors.orange),
          _buildStatItem('Signalements Total', '$totalCases', Colors.red),
          _buildStatItem('Traités', '${totalCases - pendingCount}', Colors.green),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }

  // ===== PENDING TAB =====
  Widget _buildPendingTab() {
    final moderation = ref.watch(moderationProvider);
    final pendingCases = moderation.pendingCases;

    if (pendingCases.isEmpty) {
      return const Center(child: Text('Aucun contenu en attente de modération.'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: pendingCases.length,
      itemBuilder: (ctx, index) {
        final item = pendingCases[index];
        final isSuspicious = item.primaryTag.isCritical;
        
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          color: isSuspicious ? Colors.red.shade50 : null,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: item.hasCriticalThreshold ? Colors.red : AppTheme.marineBlue,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        item.primaryTag.label, 
                        style: const TextStyle(color: Colors.white, fontSize: 10)
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text(item.contentTitle, style: const TextStyle(fontWeight: FontWeight.bold))),
                    if (isSuspicious)
                      const Icon(Icons.warning, color: Colors.orange, size: 20),
                  ],
                ),
                const SizedBox(height: 8),
                Text('Marchand: ${item.merchantName}', style: const TextStyle(color: Colors.grey)),
                Text('ID: ${item.contentId}', style: const TextStyle(color: Colors.grey, fontSize: 11)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _showRejectDialog(item.contentId, item.contentTitle),
                        icon: const Icon(Icons.close, color: Colors.red),
                        label: const Text('Rejeter', style: TextStyle(color: Colors.red)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          await ref.read(moderationProvider.notifier).restoreContent(item.contentId);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('${item.contentTitle} approuvé'), backgroundColor: Colors.green),
                            );
                          }
                        },
                        icon: const Icon(Icons.check),
                        label: const Text('Approuver'),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ===== REPORTS TAB =====
  Widget _buildReportsTab() {
    final moderation = ref.watch(moderationProvider);
    final reports = moderation.cases.values.expand((c) => c.reports).toList();
    
    if (reports.isEmpty) {
      return const Center(child: Text('Aucun signalement actif.'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: reports.length,
      itemBuilder: (ctx, index) {
        final report = reports[index];
        final moderationCase = moderation.cases[report.contentId];
        
        return _buildReportCard(
          contentId: report.contentId,
          contentType: moderationCase?.contentTitle ?? 'Inconnu',
          violationType: report.tag.label,
          reporterCount: 1,
          description: report.comment,
        );
      },
    );
  }

  Widget _buildReportCard({
    required String contentId,
    required String contentType,
    required String violationType,
    required int reporterCount,
    String? description,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.flag, color: Colors.red),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('$contentType: $contentId', style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text('$reporterCount signalement(s)', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.red.shade100,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(violationType, style: TextStyle(color: Colors.red.shade700, fontSize: 11)),
                ),
              ],
            ),
            if (description != null) ...[
              const SizedBox(height: 8),
              Text('"$description"', style: const TextStyle(fontStyle: FontStyle.italic, color: Colors.grey)),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                TextButton(
                  onPressed: () => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('📄 Affichage du contenu ID: $contentId'))),
                  child: const Text('Voir contenu'),
                ),
                const Spacer(),
                OutlinedButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Signalement ignoré')),
                    );
                  },
                  child: const Text('Ignorer'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () => _showSuspendDialog(contentId),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  child: const Text('Suspendre', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ===== HISTORY TAB =====
  Widget _buildHistoryTab() {
    final moderation = ref.watch(moderationProvider);
    final historyCases = moderation.cases.values.where((c) => c.status == ContentStatus.rejected || c.status == ContentStatus.restored).toList();

    if (historyCases.isEmpty) {
      return const Center(child: Text('Aucun historique de modération.'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: historyCases.length,
      itemBuilder: (ctx, index) {
        final c = historyCases[index];
        final isRejected = c.status == ContentStatus.rejected;
        
        return ListTile(
          leading: Icon(
            isRejected ? Icons.block : Icons.check_circle,
            color: isRejected ? Colors.red : Colors.green,
          ),
          title: Text(isRejected ? 'Contenu rejeté' : 'Contenu restauré'),
          subtitle: Text('${c.contentTitle} - ${c.adminId ?? "Système"}'),
          trailing: Text(
            c.resolvedAt != null ? '${c.resolvedAt!.day}/${c.resolvedAt!.month}' : '-', 
            style: const TextStyle(fontSize: 11, color: Colors.grey)
          ),
        );
      },
    );
  }

  // ===== DIALOGS =====
  void _showRejectDialog(String contentId, String contentName) {
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rejeter ce contenu ?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Contenu: $contentName'),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Raison du rejet',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () async {
              await ref.read(moderationProvider.notifier).rejectContent(contentId, note: reasonController.text);
              if (mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('$contentName rejeté'), backgroundColor: Colors.red),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Rejeter', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showSuspendDialog(String contentId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Suspendre ce contenu ?'),
        content: const Text('Le contenu sera retiré immédiatement. Si associé à un boost, celui-ci ne sera PAS remboursé.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () async {
              await ref.read(moderationProvider.notifier).rejectContent(contentId, note: 'Suspendu suite à signalement');
              if (mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Contenu suspendu'), backgroundColor: Colors.red),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Suspendre', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
