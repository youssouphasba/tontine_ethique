import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tontetic/core/theme/app_theme.dart';
import 'package:tontetic/features/social/data/social_provider.dart';
import 'package:tontetic/features/social/presentation/screens/profile_screen.dart';

class DirectChatScreen extends ConsumerStatefulWidget {
  final String friendName;
  final String? friendId;
  const DirectChatScreen({super.key, required this.friendName, this.friendId});

  @override
  ConsumerState<DirectChatScreen> createState() => _DirectChatScreenState();
}

class _DirectChatScreenState extends ConsumerState<DirectChatScreen> {
  final TextEditingController _msgController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(socialProvider.notifier).listenToConversation(widget.friendName, widget.friendName);
    });
  }

  @override
  Widget build(BuildContext context) {
    final social = ref.watch(socialProvider);
    final conversation = social.directMessages[widget.friendName] ?? Conversation(friendName: widget.friendName, messages: []);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: AppTheme.gold,
              child: Text(widget.friendName.isNotEmpty ? widget.friendName[0].toUpperCase() : '?', style: const TextStyle(color: AppTheme.marineBlue, fontWeight: FontWeight.bold, fontSize: 14)),
            ),
            const SizedBox(width: 12),
            Text(widget.friendName),
          ],
        ),
        backgroundColor: AppTheme.marineBlue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.info_outline), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileScreen(userName: widget.friendName)))),
        ],
      ),
      body: Column(
        children: [
          // Security Banner (V3.9 requirement)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
            color: Colors.green.withValues(alpha: 0.1),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.lock, size: 12, color: Colors.green),
                const SizedBox(width: 4),
                Text('Les messages sont chiffrés de bout en bout.', style: TextStyle(fontSize: 10, color: Colors.green[800])),
              ],
            ),
          ),
          
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: conversation.messages.length,
              itemBuilder: (context, index) {
                final msg = conversation.messages[index];
                final isMe = msg.senderId == 'me';
                
                if (msg.isInvite) {
                  return _buildInviteCard(msg);
                }

                return _buildMessageBubble(msg, isMe);
              },
            ),
          ),
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage msg, bool isMe) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isMe ? AppTheme.marineBlue : Colors.grey[200],
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMe ? 16 : 0),
            bottomRight: Radius.circular(isMe ? 0 : 16),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (msg.isEncrypted)
              Padding(
                padding: const EdgeInsets.only(right: 4, bottom: 2),
                child: Icon(Icons.lock, size: 12, color: isMe ? Colors.white70 : Colors.grey),
              ),
            Flexible(
              child: Text(
                msg.text,
                style: TextStyle(color: isMe ? Colors.white : Colors.black87),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInviteCard(ChatMessage msg) {
    final circleName = msg.circleData?['name'] ?? 'Tontine';
    final amount = msg.circleData?['amount'] ?? 0;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.gold, width: 2),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
      ),
      child: Column(
        children: [
          const Icon(Icons.mail_outline, color: AppTheme.gold, size: 32),
          const SizedBox(height: 8),
          const Text('Invitation Reçue !', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 4),
          Text(msg.text, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12)),
          const Divider(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(circleName, style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text('${amount.toInt()} FCFA / mois', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
              ElevatedButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Demande d\'adhésion envoyée !')));
                },
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.marineBlue, foregroundColor: Colors.white),
                child: const Text('Rejoindre'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
      ),
      child: SafeArea(
        child: Row(
          children: [
            IconButton(icon: const Icon(Icons.add_a_photo, color: AppTheme.marineBlue), onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('📷 Envoi de photos bientôt disponible !')))),
            Expanded(
              child: TextField(
                controller: _msgController,
                style: const TextStyle(color: Colors.black87),
                decoration: InputDecoration(
                  hintText: 'Votre message...',
                  hintStyle: TextStyle(color: Colors.grey[500]),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                  filled: true,
                  fillColor: Colors.grey[100],
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
              ),
            ),
            const SizedBox(width: 8),
            CircleAvatar(
              backgroundColor: AppTheme.gold,
              child: IconButton(
                icon: const Icon(Icons.send, color: AppTheme.marineBlue),
                onPressed: _handleSend,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleSend() {
    if (_msgController.text.trim().isEmpty) return;
    ref.read(socialProvider.notifier).sendMessage(widget.friendName, widget.friendName, _msgController.text, recipientId: widget.friendId);
    _msgController.clear();
    Future.delayed(const Duration(milliseconds: 100), () {
       _scrollController.animateTo(_scrollController.position.maxScrollExtent, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    });
  }
}
