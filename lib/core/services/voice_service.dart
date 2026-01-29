import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
// import 'dart:io'; // Removed
import 'dart:convert';
import 'package:image_picker/image_picker.dart'; // For XFile
import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:tontetic/core/providers/localization_provider.dart';
import 'package:tontetic/core/services/wolof_audio_service.dart';
import 'package:path_provider/path_provider.dart';

// V11.31: Conditional import for record package (mobile only)
import 'package:record/record.dart' if (dart.library.html) 'voice_service_stub.dart';

class TranscriptionResult {
  final String text;
  final double confidence;

  TranscriptionResult(this.text, this.confidence);
}

class VoiceService {
  final AudioPlayer _audioPlayer = AudioPlayer();
  final WolofAudioService _wolofService;
  bool _isRecording = false;
  bool get isRecording => _isRecording;
  
  // V11.31: Only init recorder on mobile
  AudioRecorder? _recorder;
  String? _currentRecordingPath;

  VoiceService(this._wolofService) {
    // Init recorder on supported platforms
    if (_isSupportedPlatform()) {
      _recorder = AudioRecorder();
    }
  }

  bool _isSupportedPlatform() {
    if (kIsWeb) return false;
    return true; // record package supports Android, iOS, Windows, macOS, Linux
  }

  // Quota Management: Max 1M characters for free tier
  static int _totalCharactersUsed = 0;
  static const int _maxFreeCharacters = 1000000;

  Future<void> startRecording() async {
    await HapticFeedback.lightImpact();
    
    // Check for platform support
    if (!_isSupportedPlatform()) {
      debugPrint("VoiceService: Platform not supported for real recording (Web/Stub)");
      _isRecording = true;
      return;
    }

    try {
      if (_recorder != null && await _recorder!.hasPermission()) {
        final directory = await getTemporaryDirectory();
        _currentRecordingPath = '${directory.path}/voice_capture_${DateTime.now().millisecondsSinceEpoch}.wav';
        
        // V11.30: Configure for Google STT (PCM 16-bit, 16kHz)
        const config = RecordConfig(
          encoder: AudioEncoder.wav,
          sampleRate: 16000,
          numChannels: 1,
        );

        await _recorder!.start(config, path: _currentRecordingPath!);
        _isRecording = true;
      }
    } catch (e) {
      debugPrint("Start Recording Error: $e");
    }
  }

  Future<XFile?> stopRecording() async {
    await HapticFeedback.mediumImpact();
    _isRecording = false;
    
    // Check for platform support
    if (!_isSupportedPlatform()) {
      return null;
    }

    try {
      final path = await _recorder?.stop();
      _isRecording = false;
      
      if (path != null) {
        return XFile(path);
      }
    } catch (e) {
      debugPrint("Stop Recording Error: $e");
    }
    return null;
  }

