import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:tontetic/core/theme/app_theme.dart';

class AudioVisualizer extends StatefulWidget {
  final bool isRecording;
  const AudioVisualizer({super.key, required this.isRecording});

  @override
  State<AudioVisualizer> createState() => _AudioVisualizerState();
}

class _AudioVisualizerState extends State<AudioVisualizer> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    if (widget.isRecording) _controller.repeat();
  }

  @override
  void didUpdateWidget(AudioVisualizer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isRecording) {
      _controller.repeat();
    } else {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return SizedBox(
          height: 60,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(20, (index) {
              final double scale = widget.isRecording 
                  ? 0.3 + (0.7 * math.sin(_controller.value * 2 * math.pi + (index * 0.5)))
                  : 0.1;
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 1.5),
                width: 4,
                height: 10 + (40 * scale.abs()),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppTheme.emeraldGreen, AppTheme.emeraldGreen.withValues(alpha: 0.5)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  borderRadius: BorderRadius.circular(4),
                ),
              );
            }),
          ),
        );
      },
    );
  }
}
