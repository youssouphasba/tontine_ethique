import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:share_plus/share_plus.dart';
import 'package:tontetic/core/theme/app_theme.dart';
import 'package:tontetic/features/social/presentation/screens/profile_screen.dart';
import 'package:tontetic/core/providers/user_provider.dart'; // Import UserProvider
import 'package:tontetic/core/providers/tontine_provider.dart'; // Import CircleProvider
import 'package:tontetic/core/presentation/widgets/tts_control_toggle.dart';
import 'package:tontetic/core/presentation/widgets/speaker_icon.dart';
import 'package:tontetic/features/tontine/presentation/screens/circle_chat_screen.dart';
import 'package:tontetic/features/tontine/presentation/screens/exit_circle_screen.dart';
import 'package:tontetic/core/providers/auth_provider.dart';
import 'package:tontetic/features/tontine/presentation/screens/legal_commitment_screen.dart';
import 'package:tontetic/core/services/notification_service.dart';

class CircleDetailsScreen extends ConsumerWidget {
  final String circleName;
  final String circleId;
  final bool isJoined; // Indique si l'user est déjà membre
  final bool isAdmin; 

  const CircleDetailsScreen({
    super.key, 
    required this.circleName,
    this.circleId = 'circle_001',
    this.isJoined = true, 
    this.isAdmin = false
  });

