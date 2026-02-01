import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tontetic/core/theme/app_theme.dart';
import 'package:tontetic/core/providers/user_provider.dart';
import 'package:tontetic/core/services/storage_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
// Ensure permission handling
import 'package:path_provider/path_provider.dart';

/// V15: Circle Chat Screen
/// Allows members to discuss before voting on payout order

class CircleChatScreen extends ConsumerStatefulWidget {
  final String circleName;
  final String circleId;
  
  const CircleChatScreen({
    super.key,
    required this.circleName,
    required this.circleId,
  });

  @override
  ConsumerState<CircleChatScreen> createState() => _CircleChatScreenState();
}

class _CircleChatScreenState extends ConsumerState<CircleChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  // Audio Recording
  final AudioRecorder _audioRecorder = AudioRecorder();
  final AudioPlayer _audioPlayer = AudioPlayer(); // For playback
  bool _isRecording = false;
  String? _recordingPath;
  
  // Upload State
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    // Preload permissions if possible or wait for action
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }
  


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.circleName, style: const TextStyle(fontSize: 16)),
            const Text('Discussion du cercle', style: TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.how_to_vote),
            tooltip: 'Voter pour l\'ordre',
            onPressed: () => _navigateToVoting(),
          ),
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () => _showChatRules(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Voting reminder banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: AppTheme.gold.withValues(alpha: 0.2),
            child: Row(
              children: [
                const Icon(Icons.how_to_vote, color: AppTheme.marineBlue, size: 20),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Discutez avant de voter ! Le vote sera ouvert une fois le cercle complet.',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                ),
                TextButton(
                  onPressed: () => _navigateToVoting(),
                  child: const Text('VOTER', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
          
          // Real Firestore Messages
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('tontines')
                  .doc(widget.circleId)
                  .collection('messages')
                  .orderBy('timestamp', descending: false)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(child: Text('Erreur de chargement'));
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data?.docs ?? [];
                
                if (docs.isEmpty) {
                   return const Center(
                     child: Padding(
                       padding: EdgeInsets.all(32.0),
                       child: Column(
                         mainAxisAlignment: MainAxisAlignment.center,
                         children: [
                           Icon(Icons.chat_bubble_outline, size: 48, color: Colors.grey),
                           SizedBox(height: 16),
                           Text(
                             "Aucun message pour le moment.\nSoyez le premier à écrire !",
                             textAlign: TextAlign.center,
                             style: TextStyle(color: Colors.grey),
                           ),
                         ],
                       ),
                     ),
                   );
                }

                // Scroll to bottom on new message
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (_scrollController.hasClients) {
                    _scrollController.animateTo(
                      _scrollController.position.maxScrollExtent,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOut,
                    );
                  }
                });

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                     final data = docs[index].data() as Map<String, dynamic>;
                     final user = ref.read(userProvider);
                     final isMe = data['senderId'] == user.uid;
                     
                     // Adapter for _buildMessageBubble
                     final msgMap = {
                       'id': docs[index].id,
                       'senderId': data['senderId'],
                       'senderName': data['senderName'] ?? 'Membre',
                       'text': data['text'] ?? '',
                       'type': data['type'] ?? 'text',
                       'url': data['url'],
                       'fileName': data['fileName'],
                       'timestamp': data['timestamp'] != null 
                           ? (data['timestamp'] as Timestamp).toDate() 
                           : DateTime.now(),
                       'isMe': isMe,
                     };
                     
                     return _buildMessageBubble(msgMap);
                  },
                );
              },
            ),
          ),
          
          // Input field
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
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
                     Text('Enregistrement... (Relâcher pour envoyer)', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                   ],
                 ),
               ),
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.attach_file, color: Colors.grey),
                  onPressed: _isUploading ? null : _pickFile,
                ),
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    onChanged: (v) => setState((){}), 
                    decoration: InputDecoration(
                      hintText: 'Message...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                    maxLines: null,
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onLongPress: _startRecording,
                  onLongPressUp: _stopRecording,
                  child: CircleAvatar(
                    backgroundColor: _messageController.text.isNotEmpty ? AppTheme.marineBlue : (_isRecording ? Colors.red : AppTheme.gold),
                    child: _isUploading 
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : IconButton(
                        icon: Icon(
                          _messageController.text.isNotEmpty ? Icons.send : Icons.mic, 
                          color: _messageController.text.isNotEmpty ? Colors.white : AppTheme.marineBlue, 
                          size: 20
                        ),
                        onPressed: _messageController.text.isNotEmpty ? _sendMessage : () {
                           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Maintenez pour enregistrer un vocal 🎤')));
                        },
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


  Widget _buildMessageBubble(Map<String, dynamic> message) {
    final isMe = message['isMe'] as bool;
    final timestamp = message['timestamp'] as DateTime;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: AppTheme.gold,
              child: Text(
                (message['senderName'] as String).substring(0, 1),
                style: const TextStyle(color: AppTheme.marineBlue, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isMe ? AppTheme.marineBlue : Colors.grey.shade200,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: isMe ? const Radius.circular(16) : Radius.zero,
                  bottomRight: isMe ? Radius.zero : const Radius.circular(16),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!isMe)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        message['senderName'],
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: AppTheme.marineBlue,
                        ),
                      ),
                    ),
                  
                  // Render Content based on Type
                  if (message['type'] == 'text')
                    Text(
                      message['text'],
                      style: TextStyle(color: isMe ? Colors.white : Colors.black87),
                    )
                  else if (message['type'] == 'image')
                    GestureDetector(
                      onTap: () => showDialog(
                        context: context, 
                        builder: (_) => Dialog(child: Image.network(message['url']))
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          message['url'],
                          height: 150,
                          width: 150,
                          fit: BoxFit.cover,
                          loadingBuilder: (c, w, l) => l == null ? w : const SizedBox(height: 150, width: 150, child: Center(child: CircularProgressIndicator())),
                        ),
                      ),
                    )
                  else if (message['type'] == 'audio')
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.play_circle_fill),
                          color: isMe ? Colors.white : AppTheme.marineBlue,
                          iconSize: 32,
                          onPressed: () => _audioPlayer.play(UrlSource(message['url'])),
                        ),
                        const SizedBox(width: 4),
                         // waveform mockup
                         SizedBox(
                           width: 80, 
                           height: 20, 
                           child: Row(
                             mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                             children: List.generate(10, (i) => Container(
                               width: 3, 
                               height: 10 + (i % 3) * 5.0, 
                               color: isMe ? Colors.white70 : Colors.grey
                             )),
                           )
                         ),
                      ],
                    )
                  else if (message['type'] == 'file')
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.insert_drive_file, color: isMe ? Colors.white : Colors.grey),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            message['fileName'] ?? 'Fichier',
                            style: TextStyle(
                                color: isMe ? Colors.white : Colors.black87,
                                decoration: TextDecoration.underline
                            ),
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 4),
                  Text(
                    _formatTime(timestamp),
                    style: TextStyle(
                      fontSize: 10,
                      color: isMe ? Colors.white60 : Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime timestamp) {
    final now = DateTime.now();
    final diff = now.difference(timestamp);
    
    if (diff.inMinutes < 1) return 'À l\'instant';
    if (diff.inMinutes < 60) return 'Il y a ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'Il y a ${diff.inHours}h';
    return '${timestamp.day}/${timestamp.month}';
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final user = ref.read(userProvider);
    _messageController.clear(); // Optimistic clear

    try {
      await FirebaseFirestore.instance
          .collection('tontines')
          .doc(widget.circleId)
          .collection('messages')
          .add({
        'senderId': user.uid,
        'senderName': user.displayName.isNotEmpty ? user.displayName : 'Membre',
        'text': text,
        'type': 'text',
        'timestamp': FieldValue.serverTimestamp(),
      });
      // Scroll handled by StreamBuilder listener
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur d\'envoi: $e')),
        );
      }
    }
  }
  
  // Multimedia Logic
  
  Future<void> _startRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        final directory = await getTemporaryDirectory();
        final path = '${directory.path}/audio_${DateTime.now().millisecondsSinceEpoch}.m4a';
        
        await _audioRecorder.start(const RecordConfig(), path: path);
        setState(() {
          _isRecording = true;
          _recordingPath = path;
        });
      }
    } catch (e) {
      debugPrint('Error starting record: $e');
    }
  }

  Future<void> _stopRecording() async {
    try {
      final path = await _audioRecorder.stop();
      setState(() => _isRecording = false);
      
      if (path != null) {
        final file = File(path);
        await _uploadAndSend(file, 'audio');
      }
    } catch (e) {
      debugPrint('Error stopping record: $e');
    }
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles();
      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        final extension = result.files.single.extension?.toLowerCase();
        final type = ['jpg', 'jpeg', 'png', 'gif'].contains(extension) ? 'image' : 'file';
        
        await _uploadAndSend(file, type);
      }
    } catch (e) {
      debugPrint('Error picking file: $e');
    }
  }

  Future<void> _uploadAndSend(File file, String type) async {
    setState(() => _isUploading = true);
    final user = ref.read(userProvider);
    final storage = StorageService(); // Use simple instance or provider

    try {
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${file.uri.pathSegments.last}';
      final path = 'tontines/${widget.circleId}/chat/$fileName';
      
      final downloadUrl = await storage.uploadFile(path, file);
      
      await FirebaseFirestore.instance
          .collection('tontines')
          .doc(widget.circleId)
          .collection('messages')
          .add({
        'senderId': user.uid,
        'senderName': user.displayName.isNotEmpty ? user.displayName : 'Membre',
        'type': type,
        'url': downloadUrl,
        'fileName': type == 'file' ? file.uri.pathSegments.last : null,
        'timestamp': FieldValue.serverTimestamp(),
      });
      
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur d\'upload: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }
  
  // Helper for path_provider removed - now using path_provider package directly


  void _navigateToVoting() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PayoutOrderVotingScreen(
          circleName: widget.circleName,
          circleId: widget.circleId,
        ),
      ),
    );
  }

  void _showChatRules() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.gavel, color: AppTheme.marineBlue),
            SizedBox(width: 8),
            Text('Règles du chat'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('✅ Discutez de l\'ordre des pots'),
            SizedBox(height: 8),
            Text('✅ Exprimez vos besoins et projets'),
            SizedBox(height: 8),
            Text('✅ Respectez les autres membres'),
            SizedBox(height: 16),
            Text('❌ Pas de pression sur les votes'),
            SizedBox(height: 8),
            Text('❌ Pas de propos offensants'),
            SizedBox(height: 16),
            Text(
              '⚠️ Les messages sont archivés pour la transparence.',
              style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('COMPRIS'),
          ),
        ],
      ),
    );
  }
}

