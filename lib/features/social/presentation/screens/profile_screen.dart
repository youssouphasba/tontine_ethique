import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart'; // Import Added
import 'package:tontetic/core/theme/app_theme.dart';
import 'package:tontetic/core/providers/user_provider.dart';
import 'package:tontetic/core/models/user_model.dart';
import 'package:tontetic/core/services/security_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tontetic/features/social/data/social_provider.dart';
import 'package:tontetic/features/social/presentation/screens/direct_chat_screen.dart';
import 'package:tontetic/features/tontine/presentation/screens/user_profile_screen.dart';

class ProfileScreen extends ConsumerWidget {
  final String userName;
  final String? userId;
  final bool isMe;

  const ProfileScreen({super.key, required this.userName, this.userId, this.isMe = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // If viewing own profile, show enhanced editable UserProfileScreen
    if (isMe) {
      return const UserProfileScreen();
    }

    return FutureBuilder<DocumentSnapshot>(
      future: userId != null ? FirebaseFirestore.instance.collection('users').doc(userId).get() : null,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        // Mock State for non-me user if fetch fails or no ID
        var otherUser = UserState(
           uid: userId ?? '',
           phoneNumber: '',
           isPremium: false,
           zone: UserZone.zoneEuro,
           status: AccountStatus.guest,
           encryptedName: SecurityService.encryptData(userName),
           bio: 'Membre Passionné',
           jobTitle: 'Membre',
        );

        if (snapshot.hasData && snapshot.data!.exists) {
           final data = snapshot.data!.data() as Map<String, dynamic>;
           
           // Improved name detection
           String? detectedName;
           final fullName = data['fullName'] as String?;
           final dispName = data['displayName'] as String?;
           final pseudo = data['pseudo'] as String?;
           final email = data['email'] as String?;
           final encrypted = data['encryptedName'] as String?;

           if (fullName != null && fullName.isNotEmpty && !fullName.contains('Utilisateur')) {
             detectedName = fullName;
           } else if (dispName != null && dispName.isNotEmpty && !dispName.contains('Utilisateur')) {
             detectedName = dispName;
           } else if (pseudo != null && pseudo.isNotEmpty) {
             detectedName = pseudo;
           } else if (encrypted != null && encrypted.isNotEmpty) {
             try {
               final decrypted = SecurityService.decryptData(encrypted);
               if (decrypted.isNotEmpty && !decrypted.contains('Utilisateur')) {
                 detectedName = decrypted;
               }
             } catch (_) {}
           }

           if (detectedName == null && email != null && email.contains('@')) {
             detectedName = email.split('@').first;
           }
           
           otherUser = otherUser.copyWith(
             encryptedName: SecurityService.encryptData(detectedName ?? userName),
             photoUrl: data['photoUrl'],
             bio: data['bio'],
             jobTitle: data['jobTitle'],
             honorScore: data['honorScore'] ?? 50,
             activeCirclesCount: data['activeCirclesCount'] ?? 0,
           );
        }

        return _buildContent(context, ref, otherUser);
      },
    );
  }

