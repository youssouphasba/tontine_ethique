import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tontetic/core/services/voice_service.dart';
import 'package:tontetic/core/providers/localization_provider.dart';
import 'package:tontetic/core/theme/app_theme.dart';

/// V11.28: Reusable Speaker Icon to trigger TTS for specific text
class SpeakerIcon extends ConsumerWidget {
  final String text;
  final AppLanguage? language;
  final double size;

  const SpeakerIcon({
    super.key,
    required this.text,
    this.language,
    this.size = 24,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IconButton(
      icon: Icon(Icons.volume_up, size: size, color: AppTheme.gold),
      constraints: BoxConstraints.tightFor(width: size + 16, height: size + 16),
      padding: EdgeInsets.zero,
      onPressed: () {
        final lang = language ?? ref.read(localizationProvider).language;
        ref.read(voiceServiceProvider).speakText(text, lang);
      },
    );
  }
}
