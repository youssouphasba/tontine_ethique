import 'package:flutter/material.dart';
// import 'package:flutter/services.dart'; - UNNECESSARY
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:tontetic/core/services/launch_promotion_service.dart';

/// V17: Widget d'offre de lancement - Modèle Créateurs + Invitations
/// 20 premiers créateurs + 9 invitations chacun = 200 utilisateurs max

class LaunchPromoInviteWidget extends ConsumerStatefulWidget {
  final String userId;
  final String userName;

  const LaunchPromoInviteWidget({
    super.key,
    required this.userId,
    required this.userName,
  });

  @override
  ConsumerState<LaunchPromoInviteWidget> createState() => _LaunchPromoInviteWidgetState();
}

class _LaunchPromoInviteWidgetState extends ConsumerState<LaunchPromoInviteWidget> {
  LaunchPromoUser? _userPromo;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPromo();
  }

  Future<void> _loadPromo() async {
    final service = ref.read(launchPromotionServiceProvider);
    final promo = await service.getUserPromo(widget.userId);
    setState(() {
      _userPromo = promo;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const SizedBox.shrink();
    }

    // Ne rien afficher si pas de promo active
    if (_userPromo == null || !_userPromo!.isPromoActive) {
      return const SizedBox.shrink();
    }

    final daysRemaining = _userPromo!.daysRemaining;
    final isCreator = _userPromo!.type == PromoType.creator;
    final remainingInvites = _userPromo!.remainingInvites;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.amber.shade600,
            Colors.orange.shade700,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isCreator ? Icons.star : Icons.card_giftcard,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isCreator 
                        ? '🎉 Offre Créateur Active !'
                        : '🎁 Offre Invité Active !',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '$daysRemaining jours restants',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Message
          Text(
            isCreator
              ? 'Vous faites partie des 20 premiers créateurs de tontine ! '
                'Invitez jusqu\'à 9 personnes pour leur offrir 3 mois Starter gratuits.'
              : 'Vous avez été invité(e) par un créateur Tontetic ! '
                'Profitez de 3 mois d\'abonnement Starter GRATUIT.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.95),
              fontSize: 14,
            ),
          ),

          const SizedBox(height: 16),

          // Avantages Starter
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildAdvantage('✓ 2 tontines simultanées'),
                const SizedBox(height: 6),
                _buildAdvantage('✓ 10 participants par tontine'),
                const SizedBox(height: 6),
                _buildAdvantage('✓ Support chat prioritaire'),
              ],
            ),
          ),

          // Compteur d'invitations (créateurs uniquement)
          if (isCreator) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Invitations restantes',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 14,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '$remainingInvites / 9',
                      style: TextStyle(
                        color: Colors.orange.shade700,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Bouton partager
            if (remainingInvites > 0)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _shareInviteLink,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.orange.shade700,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.share),
                  label: const Text(
                    'Partager mon lien d\'invitation',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              )
            else
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  '✅ Toutes vos invitations sont envoyées',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
          ],

          const SizedBox(height: 12),

          // Info après promo
          Text(
            'Après 3 mois : ${LaunchPromotionService.priceAfterEuro}€/mois pour continuer avec Starter',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 12,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdvantage(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 13,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  void _shareInviteLink() {
    final inviteCode = 'TONTETIC_${widget.userId.substring(0, 6).toUpperCase()}';
    final link = 'https://tontetic.io/join?ref=$inviteCode';
    
    final message = '''
🎉 ${widget.userName} t'offre 3 mois d'abonnement Starter GRATUIT sur Tontetic !

Tontetic, c'est l'app qui digitalise les tontines en toute sécurité.

📲 Télécharge l'app et utilise ce code :
$inviteCode

Ou clique ici : $link

Offre limitée aux 200 premiers utilisateurs !
''';

    Share.share(message, subject: 'Invitation Tontetic - 3 mois offerts');
  }
}

/// Badge à afficher sur le profil - V17 créateurs/invités
class LaunchPromoBadge extends StatelessWidget {
  final PromoType type;

  const LaunchPromoBadge({super.key, required this.type});

  @override
  Widget build(BuildContext context) {
    final isCreator = type == PromoType.creator;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isCreator
              ? [Colors.amber.shade600, Colors.orange.shade700]
              : [Colors.teal.shade400, Colors.teal.shade600],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isCreator ? Icons.star : Icons.verified,
            color: Colors.white,
            size: 14,
          ),
          const SizedBox(width: 4),
          Text(
            isCreator ? 'Early Creator' : 'Early Member',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

/// Bannière d'offre pour les non-inscrits - V17
class LaunchPromoOfferBanner extends ConsumerWidget {
  const LaunchPromoOfferBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<int>(
      future: ref.read(launchPromotionServiceProvider).getRemainingCreatorSlots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data == 0) {
          return const SizedBox.shrink();
        }

        final remaining = snapshot.data!;

        return Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.amber.shade600, Colors.orange.shade700],
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text('🚀', style: TextStyle(fontSize: 24)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Offre de Lancement !',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Plus que $remaining places créateur',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '3 mois\nGRATUIT',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.orange.shade700,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Dialog d'avertissement avant annulation
class CancellationBlockedDialog extends StatelessWidget {
  final String reason;

  const CancellationBlockedDialog({super.key, required this.reason});

  static Future<void> show(BuildContext context, String reason) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => CancellationBlockedDialog(reason: reason),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.lock, color: Colors.red.shade600),
          ),
          const SizedBox(width: 12),
          const Text('Annulation Impossible'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            reason,
            style: const TextStyle(fontSize: 15),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.grey.shade600, size: 20),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Cette restriction protège les autres membres de votre tontine.',
                    style: TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('J\'ai compris'),
        ),
      ],
    );
  }
}

