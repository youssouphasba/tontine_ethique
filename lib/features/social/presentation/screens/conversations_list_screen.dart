import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:tontetic/core/theme/app_theme.dart';
import 'package:tontetic/features/social/data/social_provider.dart';
import 'package:tontetic/features/social/presentation/screens/direct_chat_screen.dart';
import 'package:tontetic/features/chat/presentation/screens/support_chat_screen.dart';
import 'package:tontetic/features/tontine/presentation/screens/circle_chat_screen.dart';

/// Unified Messaging Hub
/// 
/// Groups all conversations in one place:
/// - Support chat
/// - Group chats (tontines)
/// - Direct messages (mutual followers only)
class ConversationsListScreen extends ConsumerStatefulWidget {
  const ConversationsListScreen({super.key});

  @override
  ConsumerState<ConversationsListScreen> createState() => _ConversationsListScreenState();
}

class _ConversationsListScreenState extends ConsumerState<ConversationsListScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Messagerie'),
        backgroundColor: AppTheme.marineBlue,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.gold,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: const [
            Tab(icon: Icon(Icons.groups), text: 'Groupes'),
            Tab(icon: Icon(Icons.storefront), text: 'Marchands'),
            Tab(icon: Icon(Icons.person), text: 'Messages'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildGroupChatsTab(),
          _buildMerchantChatsTab(),
          _buildDirectMessagesTab(),
        ],
      ),
    );
  }

  /// Tab 1: Group Chats (Tontines)
  Widget _buildGroupChatsTab() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const Center(child: Text('Connectez-vous pour voir vos groupes'));
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('tontines')
          .where('members', arrayContains: uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final tontines = snapshot.data?.docs ?? [];

        if (tontines.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.groups_outlined, size: 64, color: Colors.grey[300]),
                const SizedBox(height: 16),
                Text('Aucune tontine active', style: TextStyle(color: Colors.grey[500])),
                const SizedBox(height: 8),
                Text('Rejoignez ou créez une tontine pour discuter', 
                  style: TextStyle(color: Colors.grey[400], fontSize: 12)),
              ],
            ),
          );
        }

        return ListView.separated(
          itemCount: tontines.length + 1, // +1 for support
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, index) {
            if (index == 0) {
              // Support Chat Shortcut
              return ListTile(
                leading: const CircleAvatar(
                  backgroundColor: AppTheme.gold,
                  child: Icon(Icons.support_agent, color: AppTheme.marineBlue),
                ),
                title: const Text('Support Tontetic', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Discutez avec un agent en direct'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SupportChatScreen())),
              );
            }

            final tontine = tontines[index - 1];
            final data = tontine.data() as Map<String, dynamic>;
            final name = data['name'] ?? 'Tontine';
            final emoji = data['emoji'] ?? '💰';
            final memberCount = (data['members'] as List?)?.length ?? 0;

            return ListTile(
              leading: CircleAvatar(
                backgroundColor: AppTheme.marineBlue.withOpacity(0.1),
                child: Text(emoji, style: const TextStyle(fontSize: 24)),
              ),
              title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('$memberCount membres'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => CircleChatScreen(circleId: tontine.id, circleName: name)),
              ),
            );
          },
        );
      },
    );
  }

  /// Tab 2: Merchant Chats (Followed Merchants)
  Widget _buildMerchantChatsTab() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const Center(child: Text('Connectez-vous pour contacter des marchands'));
    }

    final social = ref.watch(socialProvider);
    final followingMerchants = social.following; // In a real app, filter to get only merchants

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('merchants')
          .where(FieldPath.documentId, whereIn: followingMerchants.isEmpty ? ['_none_'] : followingMerchants.take(10).toList())
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final merchants = snapshot.data?.docs ?? [];

        if (merchants.isEmpty && followingMerchants.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.storefront_outlined, size: 64, color: Colors.grey[300]),
                const SizedBox(height: 16),
                Text('Aucun marchand suivi', style: TextStyle(color: Colors.grey[500])),
                const SizedBox(height: 8),
                Text('Suivez des marchands dans la Boutique pour discuter', 
                  style: TextStyle(color: Colors.grey[400], fontSize: 12)),
              ],
            ),
          );
        }

        // Also show followed merchant IDs that might not have a merchant document yet
        final merchantIds = merchants.isEmpty ? followingMerchants.toList() : merchants.map((d) => d.id).toList();

        return ListView.separated(
          itemCount: merchantIds.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final merchantId = merchantIds[index];
            
            // Try to get merchant data from query
            final merchantDoc = merchants.where((d) => d.id == merchantId).firstOrNull;
            final data = merchantDoc?.data() as Map<String, dynamic>?;
            
            final name = data?['businessName'] ?? data?['name'] ?? 'Marchand $merchantId';
            final photoUrl = data?['photoUrl'] ?? data?['logoUrl'];
            final category = data?['category'] ?? 'Boutique';

            return ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.purple.shade100,
                backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
                child: photoUrl == null 
                  ? const Icon(Icons.storefront, color: Colors.purple)
                  : null,
              ),
              title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(category, style: TextStyle(color: Colors.grey[600])),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _startMerchantChat(merchantId, name),
            );
          },
        );
      },
    );
  }

  void _startMerchantChat(String merchantId, String merchantName) {
    // Navigate to direct chat with merchant
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => DirectChatScreen(friendName: merchantName, friendId: merchantId)),
    );
  }

  /// Tab 3: Direct Messages (Mutual Followers Only)
  Widget _buildDirectMessagesTab() {
    final social = ref.watch(socialProvider);
    final conversations = social.directMessages.values.toList();

    return Column(
      children: [
        // Mutual Followers Notice
        Container(
          padding: const EdgeInsets.all(12),
          margin: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline, color: Colors.blue, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Les messages directs sont réservés aux followers mutuels uniquement.',
                  style: TextStyle(fontSize: 12, color: Colors.blue.shade700),
                ),
              ),
            ],
          ),
        ),

        // Mutual Followers List (to start new conversations)
        _buildMutualFollowersSection(social),

        const Divider(),

        // Existing Conversations
        Expanded(
          child: conversations.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.message_outlined, size: 64, color: Colors.grey[300]),
                      const SizedBox(height: 16),
                      Text('Aucune conversation', style: TextStyle(color: Colors.grey[500])),
                      const SizedBox(height: 8),
                      Text('Sélectionnez un follower mutuel pour discuter',
                        style: TextStyle(color: Colors.grey[400], fontSize: 12)),
                    ],
                  ),
                )
              : ListView.separated(
                  itemCount: conversations.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final conv = conversations[index];
                    final lastMsg = conv.lastMessage;

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: AppTheme.marineBlue,
                        child: Text(conv.friendName.isNotEmpty ? conv.friendName[0].toUpperCase() : '?', style: const TextStyle(color: Colors.white)),
                      ),
                      title: Text(conv.friendName, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(
                        lastMsg?.text ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                      trailing: Text(
                        _formatTime(lastMsg?.timestamp),
                        style: TextStyle(fontSize: 10, color: Colors.grey[400]),
                      ),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => DirectChatScreen(friendName: conv.friendName)),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  /// Shows mutual followers with option to start a conversation
  Widget _buildMutualFollowersSection(SocialState social) {
    final mutualFollowers = social.following.intersection(social.followers);
    
    if (mutualFollowers.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(Icons.people_outline, size: 40, color: Colors.grey[300]),
            const SizedBox(height: 8),
            Text('Pas de followers mutuels', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
            const SizedBox(height: 4),
            Text('Suivez des personnes qui vous suivent pour discuter',
              style: TextStyle(color: Colors.grey[400], fontSize: 10)),
          ],
        ),
      );
    }

    return Container(
      height: 100,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Followers mutuels (${mutualFollowers.length})',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: mutualFollowers.length,
              itemBuilder: (context, index) {
                final friendId = mutualFollowers.elementAt(index);
                return _buildMutualFollowerChip(friendId);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMutualFollowerChip(String friendId) {
    // For now, use friendId as name (in real app, fetch user details)
    final displayName = friendId.length > 10 ? '${friendId.substring(0, 10)}...' : friendId;

    return GestureDetector(
      onTap: () => _startDirectChat(friendId, displayName),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: AppTheme.marineBlue,
              child: Text(friendId.isNotEmpty ? friendId[0].toUpperCase() : '?', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 4),
            SizedBox(
              width: 60,
              child: Text(
                displayName,
                style: const TextStyle(fontSize: 10),
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _startDirectChat(String friendId, String friendName) {
    final social = ref.read(socialProvider);
    
    // Verify mutual follow before allowing chat
    if (!social.isMutualFollow(friendId)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Vous devez être followers mutuels pour envoyer un message'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => DirectChatScreen(friendName: friendName, friendId: friendId)),
    );
  }

  String _formatTime(DateTime? timestamp) {
    if (timestamp == null) return '';
    final now = DateTime.now();
    final diff = now.difference(timestamp);
    
    if (diff.inDays > 0) {
      return '${diff.inDays}j';
    } else if (diff.inHours > 0) {
      return '${diff.inHours}h';
    } else if (diff.inMinutes > 0) {
      return '${diff.inMinutes}m';
    }
    return 'now';
  }
}
