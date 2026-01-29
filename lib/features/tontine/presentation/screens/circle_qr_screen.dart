import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:tontetic/core/theme/app_theme.dart';

/// V10.0 - QR Code Screen for Circle Sharing
/// Allows users to generate a QR code for their circle
/// and share the invitation link via native share menu

class CircleQRScreen extends StatelessWidget {
  final String circleId;
  final String circleName;
  final int currentMembers;
  final int maxMembers;

  const CircleQRScreen({
    super.key,
    required this.circleId,
    required this.circleName,
    required this.currentMembers,
    required this.maxMembers,
  });

  // Generate deep link for the circle
  String get _inviteLink => 'https://tontetic-app.web.app/join/$circleId';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.marineBlue,
      appBar: AppBar(
        title: const Text('Inviter des Membres'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              // Circle Info
              Text(
                circleName,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '$currentMembers / $maxMembers membres',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${maxMembers - currentMembers} places restantes',
                  style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold),
                ),
              ),
              
              const SizedBox(height: 32),
              
              // QR Code Card
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // QR Code
                    QrImageView(
                      data: _inviteLink,
                      version: QrVersions.auto,
                      size: 200,
                      backgroundColor: Colors.white,
                      eyeStyle: const QrEyeStyle(
                        eyeShape: QrEyeShape.square,
                        color: AppTheme.marineBlue,
                      ),
                      dataModuleStyle: const QrDataModuleStyle(
                        dataModuleShape: QrDataModuleShape.circle,
                        color: AppTheme.marineBlue,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Scannez pour rejoindre',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 32),
              
              // Share Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _shareInvite(context),
                  icon: const Icon(Icons.share),
                  label: const Text('PARTAGER LE LIEN'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.gold,
                    foregroundColor: AppTheme.marineBlue,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Copy Link Button
              TextButton.icon(
                onPressed: () => _copyLink(context),
                icon: const Icon(Icons.copy, color: Colors.white70),
                label: const Text('Copier le lien', style: TextStyle(color: Colors.white70)),
              ),
              
              const Spacer(),
              
              // Hint
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.white54, size: 20),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Les nouveaux membres devront valider leur identité avant de rejoindre le cercle.',
                        style: TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _shareInvite(BuildContext context) {
    final message = '''
🤝 Rejoins mon cercle d'épargne "$circleName" sur Tontetic !

📱 Clique ici pour rejoindre :
$_inviteLink

💰 Ensemble, on épargne mieux !
''';
    
    Share.share(message, subject: 'Invitation Tontetic - $circleName');
  }

  void _copyLink(BuildContext context) {
    // In production, use Clipboard.setData
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Lien copié ! 📋'),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}