/// Widget pour les utilisateurs INVITÉS - Affiche leur statut d'offre
/// NB: Les invités ne voient pas la bannière "Offre de Lancement" 
/// mais peuvent voir les modalités de l'offre qu'ils ont rejoint
class InvitedPromoStatusWidget extends ConsumerStatefulWidget {
  final String userId;

  const InvitedPromoStatusWidget({
    super.key,
    required this.userId,
  });

  @override
  ConsumerState<InvitedPromoStatusWidget> createState() => _InvitedPromoStatusWidgetState();
}

class _InvitedPromoStatusWidgetState extends ConsumerState<InvitedPromoStatusWidget> {
  LaunchPromoUser? _userPromo;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPromo();
  }

  Future<void> _loadPromo() async {
    final service = ref.read(launchPromotionServiceProvider);
    final promo = await service.getUserPromo(widget.userId);
    setState(() {
      _userPromo = promo;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const SizedBox.shrink();
    }

    // Ne rien afficher si pas de promo ou si c'est un créateur (pas un invité)
    if (_userPromo == null || _userPromo!.type != PromoType.invited) {
      return const SizedBox.shrink();
    }

    // Ne rien afficher si la promo n'est plus active
    if (!_userPromo!.isPromoActive) {
      return const SizedBox.shrink();
    }

    final daysRemaining = _userPromo!.daysRemaining;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.teal.shade400, Colors.teal.shade600],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.card_giftcard,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '🎁 Offre Invité Active',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '$daysRemaining jours restants',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Message
          Text(
            'Vous bénéficiez de 3 mois d\'abonnement Starter GRATUIT '
            'grâce à l\'invitation d\'un créateur Tontetic.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.95),
              fontSize: 14,
            ),
          ),

          const SizedBox(height: 12),

          // Avantages
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildAdvantage('✓ 2 tontines simultanées'),
                const SizedBox(height: 4),
                _buildAdvantage('✓ 10 participants par tontine'),
                const SizedBox(height: 4),
                _buildAdvantage('✓ Support chat prioritaire'),
              ],
            ),
          ),

          const SizedBox(height: 8),

          Text(
            'Après 3 mois : ${LaunchPromotionService.priceAfterEuro}€/mois pour continuer',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 12,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdvantage(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 13,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}

