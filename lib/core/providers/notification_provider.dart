import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tontetic/core/models/notification_model.dart';
import 'package:tontetic/core/providers/auth_provider.dart';

class NotificationState {
  final List<AppNotification> notifications;
  final int unreadCount;
  final bool isLoading;

  NotificationState({
    this.notifications = const [],
    this.unreadCount = 0,
    this.isLoading = true,
  });

  NotificationState copyWith({
    List<AppNotification>? notifications,
    int? unreadCount,
    bool? isLoading,
  }) {
    return NotificationState(
      notifications: notifications ?? this.notifications,
      unreadCount: unreadCount ?? this.unreadCount,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class NotificationNotifier extends StateNotifier<NotificationState> {
  final Ref ref;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  StreamSubscription? _sub;

  NotificationNotifier(this.ref) : super(NotificationState()) {
    _initListener();
  }

  void _initListener() {
    state = state.copyWith(isLoading: true);
    
    final authState = ref.watch(authStateProvider);
    
    authState.whenData((user) {
      if (user != null) {
        _sub?.cancel();
        
        _sub = _db
            .collection('users')
            .doc(user.uid)
            .collection('notifications')
            .orderBy('createdAt', descending: true)
            .limit(50) // Limit loading
            .snapshots()
            .listen((snapshot) {
              final notifs = snapshot.docs
                  .map((doc) => AppNotification.fromFirestore(doc))
                  .toList();
              
              final unread = notifs.where((n) => !n.isRead).length;

              state = state.copyWith(
                notifications: notifs,
                unreadCount: unread,
                isLoading: false,
              );
            });
      } else {
        _sub?.cancel();
        state = NotificationState(isLoading: false);
      }
    });
  }

  Future<void> markAsRead(String notificationId) async {
    final user = ref.read(authStateProvider).value;
    if (user == null) return;

    try {
      await _db
          .collection('users')
          .doc(user.uid)
          .collection('notifications')
          .doc(notificationId)
          .update({'isRead': true});
    } catch (e) {
      // Handle error cleanly or log
    }
  }

  Future<void> markAllAsRead() async {
    final user = ref.read(authStateProvider).value;
    if (user == null) return;

    final batch = _db.batch();
    
    // Note: In real app, querying all unread and batching is better.
    // For now, we take from local state to find unread ones.
    final unreadNotifs = state.notifications.where((n) => !n.isRead);

    if (unreadNotifs.isEmpty) return;

    for (final n in unreadNotifs) {
       final ref = _db
          .collection('users')
          .doc(user.uid)
          .collection('notifications')
          .doc(n.id);
       batch.update(ref, {'isRead': true});
    }

    try {
      await batch.commit();
    } catch (e) {
      // Log error
    }
  }

  Future<void> deleteNotification(String notificationId) async {
    final user = ref.read(authStateProvider).value;
    if (user == null) return;

    await _db
        .collection('users')
        .doc(user.uid)
        .collection('notifications')
        .doc(notificationId)
        .delete();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

final notificationProvider = StateNotifierProvider<NotificationNotifier, NotificationState>((ref) {
  return NotificationNotifier(ref);
});
