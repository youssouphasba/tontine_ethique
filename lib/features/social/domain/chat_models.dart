class ChatMessage {
  final String id;
  final String senderId;
  final String text;
  final DateTime timestamp;
  final bool isInvite;
  final Map<String, dynamic>? circleData;
  final bool isEncrypted;
  final String? encryptedKey;
  final String? iv;

  ChatMessage({
    required this.id,
    required this.senderId,
    required this.text,
    required this.timestamp,
    this.isInvite = false,
    this.circleData,
    this.isEncrypted = false,
    this.encryptedKey,
    this.iv,
  });
}

class Conversation {
  final String friendName;
  final List<ChatMessage> messages;

  Conversation({required this.friendName, required this.messages});

  ChatMessage? get lastMessage => messages.isNotEmpty ? messages.last : null;
}

class UserActivity {
  final String id;
  final String userName;
  final String userAvatar; 
  final String description; 
  final String actionLabel; 
  final DateTime timestamp;

  UserActivity({
    required this.id,
    required this.userName,
    required this.userAvatar,
    required this.description,
    required this.actionLabel,
    required this.timestamp,
  });
}
