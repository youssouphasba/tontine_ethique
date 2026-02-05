import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart'; // Import Added
import 'package:tontetic/core/theme/app_theme.dart';
import 'package:tontetic/core/providers/user_provider.dart';
import 'package:tontetic/core/providers/localization_provider.dart';
import 'package:tontetic/core/providers/localization_provider.dart';
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
    final l10n = ref.read(localizationProvider);
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

        return _buildContent(context, ref, otherUser, l10n);
      },
    );
  }

  Widget _buildContent(BuildContext context, WidgetRef ref, UserState user, LocalizationState l10n) {
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
        title: Text(isMe ? l10n.translate('profile_my') : '${l10n.translate('profile_of')}$displayName'),
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
                      GestureDetector(
                        onTap: () => _showHonorScoreExplanation(context, honorScore.toDouble(), ref),
                        child: _buildStatItem(l10n.translate('honor_score'), '$honorScore/5 ⭐', Icons.verified, null),
                      ),
                      GestureDetector(
                        onTap: () => _showFollowersList(context, ref, displayName, 'followers'),
                        child: _buildStatItem(l10n.translate('followers'), social.getFollowers(user.uid).toString(), Icons.people, null),
                      ),
                      GestureDetector(
                        onTap: () => _showFollowersList(context, ref, displayName, 'following'),
                        child: _buildStatItem(l10n.translate('following_stat'), social.following.length.toString(), Icons.person_add, null),
                      ),
                      _buildStatItem(l10n.translate('tontines_stat'), user.activeCirclesCount.toString(), Icons.account_balance, null),
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
                        child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.handshake, color: AppTheme.gold, size: 16),
                          const SizedBox(width: 8),
                          Text(l10n.translate('mutual_friend'), style: const TextStyle(color: AppTheme.gold, fontWeight: FontWeight.bold, fontSize: 12)),
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
                  Text(l10n.translate('about_title'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.marineBlue)),
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
                          label: Text(l10n.translate('invite_to_tontine')),
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
                                l10n.translate('mutual_follow_warning'),
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
                                isFollowing ? l10n.translate('following_btn') : l10n.translate('follow_btn'),
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

  void _showHonorScoreExplanation(BuildContext context, double score, WidgetRef ref) {
    final l10n = ref.read(localizationProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1A2E) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.gold.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.verified, color: AppTheme.gold, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.translate('honor_score'), // Keeping title as label or translating
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Score : ${score.toStringAsFixed(1)}/5',
                        style: const TextStyle(color: AppTheme.gold, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Explanation
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isDark ? Colors.white12 : Colors.blue.shade100),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, color: isDark ? AppTheme.gold : Colors.blue.shade700, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        l10n.translate('what_is_it'),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isDark ? AppTheme.gold : Colors.blue.shade700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    l10n.translate('honor_score_desc'),
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Formula
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.translate('calculation_formula'), style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? AppTheme.marineBlue.withValues(alpha: 0.3) : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Score = (Paiements réussis / Total) × 5',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDark ? AppTheme.gold : AppTheme.marineBlue,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.translate('new_member_start'),
                    style: TextStyle(fontSize: 12, color: isDark ? Colors.white60 : Colors.grey[600]),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Interpretation
            _buildScoreInterpretation(score, isDark, l10n),

            const SizedBox(height: 20),

            // RGPD Notice
            Row(
              children: [
                const Icon(Icons.gavel, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.translate('rgpd_contact'),
                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildScoreInterpretation(double score, bool isDark, LocalizationState l10n) {
    String label;
    String description;
    Color color;

    if (score >= 4.5) {
      label = l10n.translate('score_excellent');
      description = l10n.translate('excellent_desc');
      color = Colors.green;
    } else if (score >= 4.0) {
      label = l10n.translate('score_very_good');
      description = l10n.translate('very_good_desc');
      color = Colors.lightGreen;
    } else if (score >= 3.0) {
      label = l10n.translate('score_acceptable');
      description = l10n.translate('acceptable_desc');
      color = Colors.orange;
    } else {
      label = l10n.translate('score_warning');
      description = l10n.translate('warning_desc');
      color = Colors.red;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              score >= 4.0 ? Icons.thumb_up : (score >= 3.0 ? Icons.thumbs_up_down : Icons.warning),
              color: color,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontWeight: FontWeight.bold, color: color)),
                Text(
                  description,
                  style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : Colors.grey[700]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showFollowersList(BuildContext context, WidgetRef ref, String userName, String type) {
    final l10n = ref.read(localizationProvider);
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
                    return Center(child: Text('${l10n.translate('error_label')}: ${snapshot.error}'));
                  }
                  
                  final docs = snapshot.data?.docs ?? [];
                  
                  if (docs.isEmpty) {
                    return Center(
                      child: Text(
                        type == 'followers' 
                            ? l10n.translate('no_followers') 
                            : l10n.translate('no_following'),
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
                                child: Text(l10n.translate('unfollow')),
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
    final l10n = ref.read(localizationProvider);
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.translate('choose_tontine'), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
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
          SnackBar(content: Text(ref.read(localizationProvider).translate('invitation_sent_success').replaceAll('@name', targetName))),
        );
      },
    );
  }
}
