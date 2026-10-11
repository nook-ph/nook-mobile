import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:nook/core/utils/tag_icon_resolver.dart';

/// A tag's icon: one of Nook's own coffee glyphs when the tag has one,
/// otherwise its Phosphor icon (see [resolveTagIcon]), otherwise [fallback].
/// Renders nothing when there is no icon at all, so check [hasTagIcon] before
/// reserving space for one.
class TagIcon extends StatelessWidget {
  const TagIcon(
    this.tagName, {
    super.key,
    required this.size,
    required this.color,
    this.fallback,
  });

  final String? tagName;
  final double size;
  final Color color;

  /// Shown when the tag has neither a custom glyph nor a Phosphor icon.
  final IconData? fallback;

  @override
  Widget build(BuildContext context) {
    final glyph = resolveCoffeeGlyph(tagName);
    if (glyph != null) {
      return CoffeeGlyphIcon(glyph, size: size, color: color);
    }
    final icon = resolveTagIcon(tagName) ?? fallback;
    if (icon == null) return const SizedBox.shrink();
    return Icon(icon, size: size, color: color);
  }
}

/// One of the custom coffee icons, drawn as Phosphor regular.
///
/// Source of truth: nook-supabase `assets/icons/coffee/*.svg` (256 x 256
/// viewBox, 16-unit round stroke, no fill). The paths below are those files,
/// coordinate for coordinate; drawing them directly keeps the app free of an
/// SVG renderer and an asset round trip for six small glyphs. There is only a
/// regular weight: a selected chip keeps it and lets its colours carry the
/// state.
class CoffeeGlyphIcon extends StatelessWidget {
  const CoffeeGlyphIcon(
    this.glyph, {
    super.key,
    required this.size,
    required this.color,
  });

  final CoffeeGlyph glyph;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: _CoffeeGlyphPainter(glyph, color)),
    );
  }
}

class _CoffeeGlyphPainter extends CustomPainter {
  _CoffeeGlyphPainter(this.glyph, this.color);

  final CoffeeGlyph glyph;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 16
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;

    canvas.save();
    canvas.scale(size.width / 256, size.height / 256);
    for (final part in _parts(glyph)) {
      part(canvas, paint);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_CoffeeGlyphPainter old) =>
      old.glyph != glyph || old.color != color;
}

typedef _Part = void Function(Canvas canvas, Paint paint);

_Part _path(Path path) =>
    (canvas, paint) => canvas.drawPath(path, paint);

_Part _line(double x1, double y1, double x2, double y2) =>
    (canvas, paint) => canvas.drawLine(Offset(x1, y1), Offset(x2, y2), paint);

/// An SVG `<ellipse>` with `transform="rotate(deg cx cy)"`.
_Part _ellipse(double cx, double cy, double rx, double ry, double deg) =>
    (canvas, paint) {
      canvas.save();
      canvas.translate(cx, cy);
      canvas.rotate(deg * math.pi / 180);
      canvas.drawOval(
        Rect.fromCenter(center: Offset.zero, width: rx * 2, height: ry * 2),
        paint,
      );
      canvas.restore();
    };

Path _polyline(List<Offset> points) {
  final path = Path()..moveTo(points.first.dx, points.first.dy);
  for (final p in points.skip(1)) {
    path.lineTo(p.dx, p.dy);
  }
  return path;
}

