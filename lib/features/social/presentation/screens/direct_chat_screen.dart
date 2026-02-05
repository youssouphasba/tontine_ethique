import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:tontetic/core/theme/app_theme.dart';
import 'package:tontetic/core/services/chat_service.dart';
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
  final AudioRecorder _audioRecorder = AudioRecorder();
  final AudioPlayer _audioPlayer = AudioPlayer();
  final ChatService _chatService = ChatService();

  bool _isRecording = false;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.friendId != null && widget.friendId != 'demo_merchant') {
        ref.read(socialProvider.notifier).listenToConversation(widget.friendName, widget.friendId!);
      }
    });
  }

  @override
  void dispose() {
    _msgController.dispose();
    _scrollController.dispose();
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  String? get _currentUserId => FirebaseAuth.instance.currentUser?.uid;

  Future<void> _startRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        final directory = await getTemporaryDirectory();
        final path = '${directory.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';

        await _audioRecorder.start(const RecordConfig(), path: path);
        setState(() => _isRecording = true);
      }
    } catch (e) {
      debugPrint('Error starting recording: $e');
    }
  }

  Future<void> _stopRecording() async {
    try {
      final path = await _audioRecorder.stop();
      setState(() => _isRecording = false);

      if (path != null && widget.friendId != null && _currentUserId != null) {
        await _sendMediaMessage(File(path), 'audio');
      }
    } catch (e) {
      debugPrint('Error stopping recording: $e');
    }
  }

  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(source: ImageSource.gallery, maxWidth: 1024, imageQuality: 80);

      if (image != null && widget.friendId != null && _currentUserId != null) {
        await _sendMediaMessage(File(image.path), 'image');
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
    }
  }

  Future<void> _sendMediaMessage(File file, String type) async {
    if (widget.friendId == null || _currentUserId == null) return;

    setState(() => _isUploading = true);

    try {
      final conversationId = ChatService.getCanonicalId(_currentUserId!, widget.friendId!);

      await _chatService.sendMediaMessage(
        conversationId: conversationId,
        senderId: _currentUserId!,
        recipientId: widget.friendId!,
        file: file,
        mediaType: type,
        senderName: FirebaseAuth.instance.currentUser?.displayName,
        recipientName: widget.friendName,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(type == 'audio' ? '🎤 Message vocal envoyé' : '📷 Image envoyée'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
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
        child: _buildMessageContent(msg, isMe),
      ),
    );
  }

  Widget _buildMessageContent(ChatMessage msg, bool isMe) {
    // Audio message
    if (msg.type == 'audio' && msg.url != null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.play_circle_fill),
            color: isMe ? Colors.white : AppTheme.marineBlue,
            iconSize: 32,
            onPressed: () => _audioPlayer.play(UrlSource(msg.url!)),
          ),
          const SizedBox(width: 4),
          SizedBox(
            width: 80,
            height: 20,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(10, (i) => Container(
                width: 3,
                height: 10 + (i % 3) * 5.0,
                color: isMe ? Colors.white70 : Colors.grey,
              )),
            ),
          ),
        ],
      );
    }

    // Image message
    if (msg.type == 'image' && msg.url != null) {
      return GestureDetector(
        onTap: () => showDialog(
          context: context,
          builder: (_) => Dialog(child: Image.network(msg.url!)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(
            msg.url!,
            height: 150,
            width: 150,
            fit: BoxFit.cover,
            loadingBuilder: (c, w, l) => l == null ? w : const SizedBox(
              height: 150,
              width: 150,
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
        ),
      );
    }

    // File message
    if (msg.type == 'file' && msg.url != null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.insert_drive_file, color: isMe ? Colors.white : Colors.grey),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              msg.fileName ?? 'Fichier',
              style: TextStyle(
                color: isMe ? Colors.white : Colors.black87,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ],
      );
    }

    // Text message (default)
    return Row(
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_isRecording)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.mic, color: Colors.red, size: 16),
                    SizedBox(width: 8),
                    Text('Enregistrement... (Relâcher pour envoyer)', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 12)),
                  ],
                ),
              ),
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.add_a_photo, color: AppTheme.marineBlue),
                  onPressed: _isUploading ? null : _pickImage,
                ),
                Expanded(
                  child: TextField(
                    controller: _msgController,
                    onChanged: (_) => setState(() {}),
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
                GestureDetector(
                  onLongPress: _startRecording,
                  onLongPressUp: _stopRecording,
                  child: CircleAvatar(
                    backgroundColor: _msgController.text.isNotEmpty
                        ? AppTheme.marineBlue
                        : (_isRecording ? Colors.red : AppTheme.gold),
                    child: _isUploading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : IconButton(
                            icon: Icon(
                              _msgController.text.isNotEmpty ? Icons.send : Icons.mic,
                              color: _msgController.text.isNotEmpty ? Colors.white : AppTheme.marineBlue,
                              size: 20,
                            ),
                            onPressed: _msgController.text.isNotEmpty
                                ? _handleSend
                                : () => ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('🎤 Maintenez pour enregistrer un vocal')),
                                  ),
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _handleSend() {
    if (_msgController.text.trim().isEmpty) return;
    
    if (widget.friendId == null) {
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erreur: ID ami introuvable')));
       return;
    }

    if (widget.friendId == 'demo_merchant') {
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Mode démo: message non envoyé.')));
       _msgController.clear();
       return;
    }

    ref.read(socialProvider.notifier).sendMessage(widget.friendName, widget.friendId!, _msgController.text);
    _msgController.clear();
    Future.delayed(const Duration(milliseconds: 100), () {
       if (_scrollController.hasClients) {
         _scrollController.animateTo(_scrollController.position.maxScrollExtent, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
       }
    });
  }
}
