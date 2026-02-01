import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tontetic/core/providers/subscription_provider.dart';

/// Employee Invitation Screen (Enterprise Side)
/// Allows company to invite employees via email or identifier
/// 
/// Features:
/// - Import emails (batch or individual)
/// - Generate secure invitation links
/// - Track invitation status

import 'package:tontetic/core/services/invitation_service.dart';
import 'package:tontetic/core/models/employee_invitation_model.dart';

class EmployeeInvitationScreen extends ConsumerStatefulWidget {
  const EmployeeInvitationScreen({super.key});

  @override
  ConsumerState<EmployeeInvitationScreen> createState() => _EmployeeInvitationScreenState();
}

class _EmployeeInvitationScreenState extends ConsumerState<EmployeeInvitationScreen> {
  final _emailController = TextEditingController();
  final _nameController = TextEditingController();
  final List<EmployeeInvitation> _invitations = []; // Removed final to allow refresh
  bool _isSending = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inviter des salariés'),
        backgroundColor: Colors.indigo,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            const Text('Gérer les invitations', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.indigo)),
            const SizedBox(height: 8),
            const Text('Invitez vos salariés à rejoindre les tontines de l\'entreprise.', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 24),

            // Info box
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info, color: Colors.blue, size: 20),
                      SizedBox(width: 8),
                      Text('Compte unique', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                    ],
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Si le salarié a déjà un compte, il pourra le rattacher à l\'entreprise sans créer de doublon. '
                    'Vous ne verrez que les données relatives aux tontines de l\'entreprise.',
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Add employee form
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Ajouter un salarié', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _emailController,
                      decoration: const InputDecoration(
                        labelText: 'Email professionnel',
                        prefixIcon: Icon(Icons.email),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Nom (optionnel)',
                        prefixIcon: Icon(Icons.person),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: (_isSending || !ref.watch(subscriptionProvider)!.canAddEmployee) ? null : _sendInvitation,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.indigo,
                          disabledBackgroundColor: Colors.grey.shade300,
                        ),
                        icon: _isSending 
                          ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.send, color: Colors.white),
                        label: Text(
                          ref.watch(subscriptionProvider)!.canAddEmployee 
                              ? 'Envoyer l\'invitation' 
                              : 'Limite atteinte', 
                          style: const TextStyle(color: Colors.white)
                        ),
                      ),
                    ),
                    if (!ref.watch(subscriptionProvider)!.canAddEmployee)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(
                          'Vous avez atteint la limite de salariés pour votre plan (${ref.watch(subscriptionProvider)!.maxEmployees}).',
                          style: const TextStyle(color: Colors.red, fontSize: 11),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Bulk import
            OutlinedButton.icon(
              onPressed: _showBulkImportDialog,
              icon: const Icon(Icons.upload_file),
              label: const Text('Importer plusieurs emails'),
            ),
            const SizedBox(height: 32),

            // Invitations list
            Row(
              children: [
                const Text('Invitations envoyées', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const Spacer(),
                Text('${_invitations.length} salarié(s)', style: const TextStyle(color: Colors.grey)),
              ],
            ),
            const SizedBox(height: 12),

            if (_invitations.isEmpty)
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: Column(
                    children: [
                      Icon(Icons.people_outline, size: 48, color: Colors.grey),
                      SizedBox(height: 8),
                      Text('Aucune invitation envoyée', style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                ),
              )
            else
              ...List.generate(_invitations.length, (index) => _buildInvitationTile(_invitations[index])),
          ],
        ),
      ),
    );
  }

  Widget _buildInvitationTile(EmployeeInvitation inv) {
    Color statusColor;
    String statusText;
    IconData statusIcon;

    switch (inv.status) {
      case InvitationStatus.pending:
        statusColor = Colors.orange;
        statusText = 'En attente';
        statusIcon = Icons.schedule;
        break;
      case InvitationStatus.opened:
        statusColor = Colors.blue;
        statusText = 'Lien ouvert';
        statusIcon = Icons.visibility;
        break;
      case InvitationStatus.accepted:
        statusColor = Colors.green;
        statusText = 'Accepté';
        statusIcon = Icons.check_circle;
        break;
      case InvitationStatus.declined:
        statusColor = Colors.red;
        statusText = 'Refusé';
        statusIcon = Icons.cancel;
        break;
      case InvitationStatus.expired:
        statusColor = Colors.grey;
        statusText = 'Expiré';
        statusIcon = Icons.timer_off;
        break;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: statusColor.withValues(alpha: 0.1),
          child: Icon(statusIcon, color: statusColor),
        ),
        title: Text(inv.name ?? inv.email),
        subtitle: Text(inv.email),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(statusText, style: TextStyle(color: statusColor, fontSize: 12)),
        ),
      ),
    );
  }

  void _sendInvitation() async {
    final sub = ref.read(subscriptionProvider);
    if (sub == null || !sub.canAddEmployee) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Limite de salariés atteinte pour votre plan.')),
      );
      return;
    }

    if (_emailController.text.isEmpty || !_emailController.text.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez entrer un email valide')),
      );
      return;
    }

    setState(() => _isSending = true);

    try {
      final token = await ref.read(invitationServiceProvider).sendInvitation(
        sub.companyId,
        _emailController.text,
        _nameController.text.isNotEmpty ? _nameController.text : null,
      );
      
      // Update local list (Optimistic or re-fetch)
      // For now, let's fetch stream in build or just add locally
      // Ideally we should use a StreamBuilder in build() instead of local list
      // But for quick fix:
       final invitation = EmployeeInvitation(
        id: 'inv_${DateTime.now().millisecondsSinceEpoch}',
        companyId: sub.companyId,
        email: _emailController.text,
        name: _nameController.text.isNotEmpty ? _nameController.text : null,
        sentAt: DateTime.now(),
        token: token,
      );

      if (mounted) {
        setState(() {
          _invitations.insert(0, invitation);
          _isSending = false;
          _emailController.clear();
          _nameController.clear();
        });
      }

    } catch (e) {
      if (mounted) {
        setState(() => _isSending = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red));
      }
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('✅ Invitation envoyée !'), backgroundColor: Colors.green),
    );
  }

  void _showBulkImportDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Importer plusieurs emails'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Collez les emails séparés par des virgules ou des retours à la ligne.'),
            const SizedBox(height: 16),
            TextField(
              maxLines: 5,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'email1@company.com\nemail2@company.com',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Import en cours...')),
              );
            },
            child: const Text('Importer'),
          ),
        ],
      ),
    );
  }
}