  Widget _buildContent(BuildContext context, WidgetRef ref, UserState user) {
    final social = ref.watch(socialProvider);
    final displayName = user.displayName.isEmpty ? userName : user.displayName;
    final photoUrl = user.photoUrl; // REAL: No more pravatar fallback
    final bio = (user.bio.isNotEmpty && user.bio != 'Membre Tontetic') ? user.bio : 'Membre Passionné';
    final jobTitle = (user.jobTitle.isNotEmpty && user.jobTitle != 'Membre') ? user.jobTitle : 'Contributeur';
    final honorScore = user.honorScore;


    final isFollowing = social.isFollowing(user.uid);
    final isMutual = social.isMutualFollow(user.uid);

    return Scaffold(
      appBar: AppBar(
        title: Text(isMe ? 'Mon Profil' : 'Profil de $displayName'),
        // Theme handles colors now
        actions: [
          if (!isMe)
            IconButton(
              icon: Icon(Icons.message, color: AppTheme.gold),
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (ctx) => DirectChatScreen(friendName: displayName, friendId: user.uid)));
              },
            ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Header: Avatar & Stats
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.marineBlue,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(32),
                  bottomRight: Radius.circular(32),
                ),
              ),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
                    backgroundColor: Colors.white,
                    child: photoUrl == null ? Text(displayName.isNotEmpty ? displayName[0].toUpperCase() : '?', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AppTheme.marineBlue)) : null,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    displayName,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  Text(
                    jobTitle,
                    style: TextStyle(fontSize: 14, color: Colors.white70),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildStatItem('Honor Score', '$honorScore/5 ⭐', Icons.verified, null),
                      GestureDetector(
                        onTap: () => _showFollowersList(context, ref, displayName, 'followers'),
                        child: _buildStatItem('Abonnés', social.getFollowers(user.uid).toString(), Icons.people, null),
                      ),
                      GestureDetector(
                        onTap: () => _showFollowersList(context, ref, displayName, 'following'),
                        child: _buildStatItem('Abonnements', social.following.length.toString(), Icons.person_add, null),
                      ),
                      _buildStatItem('Tontines', user.activeCirclesCount.toString(), Icons.account_balance, null),
                    ],
                  ),
                  if (isMutual) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppTheme.gold.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppTheme.gold),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.handshake, color: AppTheme.gold, size: 16),
                          SizedBox(width: 8),
                          Text('Ami Mutuel 🤝', style: TextStyle(color: AppTheme.gold, fontWeight: FontWeight.bold, fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Bio Section
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('À propos', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.marineBlue)),
                  const SizedBox(height: 8),
                  Text(
                    bio,
                    style: TextStyle(
                      fontSize: 14, 
                      color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.grey[700], 
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 32),
                  
                  // Mutual Follow Invitation Button (V3.9 Critical logic)
                  if (!isMe) ...[
                    if (isMutual) 
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton.icon(
                          onPressed: () => _showInviteDialog(context, ref, userName, user.uid),
                          icon: const Icon(Icons.mail_outline),
                          label: const Text('Inviter à une tontine'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.gold,
                            foregroundColor: AppTheme.marineBlue,
                            elevation: 4,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                        ),
                      )
                    else 
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Theme.of(context).brightness == Brightness.dark ? Colors.white.withValues(alpha: 0.05) : Colors.grey[50],
                          border: Border.all(color: Theme.of(context).brightness == Brightness.dark ? Colors.white10 : Colors.grey[200]!),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.lock_person_outlined, size: 24, color: AppTheme.gold),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Suivez-vous mutuellement pour débloquer les invitations privées.',
                                style: TextStyle(
                                  fontSize: 13, 
                                  color: Theme.of(context).brightness == Brightness.dark ? Colors.white60 : Colors.grey[600],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    
                    const SizedBox(height: 20),
                    
                    // Follow Toggle (Duo Action)
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 56,
                            child: ElevatedButton(
                              onPressed: () => ref.read(socialProvider.notifier).toggleFollow(user.uid),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isFollowing 
                                    ? (Theme.of(context).brightness == Brightness.dark ? Colors.white12 : Colors.grey[200])
                                    : AppTheme.marineBlue,
                                foregroundColor: isFollowing 
                                    ? (Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.black87)
                                    : Colors.white,
                                elevation: isFollowing ? 0 : 2,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                              child: Text(
                                isFollowing ? 'Abonné' : 'Suivre',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          height: 56,
                          width: 56,
                          decoration: BoxDecoration(
                            border: Border.all(color: Theme.of(context).brightness == Brightness.dark ? Colors.white24 : Colors.grey[300]!),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.share_outlined),
                            onPressed: () {
                              final String shareText = 'Découvre le profil de $displayName sur Tontetic ! \n\nhttps://tontetic-app.web.app/profile/${user.uid}';
                              Share.share(shareText);
                            },
                            color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : AppTheme.marineBlue,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, VoidCallback? onTap) {
    return Column(
      children: [
        Icon(icon, color: AppTheme.gold, size: 20),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[400])),
      ],
    );
  }

  void _showFollowersList(BuildContext context, WidgetRef ref, String userName, String type) {
    final currentUser = ref.read(userProvider);
    final userId = this.userId ?? currentUser.uid;
    
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(type == 'followers' ? Icons.people : Icons.person_add, color: AppTheme.marineBlue),
                const SizedBox(width: 12),
                Text(
                  type == 'followers' ? 'Abonnés' : 'Abonnements',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const Divider(height: 24),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(userId)
                    .collection(type) // 'followers' or 'following'
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  
                  if (snapshot.hasError) {
                    return Center(child: Text('Erreur: ${snapshot.error}'));
                  }
                  
                  final docs = snapshot.data?.docs ?? [];
                  
                  if (docs.isEmpty) {
                    return Center(
                      child: Text(
                        type == 'followers' 
                            ? 'Aucun abonné pour le moment' 
                            : 'Vous ne suivez personne',
                        style: const TextStyle(color: Colors.grey),
                      ),
                    );
                  }
                  
                  return ListView.builder(
                    shrinkWrap: true,
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final data = docs[index].data() as Map<String, dynamic>;
                      final targetUserId = docs[index].id;
                      final String? fullName = data['fullName'];
                      final String? dispName = data['displayName'];
                      final String? pseudo = data['pseudo'];
                      final String? email = data['email'];
                      
                      String targetName = '';
                      if (fullName != null && fullName.isNotEmpty && !fullName.contains('Utilisateur')) {
                        targetName = fullName;
                      } else if (dispName != null && dispName.isNotEmpty && !dispName.contains('Utilisateur')) {
                        targetName = dispName;
                      } else if (pseudo != null && pseudo.isNotEmpty) {
                        targetName = pseudo;
                      } else if (email != null && email.contains('@')) {
                        targetName = email.split('@').first;
                      } else {
                        targetName = 'Memb-${targetUserId.substring(0, 4)}';
                      }
                      
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppTheme.marineBlue.withAlpha(50),
                          child: Text(targetName.isNotEmpty ? targetName[0].toUpperCase() : '?'),
                        ),
                        title: Text(targetName),
                        trailing: type == 'following'
                            ? OutlinedButton(
                                onPressed: () {
                                  ref.read(socialProvider.notifier).toggleFollow(targetUserId);
                                  Navigator.pop(ctx);
                                },
                                child: const Text('Ne plus suivre'),
                              )
                            : null,
                        onTap: () {
                          Navigator.pop(ctx);
                          Navigator.push(context, MaterialPageRoute(
                            builder: (_) => ProfileScreen(userName: targetName, userId: targetUserId),
                          ));
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showInviteDialog(BuildContext context, WidgetRef ref, String targetName, String targetId) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Choisir une tontine', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _buildInviteCircleOption(ctx, ref, targetName, targetId, 'Épargne Tabaski 2025', 50000),
            _buildInviteCircleOption(ctx, ref, targetName, targetId, 'Business Women Dakar', 25000),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildInviteCircleOption(BuildContext context, WidgetRef ref, String targetName, String targetId, String circleName, double amount) {
    return ListTile(
      leading: const Icon(Icons.groups, color: AppTheme.marineBlue),
      title: Text(circleName),
      subtitle: Text('Cotisation: ${amount.toInt()} FCFA'),
      trailing: const Icon(Icons.send_rounded, color: AppTheme.gold),
      onTap: () {
        ref.read(socialProvider.notifier).sendMessage(
          targetName, 
          targetId,
          'Je t\'invite à rejoindre ma tontine "$circleName" !',
          isInvite: true,
          circleData: {'name': circleName, 'amount': amount},
        );
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Invitation envoyée à $targetName !')),
        );
      },
    );
  }
}
