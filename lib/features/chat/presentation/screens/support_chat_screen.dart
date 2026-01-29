import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tontetic/core/providers/user_provider.dart';
import 'package:tontetic/core/theme/app_theme.dart';

class SupportChatScreen extends ConsumerStatefulWidget {
  const SupportChatScreen({super.key});

  @override
  ConsumerState<SupportChatScreen> createState() => _SupportChatScreenState();
}

class _SupportChatScreenState extends ConsumerState<SupportChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String? _activeTicketId;
  Stream<QuerySnapshot>? _messagesStream;

  @override
  void initState() {
    super.initState();
    // Defer ticket check to after build to access ref
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkForActiveTicket();
    });
  }

  Future<void> _checkForActiveTicket() async {
    final user = ref.read(userProvider);
    // Look for an open ticket for this user
    final q = await FirebaseFirestore.instance
        .collection('support_tickets')
        .where('userId', isEqualTo: user.uid)
        .where('status', isEqualTo: 'open')
        .limit(1)
        .get();

    if (q.docs.isNotEmpty) {
      setState(() {
        _activeTicketId = q.docs.first.id;
        _initMessagesStream();
      });
    }
  }

  void _initMessagesStream() {
    if (_activeTicketId == null) return;
    _messagesStream = FirebaseFirestore.instance
        .collection('support_tickets')
        .doc(_activeTicketId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots();
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();

    final user = ref.read(userProvider);

    try {
      // 1. Create ticket if not exists
      if (_activeTicketId == null) {
        final docRef = await FirebaseFirestore.instance.collection('support_tickets').add({
          'userId': user.uid,
          'userName': user.displayName.isEmpty ? 'Utilisateur' : user.displayName,
          'userEmail': user.email,
          'subject': text.length > 30 ? '${text.substring(0, 30)}...' : text,
          'status': 'open',
          'category': 'General',
          'priority': 'normal',
          'lastMessage': text,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'unreadCount': 1, // For admin
        });
        setState(() {
          _activeTicketId = docRef.id;
          _initMessagesStream();
        });
      } else {
        // Update existing ticket
        await FirebaseFirestore.instance.collection('support_tickets').doc(_activeTicketId).update({
          'lastMessage': text,
          'updatedAt': FieldValue.serverTimestamp(),
          'unreadCount': FieldValue.increment(1),
        });
      }

      // 2. Add message to subcollection
      if (_activeTicketId != null) {
        await FirebaseFirestore.instance
            .collection('support_tickets')
            .doc(_activeTicketId)
            .collection('messages')
            .add({
          'text': text,
          'senderId': user.uid,
          'isStaff': false,
          'timestamp': FieldValue.serverTimestamp(),
        });
        
        // Scroll to bottom
        Future.delayed(const Duration(milliseconds: 100), () {
          if (_scrollController.hasClients) {
            _scrollController.animateTo(
              _scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        });
      }

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.support_agent, color: AppTheme.gold),
            SizedBox(width: 8),
            Text('Support Tontetic'),
          ],
        ),
        backgroundColor: AppTheme.marineBlue,
        actions: [
          Tooltip(
            message: 'Ce chat est là pour vous accompagner dans vos projets solidaires.',
            triggerMode: TooltipTriggerMode.tap,
            child: IconButton(icon: const Icon(Icons.info_outline, color: AppTheme.gold), onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ce chat est là pour vous accompagner dans vos projets solidaires.')))),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _activeTicketId == null 
                ? _buildEmptyState() 
                : StreamBuilder<QuerySnapshot>(
                    stream: _messagesStream,
                    builder: (context, snapshot) {
                      if (snapshot.hasError) return Center(child: Text('Erreur: ${snapshot.error}'));
                      if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

                      final docs = snapshot.data!.docs;
                      if (docs.isEmpty) return _buildEmptyState();

                      return ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: docs.length,
                        itemBuilder: (context, index) {
                          final data = docs[index].data() as Map<String, dynamic>;
                          final isMe = data['isStaff'] != true; // Default to me if not explicitly staff
                          
                          // Format time
                          String timeStr = '';
                          if (data['timestamp'] != null) {
                            final dt = (data['timestamp'] as Timestamp).toDate();
                            timeStr = '${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
                          }

                          return Align(
                            alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              decoration: BoxDecoration(
                                color: isMe 
                                    ? AppTheme.marineBlue 
                                    : (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF2C2C2C) : Colors.grey[200]),
                                borderRadius: BorderRadius.only(
                                  topLeft: const Radius.circular(12),
                                  topRight: const Radius.circular(12),
                                  bottomLeft: isMe ? const Radius.circular(12) : Radius.zero,
                                  bottomRight: isMe ? Radius.zero : const Radius.circular(12),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    data['text'] ?? '',
                                    style: TextStyle(color: isMe ? AppTheme.gold : (Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87)),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    timeStr,
                                    style: TextStyle(fontSize: 10, color: isMe ? Colors.white54 : Colors.grey),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
          ),
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text('Commencez une discussion avec le support', style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildInputArea() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        boxShadow: [BoxShadow(color: isDark ? Colors.black26 : Colors.grey.shade200, offset: const Offset(0, -2), blurRadius: 4)],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              style: TextStyle(color: isDark ? Colors.white : Colors.black87),
              decoration: InputDecoration(
                hintText: 'Écrivez votre message...',
                hintStyle: TextStyle(color: isDark ? Colors.white38 : Colors.grey[500]),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                filled: true,
                fillColor: isDark ? const Color(0xFF2C2C2C) : Colors.grey[100],
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              ),
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          const SizedBox(width: 8),
          CircleAvatar(
            backgroundColor: AppTheme.marineBlue,
            child: IconButton(
              icon: const Icon(Icons.send, color: AppTheme.gold, size: 20),
              onPressed: _sendMessage,
            ),
          ),
        ],
      ),
    );
  }
}
