import 'dart:math' as math;

import 'package:flutter/material.dart';

class ShareCardStampHero extends StatelessWidget {
  final String cafeName;
  final int stopNumber;

  const ShareCardStampHero({
    super.key,
    required this.cafeName,
    required this.stopNumber,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 352,
      color: const Color(0xFF0F1F0F),
      child: Stack(
        children: [
          Center(
            child: CustomPaint(
              size: const Size(200, 200),
              painter: _StampSealPainter(
                cafeName: cafeName,
                stopNumber: stopNumber,
              ),
            ),
          ),
          Positioned.fill(
            child: Opacity(
              opacity: 0.08,
              child: Image.asset(
                'assets/crawl/stamp_grain.png',
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const SizedBox(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StampSealPainter extends CustomPainter {
  _StampSealPainter({
    required this.cafeName,
    required this.stopNumber,
  });

  final String cafeName;
  final int stopNumber;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    const outerRadius = 100.0;
    const innerRadius = 90.0;
    const arcRadius = 95.0;

    final outerPaint = Paint()
      ..color = const Color(0xFF4CAF50)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(center, outerRadius, outerPaint);

    final innerPaint = Paint()
      ..color = const Color(0xFF1A2E1A)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, innerRadius, innerPaint);

    final wordmarkPainter = TextPainter(
      text: TextSpan(
        text: 'nook',
        style: TextStyle(
          color: Colors.white,
          fontSize: 28,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    wordmarkPainter.paint(
      canvas,
      center - Offset(wordmarkPainter.width / 2, wordmarkPainter.height / 2),
    );

    const arcStyle = TextStyle(
      color: Colors.white,
      fontSize: 12,
      letterSpacing: 2,
    );

    _paintArcText(
      canvas: canvas,
      center: center,
      text: cafeName.toUpperCase(),
      arcRadius: arcRadius,
      startAngleDeg: 200,
      endAngleDeg: 340,
      style: arcStyle,
    );

    _paintArcText(
      canvas: canvas,
      center: center,
      text: 'STOP $stopNumber',
      arcRadius: arcRadius,
      startAngleDeg: 160,
      endAngleDeg: 20,
      style: arcStyle,
    );
  }

  void _paintArcText({
    required Canvas canvas,
    required Offset center,
    required String text,
    required double arcRadius,
    required double startAngleDeg,
    required double endAngleDeg,
    required TextStyle style,
  }) {
    final chars = text.split('');
    if (chars.isEmpty) return;

    final startRad = startAngleDeg * (math.pi / 180);
    final endRad = endAngleDeg * (math.pi / 180);
    final sweep = endRad - startRad;

    for (int i = 0; i < chars.length; i++) {
      final t = chars.length > 1 ? i / (chars.length - 1) : 0.5;
      final angle = startRad + t * sweep;

      final charPainter = TextPainter(
        text: TextSpan(text: chars[i], style: style),
        textDirection: TextDirection.ltr,
      )..layout();

      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(angle);
      canvas.translate(arcRadius, 0);
      canvas.rotate(-math.pi / 2);
      canvas.translate(
        -charPainter.width / 2,
        -charPainter.height / 2,
      );
      charPainter.paint(canvas, Offset.zero);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_StampSealPainter oldDelegate) =>
      oldDelegate.cafeName != cafeName ||
      oldDelegate.stopNumber != stopNumber;
}
