// import 'dart:io'; // Removed for Web Compatibility
import 'dart:convert';
// import 'dart:typed_data'; // Added for Uint8List - UNUSED
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
// import 'package:path_provider/path_provider.dart'; // Removed for now
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audioplayers/audioplayers.dart';

class WolofAudioService {
  final AudioPlayer _audioPlayer = AudioPlayer();
  final String _spaceUrl = 'https://yousaerba-tontetic-tts-wolof.hf.space';

  /// Wake up the Space (Ping) to avoid cold start delay
  Future<void> wakeUp() async {
    try {
      debugPrint("Waking up Anta (Wolof TTS)...");
      final response = await http.get(Uri.parse(_spaceUrl)).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        debugPrint("Anta is awake and ready.");
      }
    } catch (e) {
      debugPrint("Anta Wakeup failed: $e");
    }
  }

  /// Bloc 2: Logique d'intégration mobile
  Future<bool> speakWolof(String text) async {
    try {
      // Note: Caching disabled for web compatibility (dart:io unavailable)
      // Can be re-enabled on mobile using Hive or path_provider
      
      debugPrint("Anta is processing: $text");
      final audioBytes = await fetchWolofVoice(text);
      
      if (audioBytes != null) {
        await _audioPlayer.play(BytesSource(Uint8List.fromList(audioBytes)));
        return true;
      }
      return false;
    } catch (e) {
      debugPrint("Wolof TTS Error: $e");
      return false;
    }
  }

  /*
  Future<File> _getCacheFile(String text) async {
    final directory = await getApplicationDocumentsDirectory();
    final hash = sha256.convert(utf8.encode(text)).toString();
    // Cache management: save locally as .wav
    return File('${directory.path}/anta_$hash.wav');
  }
  */

  /// Fonction fetchWolofVoice(text) implementation
  Future<List<int>?> fetchWolofVoice(String text) async {
    final predictUrl = '$_spaceUrl/run/predict';
    
    try {
      final response = await http.post(
        Uri.parse(predictUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'data': [
            text,
            "Anta", // Force speaker="Anta"
          ],
          'fn_index': 0,
        }),
      ).timeout(const Duration(seconds: 5)); // Bloc 3: Timeout 5s

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final fileUrl = data['data'][0]['name']; 
        final fullFileUrl = '$_spaceUrl/file=$fileUrl';
        
        final audioResponse = await http.get(Uri.parse(fullFileUrl)).timeout(const Duration(seconds: 5));
        return audioResponse.bodyBytes;
      }
    } catch (e) {
      debugPrint("Anta Fetch Error (Timeout or failure): $e");
    }
    return null; // Triggers fallback to text
  }
}

final wolofAudioServiceProvider = Provider<WolofAudioService>((ref) {
  return WolofAudioService();
});
