import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tontetic/core/providers/audio_settings_provider.dart';
import 'package:tontetic/core/theme/app_theme.dart';

/// V11.28: Global TTS Toggle for App Bar
class TTSControlToggle extends ConsumerWidget {
  const TTSControlToggle({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAudioEnabled = ref.watch(audioSettingsProvider);

    return IconButton(
      icon: Icon(
        isAudioEnabled ? Icons.volume_up : Icons.volume_off,
        color: isAudioEnabled ? AppTheme.gold : Colors.grey,
      ),
      tooltip: isAudioEnabled ? 'Mode Vocal Activé' : 'Mode Silencieux',
      onPressed: () {
        ref.read(audioSettingsProvider.notifier).toggleAudio();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isAudioEnabled ? '🔇 Mode Silencieux activé' : '🔊 Mode Vocal activé',
              style: const TextStyle(fontSize: 12),
            ),
            duration: const Duration(seconds: 1),
            behavior: SnackBarBehavior.floating,
            width: 200,
          ),
        );
      },
    );
  }
}