List<_Part> _parts(CoffeeGlyph glyph) {
  switch (glyph) {
    case CoffeeGlyph.espresso:
      return [
        // M64,104H176v16a56,56,0,0,1-112,0Z
        _path(
          Path()
            ..moveTo(64, 104)
            ..lineTo(176, 104)
            ..lineTo(176, 120)
            ..arcToPoint(
              const Offset(64, 120),
              radius: const Radius.circular(56),
            )
            ..close(),
        ),
        // M176,112h12a20,20,0,0,1,0,40H166
        _path(
          Path()
            ..moveTo(176, 112)
            ..lineTo(188, 112)
            ..arcToPoint(
              const Offset(188, 152),
              radius: const Radius.circular(20),
            )
            ..lineTo(166, 152),
        ),
        _line(40, 200, 216, 200),
        _line(104, 40, 104, 72),
        _line(136, 40, 136, 72),
      ];
    case CoffeeGlyph.pourOver:
      return [
        // M40,48H216l-48,64H88Z
        _path(
          Path()
            ..moveTo(40, 48)
            ..lineTo(216, 48)
            ..lineTo(168, 112)
            ..lineTo(88, 112)
            ..close(),
        ),
        _line(128, 136, 128, 140),
        // M72,164H184v12a32,32,0,0,1-32,32H104a32,32,0,0,1-32-32Z
        _path(
          Path()
            ..moveTo(72, 164)
            ..lineTo(184, 164)
            ..lineTo(184, 176)
            ..arcToPoint(
              const Offset(152, 208),
              radius: const Radius.circular(32),
            )
            ..lineTo(104, 208)
            ..arcToPoint(
              const Offset(72, 176),
              radius: const Radius.circular(32),
            )
            ..close(),
        ),
      ];
    case CoffeeGlyph.coldBrew:
      return [
        // M56,64H200l-22,152H78Z
        _path(
          Path()
            ..moveTo(56, 64)
            ..lineTo(200, 64)
            ..lineTo(178, 216)
            ..lineTo(78, 216)
            ..close(),
        ),
        _path(
          _polyline(const [Offset(148, 64), Offset(168, 32), Offset(196, 32)]),
        ),
        // rect x=96 y=112 width=44 height=44 rx=4
        _path(
          Path()..addRRect(
            RRect.fromRectAndRadius(
              const Rect.fromLTWH(96, 112, 44, 44),
              const Radius.circular(4),
            ),
          ),
        ),
      ];
    case CoffeeGlyph.philippineBeans:
      return [
        // M208,104c0,72-80,128-80,128S48,176,48,104a80,80,0,0,1,160,0Z
        _path(
          Path()
            ..moveTo(208, 104)
            ..cubicTo(208, 176, 128, 232, 128, 232)
            ..cubicTo(128, 232, 48, 176, 48, 104)
            ..arcToPoint(
              const Offset(208, 104),
              radius: const Radius.circular(80),
            )
            ..close(),
        ),
        _ellipse(128, 104, 24, 36, 45),
        // M111,121c4-14,30-20,34-34
        _path(
          Path()
            ..moveTo(111, 121)
            ..cubicTo(115, 107, 141, 101, 145, 87),
        ),
      ];
    case CoffeeGlyph.kapengBarako:
      return [
        // M48,56H184V184a24,24,0,0,1-24,24H72a24,24,0,0,1-24-24Z
        _path(
          Path()
            ..moveTo(48, 56)
            ..lineTo(184, 56)
            ..lineTo(184, 184)
            ..arcToPoint(
              const Offset(160, 208),
              radius: const Radius.circular(24),
            )
            ..lineTo(72, 208)
            ..arcToPoint(
              const Offset(48, 184),
              radius: const Radius.circular(24),
            )
            ..close(),
        ),
        _line(48, 88, 184, 88),
        // M184,104h8a32,32,0,0,1,0,64h-8
        _path(
          Path()
            ..moveTo(184, 104)
            ..lineTo(192, 104)
            ..arcToPoint(
              const Offset(192, 168),
              radius: const Radius.circular(32),
            )
            ..lineTo(184, 168),
        ),
        _ellipse(116, 148, 18, 28, 30),
      ];
    case CoffeeGlyph.matcha:
      return [
        // M32,128H224a96,96,0,0,1-192,0Z
        _path(
          Path()
            ..moveTo(32, 128)
            ..lineTo(224, 128)
            ..arcToPoint(
              const Offset(32, 128),
              radius: const Radius.circular(96),
            )
            ..close(),
        ),
        _path(
          _polyline(const [
            Offset(108, 128),
            Offset(128, 88),
            Offset(176, 88),
            Offset(188, 128),
          ]),
        ),
        _line(152, 88, 160, 32),
      ];
  }
}
