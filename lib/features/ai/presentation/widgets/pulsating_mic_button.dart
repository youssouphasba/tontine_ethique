import 'package:flutter/material.dart';
// import 'dart:math' as math;
import 'package:tontetic/core/theme/app_theme.dart';

class PulsatingMicButton extends StatefulWidget {
  final bool isRecording;
  final bool isProcessing;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const PulsatingMicButton({
    super.key,
    required this.isRecording,
    this.isProcessing = false,
    required this.onTap,
    this.onLongPress,
  });

  @override
  State<PulsatingMicButton> createState() => _PulsatingMicButtonState();
}

class _PulsatingMicButtonState extends State<PulsatingMicButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: widget.onLongPress,
      onTap: widget.onTap,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (widget.isRecording)
            ...List.generate(3, (index) {
              return AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  final double progress = (_controller.value + index / 3) % 1.0;
                  final double opacity = 1.0 - progress;
                  final double scale = 1.0 + (progress * 1.5);
                  
                  return Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppTheme.emeraldGreen.withValues(alpha: opacity * 0.5),
                        width: 2,
                      ),
                    ),
                    transform: Matrix4.diagonal3Values(scale, scale, 1.0),
                  );
                },
              );
            }),
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: widget.isRecording ? Colors.red : AppTheme.emeraldGreen,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: (widget.isRecording ? Colors.red : AppTheme.emeraldGreen).withValues(alpha: 0.3),
                  blurRadius: 10,
                  spreadRadius: 2,
                )
              ],
            ),
            child: Center(
              child: widget.isProcessing 
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : Icon(
                    widget.isRecording ? Icons.stop : Icons.mic,
                    color: Colors.white,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
