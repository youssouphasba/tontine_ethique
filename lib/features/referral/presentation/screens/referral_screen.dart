import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tontetic/core/theme/app_theme.dart';
import 'package:tontetic/features/referral/data/referral_service.dart';

class ReferralScreen extends StatelessWidget {
  const ReferralScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final String referralCode = ReferralService.generateReferralCode();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Parrainage & Bonus'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            // Illustration Or
            Container(
              height: 150,
              width: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.gold.withValues(alpha: 0.1),
                border: Border.all(color: AppTheme.gold, width: 2),
              ),
              child: const Icon(
                Icons.card_giftcard,
                size: 80,
                color: AppTheme.gold,
              ),
            ),
            const SizedBox(height: 32),
            
            Text(
              'Invitez vos proches',
              style: Theme.of(context).textTheme.displayLarge?.copyWith(fontSize: 28),
            ),
            const SizedBox(height: 12),
            const Text(
              'Invitez vos amis et choisissez votre récompense.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 24),
            _buildRewardSelector(),
            const SizedBox(height: 24),

            // Code Parrainage Card
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.marineBlue,
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [
                  BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 5))
                ],
              ),
              child: Column(
                children: [
                  const Text(
                    'VOTRE CODE UNIQUE',
                    style: TextStyle(color: Colors.white54, letterSpacing: 1.5, fontSize: 12),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        referralCode,
                        style: const TextStyle(
                          color: AppTheme.gold,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(width: 16),
                      IconButton(
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: referralCode));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Code copié !')),
                          );
                        },
                        icon: const Icon(Icons.copy, color: Colors.white),
                        tooltip: 'Copier',
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Bouton Partage
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  // Simulation Share
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Ouverture du partage WhatsApp...')),
                  );
                },
                icon: const Icon(Icons.share),
                label: const Text('Partager mon lien'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.gold,
                  foregroundColor: AppTheme.marineBlue,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
            const SizedBox(height: 48),

            // Historique
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Historique de parrainage',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            const SizedBox(height: 16),
            // History would be fetched dynamically
            Center(child: Text("Aucun historique pour le moment", style: TextStyle(color: Colors.grey))),
          ],
        ),
      ),
    );
  }

  /*
  Widget _buildHistoryItem(String name, String date, String bonus) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: AppTheme.marineBlue.withValues(alpha: 0.1),
            child: Text(name[0], style: const TextStyle(color: AppTheme.marineBlue)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(date, style: const TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.gold.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(bonus, style: const TextStyle(color: Color(0xFF8F7624), fontWeight: FontWeight.bold, fontSize: 12)),
          ),
        ],
      ),
    );
  }
  */
  Widget _buildRewardSelector() {
    return Container(
       padding: const EdgeInsets.all(16),
       decoration: BoxDecoration(
         color: Colors.white,
         borderRadius: BorderRadius.circular(16),
         border: Border.all(color: Colors.grey.shade200),
       ),
       child: Column(
         crossAxisAlignment: CrossAxisAlignment.start,
         children: [
           const Text('MODE DE RÉCOMPENSE', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
           const SizedBox(height: 12),
           _buildRewardOption('Bonus Premier Pot', '5 000 FCFA offerts au démarrage', true),
           const Divider(),
           _buildRewardOption('3 Mois Sans Frais', 'Économisez sur les frais de gestion', false),
           const Divider(),
           _buildRewardOption('Cash Wallet', 'Crédit direct pour chaque filleul', false),
         ],
       ),
    );
  }

  Widget _buildRewardOption(String title, String subtitle, bool isSelected) {
    return Row(
      children: [
        // ignore: deprecated_member_use
        Radio(value: isSelected, groupValue: true, onChanged: (v) {}, activeColor: AppTheme.marineBlue),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
              Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ),
        ),
      ],
    );
  }
}
