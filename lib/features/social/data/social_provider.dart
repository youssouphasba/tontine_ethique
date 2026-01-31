import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tontetic/core/providers/auth_provider.dart';
import 'package:tontetic/core/providers/user_provider.dart';
import 'package:tontetic/core/services/chat_service.dart';
import 'package:tontetic/features/social/data/suggestion_service.dart'; // Import Added
import 'package:tontetic/features/social/domain/chat_models.dart';
export 'package:tontetic/features/social/domain/chat_models.dart';

class SocialState {
  final List<UserActivity> activities;
  final List<String> friends;
  final Set<String> following; // V3.8: IDs of users/merchants followed
  final Set<String> followers; // V3.9: IDs of users following us (for mutual follow)
  final Map<String, int> followersCount; // V3.8: Social Proof for businesses
  final Map<String, Conversation> directMessages; // V3.9: Chat data

  SocialState({
    this.activities = const [], 
    this.friends = const [],
    this.following = const {},
    this.followers = const {},
    this.followersCount = const {},
    this.directMessages = const {},
  });

  SocialState copyWith({
    List<UserActivity>? activities,
    List<String>? friends,
    Set<String>? following,
    Set<String>? followers,
    Map<String, int>? followersCount,
    Map<String, Conversation>? directMessages,
  }) {
    return SocialState(
      activities: activities ?? this.activities,
      friends: friends ?? this.friends,
      following: following ?? this.following,
      followers: followers ?? this.followers,
      followersCount: followersCount ?? this.followersCount,
      directMessages: directMessages ?? this.directMessages,
    );
  }

  bool isFollowing(String entityId) => following.contains(entityId);
  bool isFollower(String entityId) => followers.contains(entityId);
  bool isMutualFollow(String entityId) => isFollowing(entityId) && isFollower(entityId);
  int getFollowers(String entityId) => followersCount[entityId] ?? 0;
  
  /// V15: Get all mutual followers (users who both follow and are followed by the current user)
  /// Used to filter public circles - only show circles from mutual connections
  Set<String> getMutualFollowers(String currentUserId) {
    // Return users who are both in 'following' AND 'followers' sets
    return following.intersection(followers);
  }
}


// (Models and SocialState stay the same)

/// Service provider for ChatService
final chatServiceProvider = Provider<ChatService>((ref) => ChatService());

class SocialNotifier extends StateNotifier<SocialState> {
  final Ref ref;
  final Map<String, StreamSubscription> _convSubs = {};
  final Map<String, StreamSubscription> _socialSubs = {};
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  StreamSubscription? _activitiesSub;

  SocialNotifier(this.ref) : super(SocialState(
    friends: [],
    followers: {},
    following: {},
    followersCount: {},
  )) {
    _initAuthListener();
    _initActivityStream();
  }

  void _initActivityStream() {
    _activitiesSub?.cancel();
    _activitiesSub = _firestore
        .collection('activities')
        .orderBy('timestamp', descending: true)
        .limit(20)
        .snapshots()
        .listen((snapshot) {
      final activityList = snapshot.docs.map((doc) {
        final data = doc.data();
        return UserActivity(
          id: doc.id,
          userName: data['userName'] ?? 'Membre',
          userAvatar: data['userAvatar'] ?? '',
          description: data['description'] ?? '',
          actionLabel: data['actionLabel'] ?? '',
          timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
        );
      }).toList();
      state = state.copyWith(activities: activityList);
    });
  }

  void _initAuthListener() {
    ref.listen(authStateProvider, (previous, next) {
      next.whenData((user) {
        // Clear previous subscriptions
        for (var sub in _socialSubs.values) {
          sub.cancel();
        }
        _socialSubs.clear();

        if (user != null) {
          _startSocialListeners(user.uid);
        } else {
          state = SocialState(); // Clear state on logout
          _initActivityStream(); // Re-init activity stream for guests
        }
      });
    });
    
    // Initial load if already logged in
    final user = ref.read(authStateProvider).value;
    if (user != null) {
      _startSocialListeners(user.uid);
    }
  }

  void _startSocialListeners(String uid) {
    // 1. Listen to FOLLOWING
    _socialSubs['following'] = _firestore
        .collection('users')
        .doc(uid)
        .collection('following')
        .snapshots()
        .listen((snapshot) {
      final followingIds = snapshot.docs.map((doc) => doc.id).toSet();
      state = state.copyWith(following: followingIds);
    });

    // 2. Listen to FOLLOWERS
    _socialSubs['followers'] = _firestore
        .collection('users')
        .doc(uid)
        .collection('followers')
        .snapshots()
        .listen((snapshot) {
      final followersIds = snapshot.docs.map((doc) => doc.id).toSet();
      state = state.copyWith(followers: followersIds);
    });
  }

  /// Démarre l'écoute d'une conversation spécifique
  void listenToConversation(String friendName, String friendId) {
    final user = ref.read(authStateProvider).value;
    if (user == null) return;

    // Use Canonical ID for Firestore (bi-directional)
    final conversationId = ChatService.getCanonicalId(user.uid, friendId);

    if (_convSubs.containsKey(conversationId)) return;

    final sub = ref.read(chatServiceProvider).getMessages(conversationId, user.uid).listen((messages) {
      final conversations = Map<String, Conversation>.from(state.directMessages);
      conversations[friendName] = Conversation(friendName: friendName, messages: messages);
      state = state.copyWith(directMessages: conversations);
    });

    _convSubs[conversationId] = sub;
  }