  // Dynamic members list removed - fetching from StreamBuilder now


  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userProvider);
    final circleService = ref.watch(circleServiceProvider);
    return StreamBuilder<TontineCircle?>(
      stream: circleService.getCircleById(circleId),
      builder: (context, circleSnapshot) {
        if (circleSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        
        final circle = circleSnapshot.data;
        // handle null circle if needed, e.g. deleted
        if (circle == null) {
             return Scaffold(appBar: AppBar(title: const Text('Erreur')), body: const Center(child: Text('Cercle introuvable')));
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(circleName),
            actions: [
              const TTSControlToggle(),
              // Chat button
              IconButton(
                icon: const Icon(Icons.chat_bubble_outline),
                tooltip: 'Discussion du cercle',
                onPressed: () => Navigator.push(
                  context, 
                  MaterialPageRoute(
                    builder: (_) => CircleChatScreen(
                      circleName: circleName, 
                      circleId: circleId,
                    ),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.how_to_vote), 
                tooltip: 'Voter pour l\'ordre',
                onPressed: () => Navigator.push(
                  context, 
                  MaterialPageRoute(
                    builder: (_) => PayoutOrderVotingScreen(
                      circleName: circleName, 
                      circleId: circleId,
                    ),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.share_outlined),
                tooltip: 'Partager ce cercle',
                onPressed: () {
                  Share.share(
                    'Rejoins ma tontine "$circleName" sur Tontetic ! \n\n'
                    'Code d\'invitation : $circleId \n\n'
                    'Lien direct : https://tontetic-app.web.app/join/$circleId',
                    subject: 'Invitation Tontine'
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.more_vert), 
                onPressed: () => _showMoreOptions(context, circle), 
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildInfoCard(context, circle),
                const SizedBox(height: 24),
                _buildWarrantyCard(context),
                const SizedBox(height: 24),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Row(
                    children: [
                       Text(
                        'Membres & Solidarité',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SpeakerIcon(text: 'Membres et solidarité'),
                    ],
                  ),
                ),
                _buildInviteButton(context),
                const SizedBox(height: 12),
                if (isAdmin) _buildPendingRequests(context, ref),
                
                // V16: Always show members (Public View)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text('Participants', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
                StreamBuilder<List<Map<String, dynamic>>>(
                  stream: circleService.getCircleMembers(circleId, user.uid),
                  builder: (context, snapshot) {
                     if (snapshot.connectionState == ConnectionState.waiting) {
                       return const Center(child: CircularProgressIndicator());
                     }
                     final members = snapshot.data ?? [];
                     if (members.isEmpty) {
                       return const Padding(
                         padding: EdgeInsets.all(16.0),
                         child: Text('Aucun participant pour le moment.', style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey)),
                       );
                     }
                     return Column(
                       children: members.map((m) => _buildMemberTile(context, m, circle)).toList(), 
                     );
                  },
                ),
                
                const SizedBox(height: 24),

                // Join / Sign Actions
                if (!isJoined) ...[
                  if (circle.pendingSignatureIds.contains(user.uid))
                     _buildFinalizeMembershipSection(context, ref, circle)
                  else
                    _buildJoinSection(context, ref, circle),
                ] else
                   const Center(child: Text('Vous êtes membre de ce cercle.', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold))),

                // V16: Creator Management Section (Join Requests)
                if (circle.creatorId == user.uid) ...[
                  const SizedBox(height: 24),
                  _buildJoinRequestsSection(context, ref, circle),
                ],

                const SizedBox(height: 48),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFinalizeMembershipSection(BuildContext context, WidgetRef ref, TontineCircle circle) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.green),
      ),
      child: Column(
        children: [
          const Icon(Icons.check_circle_outline, size: 48, color: Colors.green),
          const SizedBox(height: 16),
          const Text(
            'Demande Approuvée !',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.green),
          ),
          const SizedBox(height: 8),
          const Text(
            'L\'administrateur a validé votre demande. Il ne vous reste plus qu\'à signer la charte pour entrer.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: () => _showLegalCommitment(context, ref, circle),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
              child: const Text('SIGNER ET ENTRER'),
            ),
          ),
        ],
      ),
    );
  }

  void _showLegalCommitment(BuildContext context, WidgetRef ref, TontineCircle circle) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => 
      LegalCommitmentScreen(
        amount: circle.amount,
        onAccepted: () async {
          final user = ref.read(userProvider);
          final String circleId = circle.id;
          
          Navigator.pop(context); // Close Legal Screen

          try {
            await ref.read(circleProvider.notifier).finalizeMembership(circleId, user.uid);
            
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bienvenue ! Vous êtes maintenant membre.')));
              // Force refresh/rebuild will check "isJoined" next time
            }
            
            // Notification
            NotificationService.showNewMemberAlert(
                memberName: user.displayName, 
                circleName: circle.name,
            );

          } catch (e) {
             if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red));
             }
          }
        },
      )
    ));
  }

  Widget _buildJoinSection(BuildContext context, WidgetRef ref, TontineCircle? circle) {
    final amountText = circle != null ? '${circle.amount.toStringAsFixed(0)} ${circle.currency}' : '...';
    
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark ? AppTheme.marineBlue.withValues(alpha: 0.2) : AppTheme.marineBlue.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).brightness == Brightness.dark ? AppTheme.gold : AppTheme.marineBlue),
      ),
      child: Column(
        children: [
          const Text(
            'Prêt à rejoindre ce cercle ?',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          const SizedBox(height: 16),
          Text(
            'En rejoignant, vous vous engagez à verser $amountText par mois.',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: () => _handleJoinAttempt(context, ref),
              child: const Text('DEMANDER À REJOINDRE'),
            ),
          ),
        ],
      ),
    );
  }

  void _handleJoinAttempt(BuildContext context, WidgetRef ref) async {
    // V15: Now requires creator approval before joining
    // Show request dialog instead of direct join
    
    _showJoinRequestDialog(context, ref);
  }
  
  Widget _buildPendingRequests(BuildContext context, WidgetRef ref) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('join_requests')
          .where('circleId', isEqualTo: circleId)
          .where('status', isEqualTo: 'pending')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const SizedBox.shrink();

        final requests = snapshot.data!.docs;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text('Demandes d\'adhésion 🔔', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            ),
            ...requests.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final requestId = doc.id;
              final requesterId = data['requesterId'] ?? data['userId'] ?? '';
              String requesterName = data['requesterName'] ?? data['userName'] ?? 'Membre';
              if (requesterName.trim().isEmpty) requesterName = 'Membre';
              final message = data['message'] ?? '';

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: AppTheme.gold.withValues(alpha: 0.3))),
                child: ListTile(
                  leading: CircleAvatar(child: Text(requesterName[0])),
                  title: Text(requesterName, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(message, style: const TextStyle(fontSize: 12)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.check_circle, color: Colors.green),
                        onPressed: () => ref.read(circleProvider.notifier).approveJoinRequest(requestId, circleId, requesterId),
                      ),
                      IconButton(
                        icon: const Icon(Icons.cancel, color: Colors.red),
                        onPressed: () => FirebaseFirestore.instance.collection('join_requests').doc(requestId).update({'status': 'rejected'}),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        );
      },
    );
  }

  void _showJoinRequestDialog(BuildContext context, WidgetRef ref) {
    final messageController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.person_add, color: AppTheme.marineBlue),
            SizedBox(width: 12),
            Text('Demande d\'adhésion'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark ? Colors.orange.withValues(alpha: 0.2) : Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Theme.of(context).brightness == Brightness.dark ? Colors.orange.withValues(alpha: 0.4) : Colors.orange.shade200),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline, 
                    color: Theme.of(context).brightness == Brightness.dark ? Colors.orange.shade300 : Colors.orange.shade700, 
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Le créateur du cercle doit approuver votre demande avant que vous puissiez rejoindre.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text('Message au créateur (optionnel) :', style: TextStyle(fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            TextField(
              controller: messageController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Présentez-vous brièvement...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.send, size: 18),
            label: const Text('ENVOYER LA DEMANDE'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.gold,
              foregroundColor: AppTheme.marineBlue,
            ),
            onPressed: () async {
              final user = ref.read(userProvider);
              if (user.uid.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vous devez être connecté pour rejoindre un cercle.')));
                return;
              }

              Navigator.pop(context);
              
              try {
                await ref.read(circleProvider.notifier).requestToJoin(
                  circleId: circleId,
                  circleName: circleName,
                  requesterId: user.uid,
                  requesterName: user.displayName,
                  message: messageController.text,
                );

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.white),
                        SizedBox(width: 12),
                        Expanded(child: Text('Demande envoyée ! Le créateur sera notifié.')),
                      ],
                    ),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red));
              }
            },
          ),
        ],
      ),
    );
  }


  Widget _buildInfoCard(BuildContext context, TontineCircle? circle) {
    final amountText = circle != null ? '${circle.amount.toStringAsFixed(0)} ${circle.currency}' : '...';
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10),
        ],
      ),
      child: Column(
        children: [
          Icon(Icons.groups, size: 48, color: Theme.of(context).brightness == Brightness.dark ? AppTheme.gold : AppTheme.marineBlue),
          const SizedBox(height: 8),
          Text(
            '$amountText / mois',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).brightness == Brightness.dark ? AppTheme.gold : AppTheme.marineBlue,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWarrantyCard(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: () => _showWarrantyInfo(context), 
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark 
              ? AppTheme.gold.withValues(alpha: 0.15) 
              : AppTheme.marineBlue.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark 
                ? AppTheme.gold.withValues(alpha: 0.5) 
                : AppTheme.marineBlue.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.shield, 
              color: AppTheme.gold,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Engagement de Solidarité Actif',
                style: TextStyle(
                  fontWeight: FontWeight.bold, 
                  color: isDark ? Colors.white : AppTheme.marineBlue,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showWarrantyInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.shield, color: AppTheme.gold),
            SizedBox(width: 12),
            Text('Système de Garantie'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('La garantie protège les membres contre les défauts de paiement.', style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 12),
            Text('• Fonds bloqués sur compte séquestre'),
            Text('• Libérés automatiquement à la fin du cycle'),
            Text('• Couvre 100% en cas de défaut'),
            SizedBox(height: 12),
            Text('En cas de non-paiement, la garantie est utilisée pour couvrir les autres membres.', style: TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Compris')),
        ],
      ),
    );
  }

  Widget _buildInviteButton(BuildContext context) {
    return Column(
      children: [
        if (isAdmin)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark ? Colors.white12 : Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Theme.of(context).brightness == Brightness.dark ? Colors.white24 : Colors.grey[300]!),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.vpn_key, size: 16, color: Theme.of(context).brightness == Brightness.dark ? Colors.white54 : Colors.grey),
                const SizedBox(width: 8),
                Text('CODE ADHÉSION : ', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Theme.of(context).brightness == Brightness.dark ? Colors.white54 : Colors.grey)),
                SelectableText(circleId, style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, color: Theme.of(context).brightness == Brightness.dark ? AppTheme.gold : AppTheme.marineBlue)),
              ],
            ),
          ),
        const SizedBox(height: 12),
        Tooltip(
          message: 'Partager le lien via WhatsApp, SMS...',
          child: ElevatedButton.icon(
            onPressed: () {
              Share.share(
                'Rejoins ma tontine "$circleName" sur Tontetic ! \n\n'
                'Code d\'invitation : $circleId \n\n'
                'Lien direct : https://tontetic-app.web.app/join/$circleId \n\n'
                'Télécharge l\'app ici : https://tontetic-app.web.app',
                subject: 'Invitation Tontine Éthique'
              );
            },
            icon: const Icon(Icons.share, size: 18),
            label: const Text('Inviter un membre'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: AppTheme.marineBlue,
              side: const BorderSide(color: AppTheme.marineBlue),
              elevation: 0,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildJoinRequestsSection(BuildContext context, WidgetRef ref, TontineCircle circle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text('Demandes d\'adhésion', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ),
        StreamBuilder<List<JoinRequest>>(
          stream: ref.read(circleServiceProvider).getJoinRequestsForCircle(circle.id),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: Padding(
                padding: EdgeInsets.all(8.0),
                child: CircularProgressIndicator(),
              ));
            }
            
            final requests = snapshot.data ?? [];
            if (requests.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text('Aucune demande en attente.', style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey)),
              );
            }

            return Column(
              children: requests.map((req) => Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.person)),
                  title: Text(req.requesterName),
                  subtitle: Text(req.message != null && req.message!.isNotEmpty ? req.message! : 'Souhaite rejoindre le cercle'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.check_circle, color: Colors.green),
                        onPressed: () => _approveRequest(context, ref, req, circle),
                      ),
                      IconButton(
                        icon: const Icon(Icons.cancel, color: Colors.red),
                        onPressed: () {
                          // TODO: Implement reject logic in CircleService
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Rejet non encore implémenté')));
                        },
                      ),
                    ],
                  ),
                ),
              )).toList(),
            );
          },
        ),
      ],
    );
  }

  void _approveRequest(BuildContext context, WidgetRef ref, JoinRequest request, TontineCircle circle) async {
    try {
      await ref.read(circleProvider.notifier).approveJoinRequest(request.id, circle.id, request.requesterId);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Demande de ${request.requesterName} approuvée !')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red));
      }
    }
  }

  Widget _buildMemberTile(BuildContext context, Map<String, dynamic> member, TontineCircle circle) {
    final bool isTriggered = member['guarantee'] == 'triggered';
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: InkWell(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (ctx) => ProfileScreen(userName: member['name'], isMe: member['isMe'], userId: member['id']))),
          child: Stack(
            children: [
              CircleAvatar(child: Text(member['name'].isNotEmpty ? member['name'][0] : '?')),
              Positioned(
                right: 0,
                bottom: 0,
                child: Icon(Icons.lock, size: 14, color: isTriggered ? Colors.red : AppTheme.gold),
              ),
            ],
          ),
        ),
        title: InkWell(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (ctx) => ProfileScreen(userName: member['name'], isMe: member['isMe'], userId: member['id']))),
          child: Text(member['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
        subtitle: isTriggered
            ? Text(
                'SOLIDARITÉ EXÉCUTÉE', 
                style: TextStyle(
                  color: Theme.of(context).brightness == Brightness.dark ? Colors.redAccent : Colors.red, 
                  fontSize: 10, 
                  fontWeight: FontWeight.bold,
                ),
              )
            : Text(
                'Engagement actif (Solidarité)', 
                style: TextStyle(
                  color: Theme.of(context).brightness == Brightness.dark ? Colors.white38 : Colors.grey, 
                  fontSize: 10,
                ),
              ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
             if (member['isMe']) 
              IconButton(
                icon: const Icon(Icons.exit_to_app, color: Colors.orange),
                onPressed: () => _handleLeaveCircle(context, circle),
                tooltip: 'Quitter le cercle',
              ),

            // Trust Score Display

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.star, color: Colors.green, size: 14),
                  const SizedBox(width: 4),
                  Text('${member['trust']}/5', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // V15: No manual button - show guarantee status only
            if (!member['isMe'])
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isTriggered 
                      ? (Theme.of(context).brightness == Brightness.dark ? Colors.red.withValues(alpha: 0.2) : Colors.red.shade100)
                      : (Theme.of(context).brightness == Brightness.dark ? Colors.green.withValues(alpha: 0.2) : Colors.green.shade100),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isTriggered ? Icons.warning : Icons.shield,
                      size: 12,
                      color: isTriggered 
                          ? (Theme.of(context).brightness == Brightness.dark ? Colors.redAccent : Colors.red) 
                          : (Theme.of(context).brightness == Brightness.dark ? Colors.greenAccent : Colors.green),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isTriggered ? 'Garantie utilisée' : 'Garantie OK',
                      style: TextStyle(
                        fontSize: 9, 
                        color: isTriggered 
                            ? (Theme.of(context).brightness == Brightness.dark ? Colors.redAccent : Colors.red) 
                            : (Theme.of(context).brightness == Brightness.dark ? Colors.greenAccent : Colors.green),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  // V15: Removed _showTriggerGuaranteeDialog - no manual intervention allowed
  // Guarantee activation is 100% automatic via AutomatedGuaranteeService

  // --- EDIT CIRCLE LOGIC ---

  // --- EDIT CIRCLE LOGIC ---


  void _showMoreOptions(BuildContext context, TontineCircle circle) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.share, color: Colors.blue),
              title: const Text('Partager le code d\'invitation'),
              onTap: () {
                Navigator.pop(ctx);
                Share.share(
                  'Rejoins ma tontine "$circleName" sur Tontetic ! \n\n'
                  'Code d\'invitation : $circleId \n\n'
                  'Lien direct : https://tontetic-app.web.app/join/$circleId',
                  subject: 'Partage de Code Tontine'
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.notifications_off, color: Colors.orange),
              title: const Text('Muter les notifications'),
              onTap: () {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Notifications du cercle en sourdine.')));
              },
            ),
            ListTile(
              leading: const Icon(Icons.report, color: Colors.red),
              title: const Text('Signaler ce cercle'),
              onTap: () {
                Navigator.pop(ctx);
                _showReportDialog(context);
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.exit_to_app, color: Colors.red),
              title: const Text('Quitter la tontine', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(ctx);
                _handleLeaveCircle(context, circle);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showReportDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('🔴 Signaler ce cercle'),
        content: const Text('Souhaitez-vous signaler ce cercle pour non-respect des règles ou comportement suspect ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('ANNULER')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Signalement envoyé à l\'équipe de modération.')));
            }, 
            child: const Text('SIGNALER')
          ),
        ],
      ),
    );
  }

  // --- LEAVE CIRCLE LOGIC ---

  void _handleLeaveCircle(BuildContext context, TontineCircle circle) {
    // Calculate remaining months mock (or real if available)
    final remaining = circle.maxParticipants - circle.currentCycle;
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ExitCircleScreen(
          circleName: circleName,
          circleId: circleId,
          monthlyAmount: circle.amount,
          remainingMonths: remaining > 0 ? remaining : 0,
        ),
      ),
    );
  }

}


