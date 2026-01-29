import 'package:flutter_riverpod/flutter_riverpod.dart';

/// V11.28: Global Audio Settings Provider
/// Manages whether automatic TTS playback is enabled across the app.
/// Default: FALSE - User must tap speaker icon to listen
class AudioSettingsNotifier extends StateNotifier<bool> {
  AudioSettingsNotifier() : super(false); // Default to false - no auto-play

  void toggleAudio() {
    state = !state;
  }

  void setAudio(bool enabled) {
    state = enabled;
  }
}

final audioSettingsProvider = StateNotifierProvider<AudioSettingsNotifier, bool>((ref) {
  return AudioSettingsNotifier();
});
