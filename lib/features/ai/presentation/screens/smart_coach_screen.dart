import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tontetic/core/providers/user_provider.dart';
import 'package:tontetic/core/theme/app_theme.dart';
import 'package:tontetic/core/services/gemini_service.dart';
import 'package:tontetic/core/providers/localization_provider.dart';
import 'package:tontetic/core/services/voice_service.dart';
import 'package:tontetic/core/providers/audio_settings_provider.dart';
import 'package:tontetic/core/presentation/widgets/speaker_icon.dart';
import 'package:tontetic/features/ai/presentation/widgets/voice_consent_dialog.dart';
import 'package:tontetic/features/ai/presentation/widgets/audio_visualizer.dart';
import 'package:tontetic/features/ai/presentation/widgets/pulsating_mic_button.dart';
import 'package:tontetic/core/presentation/widgets/tts_control_toggle.dart';

class SmartCoachScreen extends ConsumerStatefulWidget {
  final String? initialVoiceTranscription;
  const SmartCoachScreen({super.key, this.initialVoiceTranscription});

  @override
  ConsumerState<SmartCoachScreen> createState() => _SmartCoachScreenState();
}

class _SmartCoachScreenState extends ConsumerState<SmartCoachScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  late List<Map<String, dynamic>> _messages;
  bool _isRecording = false;
  bool _isProcessing = false;
  bool _isTyping = false;
  bool _hasVoiceConsent = false;
  int _voiceErrorCount = 0;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    final l10n = ref.read(localizationProvider);
    _messages = [
      {
        'isUser': false,
        'text': l10n.translate('coach_greeting'),
      }
    ];

    if (widget.initialVoiceTranscription != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _sendMessage(widget.initialVoiceTranscription!, fromVoice: true);
      });
    }
  }

  Future<void> _handleVoiceRecording() async {
    final voiceService = ref.read(voiceServiceProvider);

    if (!_hasVoiceConsent) {
      final consented = await showDialog<bool>(
        context: context,
        builder: (context) => const VoiceConsentDialog(),
      );
      if (consented == true) {
        _hasVoiceConsent = true;
      } else {
        return;
      }
    }

    if (!_isRecording) {
      setState(() => _isRecording = true);
      await voiceService.startRecording();
    } else {
      setState(() {
        _isRecording = false;
        _isProcessing = true;
      });
      final audioFile = await voiceService.stopRecording();
      if (audioFile != null) {
        final result = await voiceService.transcribeAudio(audioFile);
        if (mounted) {
          setState(() => _isProcessing = false);
          
          if (result.confidence < 0.6) {
             _handleFallback();
          } else {
             _voiceErrorCount = 0; // Reset on success
             _sendMessage(result.text, fromVoice: true);
          }
        }
      } else {
        setState(() => _isProcessing = false);
      }
    }
  }

  void _handleFallback() {
    final l10n = ref.read(localizationProvider);
    _voiceErrorCount++;
    
    setState(() {
      _messages.add({
        'isUser': false,
        'text': l10n.translate('voice_fallback_msg'),
        'type': 'voice_fallback',
        'errorTip': _voiceErrorCount >= 2 ? l10n.translate('voice_tip') : null,
      });
    });
    _scrollToBottom();
  }

  void _sendMessage(String text, {bool fromVoice = false}) {
    if (text.trim().isEmpty) return;

    final l10n = ref.read(localizationProvider);
    final processedText = fromVoice 
        ? "${l10n.translate('voice_understood')} \"$text\""
        : text;

    setState(() {
      _messages.add({'isUser': true, 'text': processedText});
      _isTyping = true;
    });
    _controller.clear();
    _scrollToBottom();

    // AI Response (Direct call to service which handles API latency)
    _getAIResponse(text);
  }

  Future<void> _getAIResponse(String input) async {
    // 1. Check for specific UI Triggers first (Hybrid approach)
    final lower = input.toLowerCase();
    String? type;

    if (lower.contains('quel cercle') || lower.contains('choisir') || lower.contains('conseil') || lower.contains('recommand')) {
      type = 'carousel';
    } 
    
    if (lower.contains('combien') || lower.contains('calcul') || lower.contains('capacité')) {
       _showBudgetCalculator();

       setState(() {
         _isTyping = false;
         _messages.add({'isUser': false, 'text': "C'est parti pour le calcul ! 🧮", 'type': null});
       });
       return; 
    }

    // 2. Call Gemini for the Text Response
    final user = ref.read(userProvider);
    final profileContext = "Revenus: ${user.isPremium ? 'Élevés' : 'Moyens'}, Zone: ${user.zone.label}, Métier: ${user.jobTitle}";
    
    final aiResponseText = await ref.read(geminiServiceProvider)
        .getCounsel(input, userProfileContext: profileContext, language: ref.read(localizationProvider).language.name);

    if (mounted) {
      final l10n = ref.read(localizationProvider);
      setState(() {
        _isTyping = false;
        _messages.add({
          'isUser': false, 
          'text': aiResponseText,
          'type': type 
        });
      });
      _scrollToBottom();
      
      // V11.28: Only auto-play if enabled globally
      if (ref.read(audioSettingsProvider)) {
        ref.read(voiceServiceProvider).speakText(aiResponseText, l10n.language);
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.psychology_alt, color: Colors.white),
            SizedBox(width: 8),
            Text('Tontii (Coach)'),
          ],
        ),
        backgroundColor: AppTheme.marineBlue,
        actions: [
          const TTSControlToggle(),
        ],
      ),
      body: Column(
        children: [
          // Chat List
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length + (_isTyping ? 1 : 0),
              itemBuilder: (context, index) {
                if (_isTyping && index == _messages.length) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Row(
                      children: [
                        CircleAvatar(backgroundColor: AppTheme.gold, radius: 16, child: Icon(Icons.psychology_alt, size: 16, color: Colors.white)),
                        const SizedBox(width: 8),
                        Text(
                          ref.watch(localizationProvider).translate('tontii_typing'),
                          style: const TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }
                final msg = _messages[index];
                final isUser = msg['isUser'];
                return Align(
                  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding: const EdgeInsets.all(12),
                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                    decoration: BoxDecoration(
                      color: isUser ? AppTheme.gold.withAlpha(51) : Colors.grey[100],
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(16),
                        topRight: const Radius.circular(16),
                        bottomLeft: Radius.circular(isUser ? 16 : 0),
                        bottomRight: Radius.circular(isUser ? 0 : 16),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (!isUser)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                "Tontii",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: AppTheme.gold,
                                ),
                              ),
                              SpeakerIcon(text: msg['text'] ?? "", size: 16),
                            ],
                          ),
                        if (!isUser) const SizedBox(height: 4),
                        Text(
                          msg['text'] ?? "",
                          style: TextStyle(
                            color: isUser ? Colors.brown[900] : Colors.black87,
                          ),
                        ),
                        if (msg['errorTip'] != null)
                           Padding(
                             padding: const EdgeInsets.only(top: 8.0),
                             child: Text(
                               msg['errorTip'],
                               style: const TextStyle(fontSize: 12, color: AppTheme.emeraldGreen, fontWeight: FontWeight.bold),
                             ),
                           ),
                        if (msg['type'] == 'carousel')
                          _buildTontineCarousel(),
                        if (msg['type'] == 'voice_fallback')
                          _buildFallbackActions(),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          
          // Suggestions (Quick Actions)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _buildSuggestionChip('Quel cercle pour moi ? 💰'),
                const SizedBox(width: 8),
                _buildSuggestionChip('Explique la garantie 🛡️'),
                const SizedBox(width: 8),
                _buildSuggestionChip('Comment bloquer mon épargne ? 🔒'),
              ],
            ),
          ),

          // Input Area
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Colors.grey[200]!))),
            child: Row(
              children: [
                Expanded(
                  child: _isRecording 
                      ? Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              ref.watch(localizationProvider).translate('voice_listening'),
                              style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.emeraldGreen, fontSize: 12),
                            ),
                            const SizedBox(height: 8),
                            AudioVisualizer(isRecording: _isRecording),
                            const SizedBox(height: 4),
                            Text(
                              ref.watch(localizationProvider).translate('voice_privacy_note'),
                              style: const TextStyle(fontSize: 9, color: Colors.grey),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        )
                      : TextField(
                          controller: _controller,
                          focusNode: _focusNode,
                          style: const TextStyle(color: Colors.black87),
                          decoration: InputDecoration(
                            hintText: ref.watch(localizationProvider).translate('ask_question'),
                            hintStyle: TextStyle(color: Colors.grey[500]),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                            filled: true,
                            fillColor: Colors.grey[100],
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          ),
                          onSubmitted: (val) => _sendMessage(val),
                        ),
                ),
                const SizedBox(width: 8),
                PulsatingMicButton(
                  isRecording: _isRecording,
                  isProcessing: _isProcessing,
                  onTap: _handleVoiceRecording,
                ),
                if (!_isRecording && !_isProcessing) ...[
                  const SizedBox(width: 8),
                  CircleAvatar(
                    backgroundColor: AppTheme.gold,
                    child: IconButton(
                      icon: const Icon(Icons.send, color: Colors.white, size: 20),
                      onPressed: () => _sendMessage(_controller.text),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- RICH UI WIDGETS ---

  Widget _buildTontineCarousel() {
    final tontines = [
      {'name': 'Épargne Pro', 'price': '50,000 FCFA', 'gain': '500,000 FCFA', 'icon': Icons.business_center, 'color': Colors.blue},
      {'name': 'Tabaski Zen', 'price': '25,000 FCFA', 'gain': '250,000 FCFA', 'icon': Icons.mosque, 'color': Colors.green},
      {'name': 'Voyage 2024', 'price': '100,000 FCFA', 'gain': '1,000,000 FCFA', 'icon': Icons.flight, 'color': Colors.orange},
    ];

    return Container(
      height: 160,
      margin: const EdgeInsets.only(top: 8, bottom: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: tontines.length,
        itemBuilder: (context, index) {
          final t = tontines[index];
          return Container(
            width: 140,
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: (t['color'] as Color).withValues(alpha: 0.3)),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2))],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircleAvatar(backgroundColor: (t['color'] as Color).withValues(alpha: 0.1), child: Icon(t['icon'] as IconData, color: t['color'] as Color)),
                const SizedBox(height: 8),
                Text(t['name'] as String, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), textAlign: TextAlign.center),
                const SizedBox(height: 4),
                Text(t['price'] as String, style: const TextStyle(fontWeight: FontWeight.w600, color: AppTheme.marineBlue, fontSize: 12)),
                const SizedBox(height: 8),
                SizedBox(
                  height: 28,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.marineBlue, padding: const EdgeInsets.symmetric(horizontal: 8)),
                    onPressed: () {
                      _sendMessage("Je suis intéressé par ${t['name']}");
                    },
                    child: const Text('Voir', style: TextStyle(fontSize: 10)),
                  ),
                )
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildFallbackActions() {
    final l10n = ref.read(localizationProvider);
    return Padding(
      padding: const EdgeInsets.only(top: 12.0),
      child: Row(
        children: [
          ElevatedButton.icon(
            onPressed: _handleVoiceRecording,
            icon: const Icon(Icons.mic, size: 16),
            label: Text(l10n.translate('voice_repeat')),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.emeraldGreen,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: () {
              _focusNode.requestFocus();
            },
            icon: const Icon(Icons.keyboard, size: 16),
            label: Text(l10n.translate('voice_write')),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
          ),
        ],
      ),
    );
  }

  void _showBudgetCalculator() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 24),
            const Text('Calculateur de Capacité 🧮', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.marineBlue)),
            const SizedBox(height: 8),
            const Text('Entrez vos revenus mensuels pour une recommandation 50/30/20.', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 24),
            const TextField(
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Revenus Mensuels (FCFA)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.monetization_on),
              ),
            ),
            const SizedBox(height: 16),
            const TextField(
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Dépenses Fixes (Loyer, etc.)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.home),
              ),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.marineBlue, padding: const EdgeInsets.symmetric(vertical: 16)),
                onPressed: () {
                  Navigator.pop(ctx);
                  _sendMessage("J'ai fait le calcul. J'ai une capacité de 75,000 FCFA.");
                },
                child: const Text('CALCULER MON POTENTIEL'),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestionChip(String text) {
    return ActionChip(
      label: Text(text, style: const TextStyle(fontSize: 12, color: AppTheme.marineBlue)),
      backgroundColor: AppTheme.gold.withValues(alpha: 0.1),
      side: BorderSide.none,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      onPressed: () => _sendMessage(text),
    );
  }
}

