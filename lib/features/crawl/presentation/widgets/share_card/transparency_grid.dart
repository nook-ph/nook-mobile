import 'package:flutter/material.dart';

class TransparencyGrid extends StatelessWidget {
  const TransparencyGrid({super.key});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _CheckerboardPainter(),
    );
  }
}

class _CheckerboardPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const tileSize = 10.0;
    final lightPaint = Paint()..color = const Color(0xFF1A1A1A);
    final darkPaint = Paint()..color = const Color(0xFF2A2A2A);

    final cols = (size.width / tileSize).ceil();
    final rows = (size.height / tileSize).ceil();

    for (var row = 0; row < rows; row++) {
      for (var col = 0; col < cols; col++) {
        final paint = (row + col) % 2 == 0 ? lightPaint : darkPaint;
        canvas.drawRect(
          Rect.fromLTWH(col * tileSize, row * tileSize, tileSize, tileSize),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_CheckerboardPainter oldDelegate) => false;
}
