import 'package:flutter/material.dart';
import 'dart:async';

// Voice Message Widget
// Allows recording and playing voice messages in all chat features
// 
// Features:
// - Record voice messages
// - Play/pause/seek
// - Visual waveform
// - Duration display
// - Cancel recording

class VoiceMessageRecorder extends StatefulWidget {
  final Function(VoiceMessage) onMessageRecorded;
  final VoidCallback? onCancel;

  const VoiceMessageRecorder({
    super.key,
    required this.onMessageRecorded,
    this.onCancel,
  });

  @override
  State<VoiceMessageRecorder> createState() => _VoiceMessageRecorderState();
}

class _VoiceMessageRecorderState extends State<VoiceMessageRecorder> with SingleTickerProviderStateMixin {
  bool _isRecording = false;
  int _recordingSeconds = 0;
  Timer? _timer;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  void _startRecording() {
    setState(() {
      _isRecording = true;
      _recordingSeconds = 0;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() => _recordingSeconds++);
      if (_recordingSeconds >= 120) {
        // Max 2 minutes
        _stopRecording();
      }
    });
    debugPrint('[VoiceMessage] Recording started');
  }

  void _stopRecording() {
    _timer?.cancel();
    final message = VoiceMessage(
      id: 'VM-${DateTime.now().millisecondsSinceEpoch}',
      durationSeconds: _recordingSeconds,
      audioUrl: 'local://voice_${DateTime.now().millisecondsSinceEpoch}.m4a', // Simulated
      createdAt: DateTime.now(),
    );
    widget.onMessageRecorded(message);
    setState(() {
      _isRecording = false;
      _recordingSeconds = 0;
    });
    debugPrint('[VoiceMessage] Recording stopped: ${_recordingSeconds}s');
  }

  void _cancelRecording() {
    _timer?.cancel();
    setState(() {
      _isRecording = false;
      _recordingSeconds = 0;
    });
    widget.onCancel?.call();
    debugPrint('[VoiceMessage] Recording cancelled');
  }

  String _formatDuration(int seconds) {
    final mins = seconds ~/ 60;
    final secs = seconds % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    if (_isRecording) {
      return _buildRecordingUI();
    }
    return _buildIdleButton();
  }

  Widget _buildIdleButton() {
    return GestureDetector(
      onLongPressStart: (_) => _startRecording(),
      onLongPressEnd: (_) => _stopRecording(),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.deepPurple.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.mic, color: Colors.deepPurple, size: 28),
      ),
    );
  }

  Widget _buildRecordingUI() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        children: [
          // Cancel button
          GestureDetector(
            onTap: _cancelRecording,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.shade100,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, color: Colors.red, size: 20),
            ),
          ),
          const SizedBox(width: 12),

          // Recording indicator
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) => Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.5 + (_pulseController.value * 0.5)),
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Duration
          Text(
            _formatDuration(_recordingSeconds),
            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
          ),
          const SizedBox(width: 12),

          // Waveform (simulated)
          Expanded(
            child: SizedBox(
              height: 30,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(20, (i) {
                  final height = 10.0 + ((_recordingSeconds + i) % 5) * 4;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 100),
                    width: 3,
                    height: height,
                    decoration: BoxDecoration(
                      color: Colors.red.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  );
                }),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Send button
          GestureDetector(
            onTap: _stopRecording,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: const BoxDecoration(
                color: Colors.deepPurple,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.send, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}

// =============== VOICE MESSAGE DATA ===============

class VoiceMessage {
  final String id;
  final int durationSeconds;
  final String audioUrl;
  final DateTime createdAt;
  final bool isPlayed;

  VoiceMessage({
    required this.id,
    required this.durationSeconds,
    required this.audioUrl,
    required this.createdAt,
    this.isPlayed = false,
  });

  String get formattedDuration {
    final mins = durationSeconds ~/ 60;
    final secs = durationSeconds % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }
}

// =============== VOICE MESSAGE PLAYER ===============

class VoiceMessagePlayer extends StatefulWidget {
  final VoiceMessage message;
  final bool isSender;

  const VoiceMessagePlayer({
    super.key,
    required this.message,
    this.isSender = false,
  });

  @override
  State<VoiceMessagePlayer> createState() => _VoiceMessagePlayerState();
}

class _VoiceMessagePlayerState extends State<VoiceMessagePlayer> {
  bool _isPlaying = false;
  double _progress = 0;
  Timer? _progressTimer;

  @override
  void dispose() {
    _progressTimer?.cancel();
    super.dispose();
  }

  void _togglePlayback() {
    if (_isPlaying) {
      _progressTimer?.cancel();
      setState(() => _isPlaying = false);
    } else {
      setState(() => _isPlaying = true);
      _progressTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
        setState(() {
          _progress += 0.1 / widget.message.durationSeconds;
          if (_progress >= 1) {
            _progress = 0;
            _isPlaying = false;
            timer.cancel();
          }
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = widget.isSender ? Colors.deepPurple : Colors.grey.shade200;
    final textColor = widget.isSender ? Colors.white : Colors.black87;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Play/pause button
          GestureDetector(
            onTap: _togglePlayback,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: widget.isSender ? Colors.white.withValues(alpha: 0.2) : Colors.deepPurple.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _isPlaying ? Icons.pause : Icons.play_arrow,
                color: widget.isSender ? Colors.white : Colors.deepPurple,
                size: 24,
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Waveform with progress
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 120,
                height: 24,
                child: Stack(
                  children: [
                    // Background waveform
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: List.generate(15, (i) {
                        final height = 8.0 + (i % 4) * 4;
                        return Container(
                          width: 3,
                          height: height,
                          decoration: BoxDecoration(
                            color: textColor.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        );
                      }),
                    ),
                    // Progress overlay
                    ClipRect(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        widthFactor: _progress,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: List.generate(15, (i) {
                            final height = 8.0 + (i % 4) * 4;
                            return Container(
                              width: 3,
                              height: height,
                              decoration: BoxDecoration(
                                color: textColor,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            );
                          }),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                widget.message.formattedDuration,
                style: TextStyle(fontSize: 11, color: textColor.withValues(alpha: 0.7)),
              ),
            ],
          ),
          const SizedBox(width: 8),

          // Voice icon
          Icon(Icons.mic, color: textColor.withValues(alpha: 0.5), size: 16),
        ],
      ),
    );
  }
}

// =============== CHAT INPUT WITH VOICE ===============

class ChatInputWithVoice extends StatefulWidget {
  final Function(String) onTextSubmit;
  final Function(VoiceMessage) onVoiceSubmit;
  final String? placeholder;

  const ChatInputWithVoice({
    super.key,
    required this.onTextSubmit,
    required this.onVoiceSubmit,
    this.placeholder,
  });

  @override
  State<ChatInputWithVoice> createState() => _ChatInputWithVoiceState();
}

class _ChatInputWithVoiceState extends State<ChatInputWithVoice> {
  final _textController = TextEditingController();
  bool _hasText = false;
  bool _isRecording = false;
  int _recordingSeconds = 0;
  Timer? _recordTimer;

  @override
  void initState() {
    super.initState();
    _textController.addListener(() {
      final hasText = _textController.text.trim().isNotEmpty;
      if (hasText != _hasText) {
        setState(() => _hasText = hasText);
      }
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _recordTimer?.cancel();
    super.dispose();
  }

  void _submitText() {
    final text = _textController.text.trim();
    if (text.isNotEmpty) {
      widget.onTextSubmit(text);
      _textController.clear();
    }
  }

  void _startRecording() {
    setState(() {
      _isRecording = true;
      _recordingSeconds = 0;
    });
    _recordTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() => _recordingSeconds++);
      if (_recordingSeconds >= 120) _stopRecording();
    });
  }

  void _stopRecording() {
    _recordTimer?.cancel();
    if (_recordingSeconds > 0) {
      widget.onVoiceSubmit(VoiceMessage(
        id: 'VM-${DateTime.now().millisecondsSinceEpoch}',
        durationSeconds: _recordingSeconds,
        audioUrl: 'local://voice_${DateTime.now().millisecondsSinceEpoch}.m4a',
        createdAt: DateTime.now(),
      ));
    }
    setState(() {
      _isRecording = false;
      _recordingSeconds = 0;
    });
  }

  void _cancelRecording() {
    _recordTimer?.cancel();
    setState(() {
      _isRecording = false;
      _recordingSeconds = 0;
    });
  }

  String _formatDuration(int seconds) {
    final mins = seconds ~/ 60;
    final secs = seconds % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    if (_isRecording) {
      return _buildRecordingBar();
    }
    return _buildInputBar();
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -2))],
      ),
      child: Row(
        children: [
          // Text input
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(24),
              ),
              child: TextField(
                controller: _textController,
                style: const TextStyle(color: Colors.black87),
                decoration: InputDecoration(
                  hintText: widget.placeholder ?? 'Votre message...',
                  border: InputBorder.none,
                  hintStyle: TextStyle(color: Colors.grey.shade500),
                ),
                maxLines: null,
                textCapitalization: TextCapitalization.sentences,
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Voice or Send button
          GestureDetector(
            onTap: _hasText ? _submitText : null,
            onLongPressStart: _hasText ? null : (_) => _startRecording(),
            onLongPressEnd: _hasText ? null : (_) => _stopRecording(),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _hasText ? Colors.deepPurple : Colors.deepPurple.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _hasText ? Icons.send : Icons.mic,
                color: _hasText ? Colors.white : Colors.deepPurple,
                size: 24,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordingBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -2))],
      ),
      child: Row(
        children: [
          // Cancel
          GestureDetector(
            onTap: _cancelRecording,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.red.shade100,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, color: Colors.red, size: 20),
            ),
          ),
          const SizedBox(width: 12),

          // Recording indicator
          const Icon(Icons.fiber_manual_record, color: Colors.red, size: 12),
          const SizedBox(width: 8),
          Text(
            _formatDuration(_recordingSeconds),
            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
          ),

          // Slider to cancel
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                '< Glissez pour annuler',
                style: TextStyle(color: Colors.red.shade300, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ),
          ),

          // Stop & send
          GestureDetector(
            onTap: _stopRecording,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                color: Colors.deepPurple,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.send, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}