/// V15: Payout Order Voting Screen
/// Drag & Drop ranking with Borda count method

class VotingMember {
  final String id;
  final String name;
  final String avatar; // Emoji or URL
  final int honorScore;

  VotingMember({
    required this.id, 
    required this.name, 
    required this.avatar, 
    required this.honorScore
  });
}

class PayoutOrderVotingScreen extends ConsumerStatefulWidget {
  final String circleName;
  final String circleId;
  
  const PayoutOrderVotingScreen({
    super.key,
    required this.circleName,
    required this.circleId,
  });

  @override
  ConsumerState<PayoutOrderVotingScreen> createState() => _PayoutOrderVotingScreenState();
}

class _PayoutOrderVotingScreenState extends ConsumerState<PayoutOrderVotingScreen> {
  bool _hasVoted = false;
  bool _isSubmitting = false;
  
  List<VotingMember> _ranking = [];

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  Future<void> _loadMembers() async {
    try {
      final user = ref.read(userProvider);
      
      // Check if already voted
      final voteDoc = await FirebaseFirestore.instance
          .collection('tontines')
          .doc(widget.circleId)
          .collection('votes')
          .doc(user.uid)
          .get();
      
      if (voteDoc.exists && mounted) {
        setState(() {
          _hasVoted = true;
        });
      }

      final circleDoc = await FirebaseFirestore.instance
          .collection('tontines')
          .doc(widget.circleId)
          .get();

      if (!circleDoc.exists) return;

      final memberIds = List<String>.from(circleDoc.data()?['memberIds'] ?? []);
      final List<VotingMember> loadedMembers = [];

      for (String uid in memberIds) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .get();
        
        if (userDoc.exists) {
          final userData = userDoc.data()!;
          loadedMembers.add(VotingMember(
            id: uid,
            name: userData['displayName'] ?? 'Membre',
            avatar: '👤', // Default avatar
            honorScore: userData['honorScore'] ?? 100,
          ));
        }
      }

      if (mounted) {
        setState(() {
          _ranking = loadedMembers;
        });
      }
    } catch (e) {
      debugPrint('Error loading members: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vote: Ordre des Pots'),
      ),
      body: _hasVoted ? _buildVoteConfirmation() : _buildVotingInterface(),
    );
  }

  Widget _buildVotingInterface() {
    return Column(
      children: [
        // Instructions banner
        Container(
          padding: const EdgeInsets.all(16),
          color: AppTheme.marineBlue.withValues(alpha: 0.1),
          child: Column(
            children: [
              const Row(
                children: [
                  Icon(Icons.info_outline, color: AppTheme.marineBlue),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Classez les membres par ordre de priorité pour recevoir le pot.',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                '1 = Premier à recevoir le pot\nGlissez-déposez pour réorganiser.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
        
        // Warning
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.orange.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.orange.shade300),
          ),
          child: const Row(
            children: [
              Icon(Icons.warning_amber, color: Colors.orange),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  '⚠️ Votre vote est DÉFINITIF et ne peut pas être modifié.',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
        
        // Ranking list with drag & drop
        Expanded(
          child: ReorderableListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _ranking.length,
            itemBuilder: (context, index) {
              final member = _ranking[index];
              return _buildRankingTile(member, index);
            },
            onReorder: (oldIndex, newIndex) {
              setState(() {
                if (newIndex > oldIndex) newIndex--;
                final item = _ranking.removeAt(oldIndex);
                _ranking.insert(newIndex, item);
              });
            },
          ),
        ),
        
        // Submit button
        Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Borda explanation
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.calculate, size: 20, color: Colors.grey),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Méthode Borda : Chaque rang attribue des points. L\'ordre final est calculé par le total des points de tous les votes.',
                        style: TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  icon: _isSubmitting 
                    ? const SizedBox(
                        width: 20, 
                        height: 20, 
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)
                      )
                    : const Icon(Icons.how_to_vote),
                  label: Text(_isSubmitting ? 'ENVOI EN COURS...' : 'VALIDER MON CLASSEMENT'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.gold,
                    foregroundColor: AppTheme.marineBlue,
                  ),
                  onPressed: _isSubmitting ? null : _submitVote,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRankingTile(VotingMember member, int index) {
    final user = ref.read(userProvider);
    final isMe = member.id == user.uid;
    
    return Card(
      key: ValueKey(member.id),
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: index == 0 ? AppTheme.gold : (index == 1 ? Colors.grey.shade400 : (index == 2 ? Colors.brown.shade300 : Colors.grey.shade200)),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  '${index + 1}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: index < 3 ? Colors.white : Colors.black,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(member.avatar, style: const TextStyle(fontSize: 24)),
          ],
        ),
        title: Text(
          member.name,
          style: TextStyle(
            fontWeight: isMe ? FontWeight.bold : FontWeight.normal,
            color: isMe ? AppTheme.marineBlue : null,
          ),
        ),
        subtitle: Row(
          children: [
            const Icon(Icons.star, size: 14, color: AppTheme.gold),
            const SizedBox(width: 4),
            Text('Score: ${member.honorScore}%'),
          ],
        ),
        trailing: const Icon(Icons.drag_handle, color: Colors.grey),
      ),
    );
  }

  Widget _buildVoteConfirmation() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.green.shade100,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check, size: 64, color: Colors.green),
            ),
            const SizedBox(height: 24),
            const Text(
              'Vote enregistré !',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text(
              'Votre classement a été soumis avec succès.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 32),
            
            // Vote summary
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  const Text('Votre classement :', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  ...List.generate(_ranking.length, (index) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 12,
                          backgroundColor: index == 0 ? AppTheme.gold : Colors.grey.shade300,
                          child: Text('${index + 1}', style: const TextStyle(fontSize: 10, color: Colors.white)),
                        ),
                        const SizedBox(width: 12),
                        Text(_ranking[index].name),
                      ],
                    ),
                  )),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Archive info
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.marineBlue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.lock, size: 16, color: AppTheme.marineBlue),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Vote horodaté et archivé de manière sécurisée.',
                      style: TextStyle(fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 32),
            
            // Status
            const Text(
              '⏳ En attente des votes des autres membres...',
              style: TextStyle(color: Colors.orange, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            const Text(
              '2/5 membres ont voté',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
            
            const SizedBox(height: 32),
            
            OutlinedButton.icon(
              icon: const Icon(Icons.arrow_back),
              label: const Text('Retour au cercle'),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  void _submitVote() async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.orange),
            SizedBox(width: 8),
            Text('Confirmer le vote'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Attention : Une fois soumis, votre vote ne peut plus être modifié.',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text('Votre classement :'),
            const SizedBox(height: 8),
            ...List.generate(_ranking.length, (index) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text('${index + 1}. ${_ranking[index].name}'),
            )),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('MODIFIER'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('CONFIRMER'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isSubmitting = true);
    
    try {
      final user = ref.read(userProvider);
      final voteData = {
        'voterId': user.uid,
        'voterName': user.displayName.isNotEmpty ? user.displayName : 'Membre',
        'ranking': _ranking.map((m) => m.id).toList(),
        'timestamp': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance
          .collection('tontines')
          .doc(widget.circleId)
          .collection('votes')
          .doc(user.uid)
          .set(voteData);

      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _hasVoted = true;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Votre vote a été enregistré !')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors du vote: $e')),
        );
      }
    }
  }
}