  Future<void> sendMessage(String friendName, String friendId, String text, {bool isInvite = false, Map<String, dynamic>? circleData}) async {
    final user = ref.read(authStateProvider).value;
    final userData = ref.read(userProvider);
    if (user == null) return;

    // Use Canonical ID
    final conversationId = ChatService.getCanonicalId(user.uid, friendId);

    await ref.read(chatServiceProvider).sendMessage(
      conversationId: conversationId,
      senderId: user.uid,
      recipientId: friendId,
      text: text,
      senderName: userData.displayName,
      senderPhoto: userData.photoUrl,
      recipientName: friendName,
      isInvite: isInvite,
      circleData: circleData,
    );
  }

  /// Toggle follow/unfollow with Firestore persistence
  Future<void> toggleFollow(String entityId) async {
    final user = ref.read(authStateProvider).value;
    if (user == null) return;
    
    // Pre-check: Don't follow yourself
    if (user.uid == entityId) return;

    final isFollowing = state.following.contains(entityId);
    final newFollowing = Set<String>.from(state.following);
    final newFollowersCount = Map<String, int>.from(state.followersCount);

    try {
      if (isFollowing) {
        // Unfollow
        newFollowing.remove(entityId);
        newFollowersCount[entityId] = (newFollowersCount[entityId] ?? 1) - 1;
        
        final batch = _firestore.batch();
        batch.delete(_firestore.collection('users').doc(user.uid).collection('following').doc(entityId));
        batch.delete(_firestore.collection('users').doc(entityId).collection('followers').doc(user.uid));
        
        // OPTIONAL: Delete notification? Usually better to keep history or it's too much work to find the doc
        
        await batch.commit();
      } else {
        // Follow
        newFollowing.add(entityId);
        newFollowersCount[entityId] = (newFollowersCount[entityId] ?? 0) + 1;
        
        final batch = _firestore.batch();
        batch.set(_firestore.collection('users').doc(user.uid).collection('following').doc(entityId), {
          'timestamp': FieldValue.serverTimestamp(),
          'uid': entityId,
        });
        batch.set(_firestore.collection('users').doc(entityId).collection('followers').doc(user.uid), {
          'timestamp': FieldValue.serverTimestamp(),
          'uid': user.uid,
        });

        // 1. ADD IN-APP NOTIFICATION FOR TARGET
        final myData = ref.read(userProvider);
        final notifRef = _firestore.collection('users').doc(entityId).collection('notifications').doc();
        batch.set(notifRef, {
          'id': notifRef.id,
          'title': 'Nouveau follower ! 👤',
          'message': '${myData.displayName} vous suit désormais.',
          'senderId': user.uid,
          'type': 'new_follower',
          'timestamp': FieldValue.serverTimestamp(),
          'read': false,
        });

        // 2. ADD GLOBAL ACTIVITY ENTRY
        final activityRef = _firestore.collection('activities').doc();
        batch.set(activityRef, {
          'userName': myData.displayName,
          'userAvatar': myData.photoUrl ?? '',
          'description': 'suit désormais un nouveau membre',
          'actionLabel': 'VOIR',
          'timestamp': FieldValue.serverTimestamp(),
          'targetId': entityId, // Can be used to navigate to profile
        });

        await batch.commit();
      }

      state = state.copyWith(
        following: newFollowing,
        followersCount: newFollowersCount,
      );
    } catch (e) {
      debugPrint('[SOCIAL_PROVIDER] ❌ Error toggling follow: $e');
    }
  }

  /// PERFORMS A REAL-TIME SEARCH FOR USERS
  Future<List<SuggestionResult>> searchUsers(String query) async {
    if (query.isEmpty) return [];
    
    try {
      // 1. Search by fullName (Prefix match)
      final nameQuery = await _firestore
          .collection('users')
          .where('fullName', isGreaterThanOrEqualTo: query)
          .where('fullName', isLessThanOrEqualTo: '$query\uf8ff')
          .limit(10)
          .get();
      
      // 2. Search by phone (Exact match)
      final phoneQuery = await _firestore
          .collection('users')
          .where('phone', isEqualTo: query)
          .limit(5)
          .get();

      final results = <String, SuggestionResult>{};

      for (var doc in nameQuery.docs) {
        final data = doc.data();
        results[doc.id] = SuggestionResult(
          userId: doc.id,
          userName: data['fullName'] ?? 'Membre',
          userAvatar: data['photoUrl'] ?? '',
          reason: 'Utilisateur trouvé',
          jobTitle: data['jobTitle'],
        );
      }

      for (var doc in phoneQuery.docs) {
        if (!results.containsKey(doc.id)) {
          final data = doc.data();
          results[doc.id] = SuggestionResult(
            userId: doc.id,
            userName: data['fullName'] ?? 'Membre',
            userAvatar: data['photoUrl'] ?? '',
            reason: 'Trouvé par téléphone',
            jobTitle: data['jobTitle'],
          );
        }
      }

      // Exclude ME from results
      final currentUid = ref.read(authStateProvider).value?.uid;
      results.remove(currentUid);

      return results.values.toList();
    } catch (e) {
      debugPrint('[SOCIAL_PROVIDER] ❌ Error searching users: $e');
      return [];
    }
  }

  @override
  void dispose() {
    for (var sub in _convSubs.values) {
      sub.cancel();
    }
    for (var sub in _socialSubs.values) {
      sub.cancel();
    }
    _activitiesSub?.cancel();
    super.dispose();
  }
}

final socialProvider = StateNotifierProvider<SocialNotifier, SocialState>((ref) {
  return SocialNotifier(ref);
});