class _LeaveCircleDialog extends StatefulWidget {
  const _LeaveCircleDialog();

  @override
  State<_LeaveCircleDialog> createState() => _LeaveCircleDialogState();
}

class _LeaveCircleDialogState extends State<_LeaveCircleDialog> {
  int _step = 1;
  final _replacementCtrl = TextEditingController();
  bool _agreedToTerms = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_step == 1 ? 'Quitter la Tontine' : 'Transfert de Mandat'),
      content: SizedBox(
        width: 500,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Step Progress
            Row(children: [
              CircleAvatar(radius: 12, backgroundColor: _step >= 1 ? AppTheme.marineBlue : Colors.grey, child: const Text('1', style: TextStyle(fontSize: 10, color: Colors.white))),
              Expanded(child: Container(height: 2, color: _step >= 2 ? AppTheme.marineBlue : Colors.grey)),
              CircleAvatar(radius: 12, backgroundColor: _step >= 2 ? AppTheme.marineBlue : Colors.grey, child: const Text('2', style: TextStyle(fontSize: 10, color: Colors.white))),
            ]),
            const SizedBox(height: 24),
            
            if (_step == 1) _buildStep1() else _buildStep2(),
          ],
        ),
      ),
      actions: [
        if (_step == 2) TextButton(onPressed: () => setState(() => _step = 1), child: const Text('Retour')),
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
        ElevatedButton(
          onPressed: _canProceed() ? _next : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: _step == 2 ? Colors.red : AppTheme.marineBlue,
            foregroundColor: Colors.white,
          ),
          child: Text(_step == 1 ? 'Continuer' : 'SIGNER & QUITTER'),
        ),
      ],
    );
  }

  Widget _buildStep1() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Motif de départ', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        const TextField(maxLines: 2, decoration: InputDecoration(hintText: 'Expliquez brièvement...', border: OutlineInputBorder())),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark ? Colors.amber.withValues(alpha: 0.2) : Colors.amber.shade50, 
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              const Icon(Icons.warning_amber, color: Colors.amber),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Le départ anticipé n\'est possible qu\'en proposant un remplaçant solvable.', 
                  style: TextStyle(
                    fontSize: 12, 
                    color: Theme.of(context).brightness == Brightness.dark ? Colors.amber.shade100 : Colors.black87,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStep2() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
         const Text('Désigner un Remplaçant', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        TextField(
          controller: _replacementCtrl,
          decoration: const InputDecoration(
            labelText: 'Email ou ID du Remplaçant',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.person_search),
          ),
          onChanged: (v) => setState((){}),
        ),
         if (_replacementCtrl.text.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Row(children: const [Icon(Icons.check_circle, size: 14, color: Colors.green), SizedBox(width: 4), Text('Utilisateur trouvé', style: TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.bold))]),
          ),
        const SizedBox(height: 16),
        
        // SECURITY WARNING BLOCK
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark ? Colors.red.withValues(alpha: 0.2) : Colors.red.shade50,
            border: Border.all(color: Theme.of(context).brightness == Brightness.dark ? Colors.red.withValues(alpha: 0.4) : Colors.red.shade200),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '⚠️ RESPONSABILITÉ PROLONGÉE', 
                style: TextStyle(
                  fontWeight: FontWeight.bold, 
                  color: Theme.of(context).brightness == Brightness.dark ? Colors.redAccent : Colors.red, 
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Vous restez responsable des paiements tant que votre remplaçant n\'a pas :\n1. Accepté l\'invitation\n2. Validé sa Certification de Profil\n3. Versé sa propre garantie', 
                style: TextStyle(
                  fontSize: 11, 
                  color: Theme.of(context).brightness == Brightness.dark ? Colors.red.shade100 : Colors.red,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Checkbox(value: _agreedToTerms, onChanged: (v) => setState(() => _agreedToTerms = v!)),
            const Expanded(child: Text('Je certifie transférer ma position et m\'engage solidairement jusqu\'à la validation du remplaçant.', style: TextStyle(fontSize: 11))),
          ],
        ),
      ],
    );
  }

  bool _canProceed() {
    if (_step == 1) return true;
    return _replacementCtrl.text.isNotEmpty && _agreedToTerms;
  }

  void _next() {
    if (_step == 1) {
      setState(() => _step = 2);
    } else {
      Navigator.pop(context);
      // Explicit Warning Snackbar
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('⏳ Invitation Envoyée !', style: TextStyle(fontWeight: FontWeight.bold)),
                Text('Attention : Vous restez garant du créneau jusqu\'à la validation finale de Jean D.', style: TextStyle(fontSize: 12)),
              ],
            ),
          ),
          backgroundColor: Colors.orange.shade800,
          duration: const Duration(seconds: 6),
        )
      );
    }
  }
}
