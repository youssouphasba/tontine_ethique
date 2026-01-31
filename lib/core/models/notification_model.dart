import 'package:cloud_firestore/cloud_firestore.dart';

enum NotificationType {
  info,
  warning,
  success,
  payment,
  tontine_invite,
  chat_message,
}

class AppNotification {
  final String id;
  final String title;
  final String body;
  final NotificationType type;
  final bool isRead;
  final DateTime createdAt;
  final Map<String, dynamic>? data; // Pour les deep links ou actions

  AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.isRead,
    required this.createdAt,
    this.data,
  });

  factory AppNotification.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AppNotification(
      id: doc.id,
      title: data['title'] ?? '',
      body: data['body'] ?? '',
      type: _parseType(data['type']),
      isRead: data['isRead'] ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      data: data['data'],
    );
  }

  static NotificationType _parseType(String? typeStr) {
    switch (typeStr) {
      case 'warning': return NotificationType.warning;
      case 'success': return NotificationType.success;
      case 'payment': return NotificationType.payment;
      case 'tontine_invite': return NotificationType.tontine_invite;
      case 'chat_message': return NotificationType.chat_message;
      default: return NotificationType.info;
    }
  }
}
