import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tontetic/features/advertising/data/moderation_service.dart';

/// V11.2 - Admin Moderation Panel
/// Shows pending cases for Super Admin review
class ModerationPanelScreen extends ConsumerWidget {
  const ModerationPanelScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final moderation = ref.watch(moderationProvider);
    final pendingCases = moderation.pendingCases;

    return Scaffold(
      appBar: AppBar(
        title: const Text('🛡️ Modération'),
        backgroundColor: Colors.red.shade800,
        foregroundColor: Colors.white,
      ),
      body: pendingCases.isEmpty
          ? _buildEmptyState()
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: pendingCases.length,
              itemBuilder: (context, index) => _buildCaseCard(context, ref, pendingCases[index]),
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.verified_user, size: 80, color: Colors.green.shade300),
          const SizedBox(height: 16),
          const Text(
            'Aucun contenu en attente',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Tous les signalements ont été traités.',
            style: TextStyle(color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildCaseCard(BuildContext context, WidgetRef ref, ModerationCase moderationCase) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.warning, size: 14, color: Colors.orange.shade800),
                      const SizedBox(width: 4),
                      Text(
                        '${moderationCase.reportCount} signalements',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange.shade800,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Text(
                  '#${moderationCase.contentId.substring(0, 8)}',
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // Content Info
            Text(
              moderationCase.contentTitle,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.store, size: 14, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text(
                  moderationCase.merchantName,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // Primary Reason
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.report, color: Colors.red.shade700, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Motif principal :', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
                        Text(
                          moderationCase.primaryTag.label,
                          style: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 12),
            
            // Suspended Info
            if (moderationCase.suspendedAt != null)
              Text(
                'Suspendu le ${_formatDate(moderationCase.suspendedAt!)}',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
              ),
            
            const SizedBox(height: 16),
            
            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showWarningMessage(context, ref, moderationCase.contentId),
                    icon: const Icon(Icons.visibility, size: 18),
                    label: const Text('Voir Message'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.grey.shade700,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _restoreContent(context, ref, moderationCase.contentId),
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('Réhabiliter'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _rejectContent(context, ref, moderationCase.contentId),
                    icon: const Icon(Icons.delete, size: 18),
                    label: const Text('Supprimer'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} à ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  void _showWarningMessage(BuildContext context, WidgetRef ref, String contentId) {
    final message = ref.read(moderationProvider.notifier).generateWarningMessage(contentId);
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('📧 Message Envoyé au Marchand'),
        content: SingleChildScrollView(
          child: Text(message, style: const TextStyle(fontSize: 13, height: 1.5)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  void _restoreContent(BuildContext context, WidgetRef ref, String contentId) {
    ref.read(moderationProvider.notifier).restoreContent(contentId);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('✅ Contenu réhabilité. Score d\'Honneur restauré.'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _rejectContent(BuildContext context, WidgetRef ref, String contentId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmer la suppression'),
        content: const Text('Cette action est définitive. Le contenu sera supprimé et le marchand notifié.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(moderationProvider.notifier).rejectContent(contentId);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('🗑️ Contenu supprimé définitivement.'),
                  backgroundColor: Colors.red,
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Supprimer', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
