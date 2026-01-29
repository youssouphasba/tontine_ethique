import 'package:flutter/material.dart';
import 'package:tontetic/core/theme/app_theme.dart';

class SignaturePad extends StatefulWidget {
  final ValueChanged<List<Offset>> onSigned;

  const SignaturePad({super.key, required this.onSigned});

  @override
  State<SignaturePad> createState() => _SignaturePadState();
}

class _SignaturePadState extends State<SignaturePad> {
  final List<Offset> _points = [];

  void _addPoint(DragUpdateDetails details) {
    setState(() {
      final renderBox = context.findRenderObject() as RenderBox;
      final local = renderBox.globalToLocal(details.globalPosition);
      // Ensure points stay within bounds visually
      if (local.dx >= 0 && local.dy >= 0 && local.dx <= renderBox.size.width && local.dy <= renderBox.size.height) {
         _points.add(local);
      }
    });
  }

  void _endStroke() {
     _points.add(Offset.infinite); // Separator (not implemented in simple version yet, but good practice)
     // Actually for simplicity we just pass points.
     widget.onSigned(_points);
  }

  void _clear() {
    setState(() {
      _points.clear();
      widget.onSigned([]);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Container(
          height: 150,
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.grey[50],
            border: Border.all(color: Colors.grey.shade400, style: BorderStyle.solid),
            borderRadius: BorderRadius.circular(8),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: GestureDetector(
              onPanUpdate: _addPoint,
              onPanEnd: (_) => _endStroke(),
              child: CustomPaint(
                painter: _SignaturePainter(_points),
                size: Size.infinite,
              ),
            ),
          ),
        ),
        TextButton(
          onPressed: _clear,
          child: const Text('Effacer', style: TextStyle(color: Colors.red, fontSize: 12)),
        )
      ],
    );
  }
}

class _SignaturePainter extends CustomPainter {
  final List<Offset> points;
  _SignaturePainter(this.points);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppTheme.marineBlue
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 3.0;

    for (int i = 0; i < points.length - 1; i++) {
        // Handle breaks if implemented (Offset.infinite), here assuming continuous for MVP
        canvas.drawLine(points[i], points[i + 1], paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