  Future<TranscriptionResult> transcribeAudio(XFile audioFile) async {
    final apiKey = dotenv.env['GOOGLE_CLOUD_API_KEY'];
    if (apiKey == null) {
      return TranscriptionResult("API Key missing", 0.0);
    }

    // V11.25: Real Google STT Integration
    try {
      // Note: check exists via reading bytes, XFile doesn't support exists() synchronously
      final bytes = await audioFile.readAsBytes();
      if (bytes.isEmpty) {
        return TranscriptionResult("Audio file empty", 0.0);
      }
      final base64Audio = base64Encode(bytes);

      final response = await http.post(
        Uri.parse('https://speech.googleapis.com/v1/speech:recognize?key=$apiKey'),
        body: jsonEncode({
          'config': {
            'encoding': 'LINEAR16', 
            'sampleRateHertz': 16000, 
            'languageCode': 'fr-FR',
            'alternativeLanguageCodes': ['wo-SN'],
            'speechContexts': [{
              'phrases': ['Tontii', 'Tontetic', 'Natt', 'Mbindu'],
              'boost': 20.0,
            }],
          },
          'audio': {'content': base64Audio}
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['results'] != null && data['results'].isNotEmpty) {
           final topResult = data['results'][0]['alternatives'][0];
           return TranscriptionResult(topResult['transcript'], topResult['confidence']);
        }
      }
      
      return TranscriptionResult("Aucune transcription trouvée", 0.0);
    } catch (e) {
      return TranscriptionResult("Erreur STT: $e", 0.0);
    } finally {
      // V11.30: Cleanup temporary file after transcription - XFile cannot delete easily, skipping cleanup for Web compatibility
    }
  }

  Future<void> speakText(String text, AppLanguage language) async {
    final cleanText = _sanitizeText(text);
    if (cleanText.isEmpty) return;

    // V11.26: Handle Wolof separately via Hugging Face (Anta)
    if (language == AppLanguage.wo) {
      final success = await _wolofService.speakWolof(cleanText);
      if (!success) {
        debugPrint("Wolof TTS failed (Timeout/Error). Falling back to visual notification.");
        // In a real app, this would trigger a snackbar or similar UI feedback.
      }
      return;
    }

    if (_totalCharactersUsed + text.length > _maxFreeCharacters) {
      debugPrint("QUOTA EXCEEDED: blocking TTS call to avoid charges.");
      return;
    }

    final apiKey = dotenv.env['GOOGLE_CLOUD_API_KEY'];
    final voiceType = dotenv.env['VOICE_TYPE'] ?? 'Wavenet';
    
    if (apiKey == null) return;

    try {
      // V11.25: Real Google TTS avec Wavenet/Chirp
      String voiceName;
      if (voiceType == 'Chirp3HD') {
        voiceName = 'fr-FR-Chirp3-HD-Aoede';
      } else if (voiceType == 'Wavenet') {
        voiceName = 'fr-FR-Wavenet-D';
      } else {
        voiceName = 'fr-FR-Standard-D';
      }
      
      final url = 'https://texttospeech.googleapis.com/v1/text:synthesize?key=$apiKey';
      
      debugPrint("TTS Request: Using $voiceName for '$text'");
      
      // Update quota
      _totalCharactersUsed += text.length;
      debugPrint("Quota: $_totalCharactersUsed / $_maxFreeCharacters");

      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'input': {'text': cleanText},
          'voice': {'languageCode': 'fr-FR', 'name': voiceName},
          'audioConfig': {
             'audioEncoding': 'MP3',
             'pitch': 0.0,
             'speakingRate': 1.0,
          },
        }),
      );

      if (response.statusCode == 200) {
        final audioContent = jsonDecode(response.body)['audioContent'];
        final bytes = base64Decode(audioContent);
        // Play using audioplayers
        await _audioPlayer.play(BytesSource(bytes));
        debugPrint("TTS: Audio playback started successfully");
      } else {
        debugPrint("TTS Error: ${response.statusCode} - ${response.body}");
      }
    } catch (e) {
      debugPrint("TTS Exception: $e");
    }
  }

  String _sanitizeText(String text) {
    // 1. Remove emojis using a broad unicode range
    String sanitized = text.replaceAll(RegExp(r'[\u{1F600}-\u{1F64F}\u{1F300}-\u{1F5FF}\u{1F680}-\u{1F6FF}\u{1F1E0}-\u{1F1FF}\u{2700}-\u{27BF}\u{1F900}-\u{1F9FF}\u{1F018}-\u{1F093}\u{1F004}\u{1F400}-\u{1F4FF}\u{1F500}-\u{1F5FF}\u{1F900}-\u{1F9FF}\u{2600}-\u{26FF}\u{2B50}]', unicode: true), '');
    
    // 2. Remove markdown artifacts like ** for bold or _ for italic
    sanitized = sanitized.replaceAll('*', '').replaceAll('_', '');
    
    // 3. Remove URLs if any (as they are usually unreadable)
    sanitized = sanitized.replaceAll(RegExp(r'https?://\S+'), '');

    // 4. Trim extra spaces
    return sanitized.trim();
  }

  Future<void> requestMicrophonePermission() async {
    await _recorder?.hasPermission();
  }

  /// [ALPHA TEST ONLY] Manual Trigger for Anta Voice Messages
  Future<void> playAntaSpecificMessage(String message, AppLanguage language) async {
    debugPrint('📢 [Sandbox] Déclenchement manuel du message Anta : "$message"');
    await speakText(message, language);
  }
}

final voiceServiceProvider = Provider<VoiceService>((ref) {
  final wolofService = ref.watch(wolofAudioServiceProvider);
  return VoiceService(wolofService);
});
