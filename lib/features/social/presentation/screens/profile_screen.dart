import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tontetic/core/theme/app_theme.dart';
import 'package:tontetic/core/providers/user_provider.dart';
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
           bio: 'Membre Tontetic',
           jobTitle: 'Membre',
        );

        if (snapshot.hasData && snapshot.data!.exists) {
           final data = snapshot.data!.data() as Map<String, dynamic>;
           otherUser = otherUser.copyWith(
             encryptedName: SecurityService.encryptData(data['fullName'] ?? userName),
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
    final bio = user.bio.isNotEmpty ? user.bio : 'Membre Tontetic';
    final jobTitle = user.jobTitle.isNotEmpty ? user.jobTitle : 'Membre';
    final honorScore = user.honorScore;

    final followers = social.getFollowers(user.uid);
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
                      _buildStatItem('Honor Score', honorScore.toString(), Icons.verified, null),
                      GestureDetector(
                        onTap: () => _showFollowersList(context, ref, displayName, 'followers'),
                        child: _buildStatItem('Abonnés', followers.toString(), Icons.people, null),
                      ),
                      GestureDetector(
                        onTap: () => _showFollowersList(context, ref, displayName, 'following'),
                        child: _buildStatItem('Abonnements', social.following.length.toString(), Icons.person_add, null),
                      ),
                      _buildStatItem('Tontines', user.activeCirclesCount.toString(), Icons.account_balance, null),
                    ],
                  ),
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
                  const SizedBox(height: 24),
                  
                  // Mutual Follow Invitation Button (V3.9 Critical logic)
                  if (!isMe) ...[
                    if (isMutual) 
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => _showInviteDialog(context, ref, userName, user.uid),
                          icon: const Icon(Icons.mail_outline),
                          label: const Text('Inviter à une tontine'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.gold,
                            foregroundColor: AppTheme.marineBlue,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      )
                    else 
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).brightness == Brightness.dark ? Colors.white.withValues(alpha: 0.05) : Colors.grey[100],
                          border: Border.all(color: Theme.of(context).brightness == Brightness.dark ? Colors.white24 : Colors.grey[300]!),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline, size: 20, color: Colors.grey),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Vous devez vous suivre mutuellement pour envoyer une invitation.',
                                style: TextStyle(
                                  fontSize: 12, 
                                  color: Theme.of(context).brightness == Brightness.dark ? Colors.white60 : Colors.grey[600],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    
                    const SizedBox(height: 12),
                    
                    // Follow Toggle
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () => ref.read(socialProvider.notifier).toggleFollow(user.uid),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          side: BorderSide(
                            color: isFollowing 
                                ? Colors.grey 
                                : (Theme.of(context).brightness == Brightness.dark ? AppTheme.gold : AppTheme.marineBlue),
                          ),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text(
                          isFollowing ? 'Se désabonner' : 'Suivre',
                          style: TextStyle(
                            color: isFollowing 
                                ? Colors.grey 
                                : (Theme.of(context).brightness == Brightness.dark ? AppTheme.gold : AppTheme.marineBlue),
                          ),
                        ),
                      ),
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
                      final String? displayNameRaw = data['displayName'];
                      final String? nameField = data['name'];
                      
                      String targetName;
                      if (fullName != null && fullName.isNotEmpty) {
                        targetName = fullName;
                      } else if (displayNameRaw != null && displayNameRaw.isNotEmpty) {
                        targetName = displayNameRaw;
                      } else if (nameField != null && nameField.isNotEmpty) {
                        targetName = nameField;
                      } else {
                        targetName = 'Membre Tontetic';
                      }
                      
                      if (targetName == 'Utilisateur') targetName = 'Membre Tontetic';
                      
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
          targetName,
          'Je t\'invite à rejoindre ma tontine "$circleName" !',
          recipientId: targetId,
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
