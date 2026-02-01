import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:tontetic/core/theme/app_theme.dart';
import 'package:tontetic/core/providers/tontine_provider.dart';
import 'package:tontetic/core/models/tontine_model.dart';

/// Screen to generate QR code invitations for circles
class QRInvitationScreen extends ConsumerStatefulWidget {
  const QRInvitationScreen({super.key});

  @override
  ConsumerState<QRInvitationScreen> createState() => _QRInvitationScreenState();
}

class _QRInvitationScreenState extends ConsumerState<QRInvitationScreen> {
  String? _selectedCircleId;
  String? _selectedCircleName;

  @override
  Widget build(BuildContext context) {
    final circleState = ref.watch(circleProvider);
    final myCircles = circleState.myCircles;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inviter à un cercle'),
        backgroundColor: AppTheme.marineBlue,
        foregroundColor: Colors.white,
      ),
      body: myCircles.isEmpty
          ? _buildEmptyState()
          : _selectedCircleId == null
              ? _buildCirclesList(myCircles)
              : _buildQRCodeView(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.groups_outlined, size: 48, color: Colors.grey),
            ),
            const SizedBox(height: 24),
            const Text(
              'Aucun cercle disponible',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            const Text(
              'Créez ou rejoignez un cercle pour pouvoir inviter d\'autres membres.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCirclesList(List<TontineCircle> circles) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Sélectionnez un cercle',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Choisissez le cercle pour lequel vous souhaitez générer une invitation.',
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: circles.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final circle = circles[index];
              final isFull = circle.isFull;
              
              return Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  leading: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: isFull ? Colors.grey : AppTheme.marineBlue,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.groups, color: Colors.white),
                  ),
                  title: Text(circle.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text('${circle.memberIds.length}/${circle.maxParticipants} membres'),
                      if (isFull)
                        const Text('Cercle complet', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  trailing: isFull
                      ? const Icon(Icons.block, color: Colors.grey)
                      : const Icon(Icons.qr_code, color: AppTheme.gold),
                  enabled: !isFull,
                  onTap: isFull ? null : () {
                    setState(() {
                      _selectedCircleId = circle.id;
                      _selectedCircleName = circle.name;
                    });
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildQRCodeView() {
    final invitationLink = 'https://tontetic-app.web.app/join-circle?id=$_selectedCircleId';
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => setState(() {
                _selectedCircleId = null;
                _selectedCircleName = null;
              }),
              icon: const Icon(Icons.arrow_back),
              label: const Text('Changer de cercle'),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _selectedCircleName ?? 'Cercle',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text('Montrez ce QR code pour inviter', style: TextStyle(color: Colors.grey.shade600)),
          const SizedBox(height: 32),
          
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: AppTheme.marineBlue.withValues(alpha: 0.2), blurRadius: 20, offset: const Offset(0, 10))],
            ),
            child: Column(
              children: [
                QrImageView(
                  data: invitationLink,
                  version: QrVersions.auto,
                  size: 220,
                  backgroundColor: Colors.white,
                  eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: AppTheme.marineBlue),
                  dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: AppTheme.marineBlue),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.verified_user, color: Colors.green, size: 16),
                    const SizedBox(width: 4),
                    Text('Invitation sécurisée', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                Share.share(
                  '🌟 Rejoins mon cercle de tontine "$_selectedCircleName" sur Tontetic !\n\n'
                  '📲 Clique ici pour nous rejoindre : $invitationLink\n\n'
                  '💰 Ensemble, construisons notre épargne solidaire !',
                  subject: 'Invitation Tontetic - $_selectedCircleName',
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.gold,
                foregroundColor: AppTheme.marineBlue,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.share),
              label: const Text('Partager l\'invitation', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 12),
          
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: invitationLink));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('✓ Lien d\'invitation copié !'), backgroundColor: Colors.green),
                );
              },
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.copy),
              label: const Text('Copier le lien'),
            ),
          ),
          const SizedBox(height: 24),
          
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(12)),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: Colors.blue),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'La personne invitée devra scanner ce code ou cliquer sur le lien pour rejoindre votre cercle.',
                    style: TextStyle(color: Colors.blue.shade700, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
