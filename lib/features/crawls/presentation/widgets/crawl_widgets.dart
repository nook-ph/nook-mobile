import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:nook/core/utils/adaptive_tap.dart';
import 'package:nook/features/crawls/domain/entities/crawl.dart';
import 'package:nook/features/crawls/domain/entities/crawl_run.dart';
import 'package:nook/features/lists/presentation/widgets/list_tokens.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

/// Soft tinted surface for chips and the "you're here" row.
const crawlTint = Color(0xFFEEEEEE);

/// Side gutter of the crawl pages.
const crawlGutter = 20.0;

/// The green chip tint ("In progress", "Crawl", "5 of 6").
const crawlGreenTint = Color(0xFFE6EDE8);

/// The warm fill of the "Location is off" notice on the run page.
const crawlWarmTint = Color(0xFFFBF3DF);

/// The off-white of the empty card and the invite link box.
const crawlSoftFill = Color(0xFFF6F6F4);

/// A crawl text style at an exact Figma size. Sizes are set here rather than
/// through the app text theme, whose body sizes differ from the redesign's.
TextStyle crawlText(
  double size, {
  FontWeight weight = FontWeight.w400,
  Color color = ListsTokens.ink,
  double height = 1.5,
  double? letterSpacing,
}) => TextStyle(
  fontFamily: 'Poppins',
  fontSize: size,
  fontWeight: weight,
  color: color,
  height: height,
  letterSpacing: letterSpacing,
);

/// The crawl stamp: a scalloped seal carrying a check or a stop number.
///
/// Seals are the crawl motif; loyalty cards (when they ship) use punch-dots.
/// Keep the two apart.
class CrawlSeal extends StatelessWidget {
  const CrawlSeal({
    super.key,
    required this.size,
    this.label,
    this.color = ListsTokens.brand,
    this.foreground = ListsTokens.surface,
    this.ring = false,
  });

  final double size;

  /// A stop number. Null draws a check instead.
  final String? label;
  final Color color;
  final Color foreground;

  /// The dashed inner ring, for the large ceremonial sizes.
  final bool ring;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _SealPainter(color: color, ring: ring ? foreground : null),
        child: Center(
          child: label == null
              ? Icon(
                  LucideIcons.check,
                  // Figma: 60 on the 120 seal, 15.68 on the 28 one.
                  size: size * (ring ? 0.5 : 0.56),
                  color: foreground,
                )
              : Text(
                  label!,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: size * 0.42,
                    fontWeight: FontWeight.w600,
                    color: foreground,
                    height: 1,
                  ),
                ),
        ),
      ),
    );
  }
}

class _SealPainter extends CustomPainter {
  _SealPainter({required this.color, this.ring});

  final Color color;
  final Color? ring;

  static const _points = 16;
  static const _inner = 0.87;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2;
    final path = Path();
    for (var i = 0; i < _points * 2; i++) {
      final r = i.isEven ? radius : radius * _inner;
      final angle = -math.pi / 2 + i * math.pi / _points;
      final point = center + Offset(math.cos(angle), math.sin(angle)) * r;
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    path.close();

    canvas.drawPath(path, Paint()..color = color);
    // A round-joined stroke in the same colour softens the scallop tips.
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = radius * 0.06
        ..strokeJoin = StrokeJoin.round,
    );

    final ringColor = ring;
    if (ringColor == null) return;
    final ringPaint = Paint()
      ..color = ringColor.withValues(alpha: 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1, radius / 45);
    const dashes = 40;
    final ringRect = Rect.fromCircle(center: center, radius: radius * 0.74);
    for (var i = 0; i < dashes; i++) {
      canvas.drawArc(
        ringRect,
        i * 2 * math.pi / dashes,
        math.pi / dashes,
        false,
        ringPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_SealPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.ring != ring;
}

/// A stop number in a circle. Filled = picked / current; outlined = not yet.
class CrawlNumberBadge extends StatelessWidget {
  const CrawlNumberBadge({
    super.key,
    this.number,
    this.size = 24,
    this.background,
    this.foreground = ListsTokens.surface,
    this.outlined = false,
  });

  final int? number;
  final double size;
  final Color? background;
  final Color foreground;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: outlined
            ? ListsTokens.surface
            : (background ?? ListsTokens.brand),
        // An unpicked circle with no number is drawn a shade darker so it
        // still reads as a control.
        border: outlined
            ? Border.all(
                color: number == null
                    ? const Color(0xFFC4C4C4)
                    : ListsTokens.border,
              )
            : null,
      ),
      child: number == null
          ? null
          : Text(
              '$number',
              style: TextStyle(
                fontFamily: 'Poppins',
                // Figma: 12 Medium in a 28 circle.
                fontSize: size * 0.43,
                fontWeight: FontWeight.w500,
                color: outlined ? ListsTokens.muted : foreground,
                height: 1,
              ),
            ),
    );
  }
}

class CrawlProgressBar extends StatelessWidget {
  const CrawlProgressBar({super.key, required this.done, required this.total});

  final int done;
  final int total;

  @override
  Widget build(BuildContext context) {
    final fraction = total <= 0 ? 0.0 : (done / total).clamp(0.0, 1.0);
    return Semantics(
      label: '$done of $total stops stamped',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(3),
        child: SizedBox(
          height: 6,
          child: Stack(
            fit: StackFit.expand,
            children: [
              const ColoredBox(color: ListsTokens.sage),
              FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: fraction,
                child: const ColoredBox(color: ListsTokens.score),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Overlapping crew avatars; falls back to an initial when there is no photo.
///
/// [size] is the whole avatar, including its 2pt white ring (Figma: 28, and
/// 32 in the invite sheet's member rows). Neighbours overlap by 8.
class CrewAvatars extends StatelessWidget {
  const CrewAvatars({super.key, required this.crew, this.size = 28});

  final List<CrewMember> crew;
  final double size;

  static const _max = 4;
  static const _ring = 2.0;
  static const _overlap = 8.0;
  static const _fills = [
    Color(0xFF344E41),
    Color(0xFFA3B18A),
    Color(0xFF868584),
    Color(0xFF588157),
  ];

  @override
  Widget build(BuildContext context) {
    final shown = crew.take(_max).toList();
    final step = size - _overlap;
    return SizedBox(
      width: shown.isEmpty ? 0 : step * (shown.length - 1) + size,
      height: size,
      child: Stack(
        children: [
          for (var i = 0; i < shown.length; i++)
            Positioned(
              left: i * step,
              child: Container(
                width: size,
                height: size,
                padding: const EdgeInsets.all(_ring),
                decoration: const BoxDecoration(
                  color: ListsTokens.surface,
                  shape: BoxShape.circle,
                ),
                child: _Avatar(
                  member: shown[i],
                  fill: _fills[i % _fills.length],
                  size: size - _ring * 2,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.member, required this.fill, required this.size});

  final CrewMember member;
  final Color fill;
  final double size;

  @override
  Widget build(BuildContext context) {
    final initial = Container(
      color: fill,
      alignment: Alignment.center,
      child: Text(
        member.initial,
        // Figma: 10 Medium at every avatar size up to 32.
        style: const TextStyle(
          fontFamily: 'Poppins',
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: ListsTokens.surface,
          height: 1,
        ),
      ),
    );
    final url = member.avatarUrl?.trim() ?? '';
    return ClipOval(
      child: url.isEmpty
          ? initial
          : CachedNetworkImage(
              imageUrl: url,
              fit: BoxFit.cover,
              placeholder: (_, _) => initial,
              errorWidget: (_, _, _) => initial,
            ),
    );
  }
}

/// A cafe's photo as a small rounded square, with the coffee tile fallback
/// the Lists surfaces use.
class CrawlStopThumb extends StatelessWidget {
  const CrawlStopThumb({super.key, required this.imageUrl, this.size = 40});

  final String? imageUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      color: ListsTokens.sage,
      alignment: Alignment.center,
      child: Icon(
        PhosphorIcons.coffee(),
        size: size * 0.45,
        color: ListsTokens.brand,
      ),
    );
    final url = imageUrl?.trim() ?? '';
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox.square(
        dimension: size,
        child: url.isEmpty
            ? fallback
            : CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                placeholder: (_, _) => fallback,
                errorWidget: (_, _, _) => fallback,
              ),
      ),
    );
  }
}

/// A small status chip in sentence case. Green ("Crawl", "In progress",
/// "5 of 6") by default; [neutral] is the grey one ("Archived", "Finished").
class CrawlChip extends StatelessWidget {
  const CrawlChip({super.key, required this.label, this.neutral = false});

  final String label;
  final bool neutral;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: neutral ? crawlTint : crawlGreenTint,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        maxLines: 1,
        style: crawlText(
          10,
          weight: FontWeight.w500,
          color: neutral ? ListsTokens.ink : ListsTokens.brand,
        ),
      ),
    );
  }
}

/// Full-width primary action. Shows a spinner in place of the label while
/// [busy], and dims when [onTap] is null.
class CrawlPrimaryButton extends StatelessWidget {
  const CrawlPrimaryButton({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.busy = false,
    this.outlined = false,
  });

  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final bool busy;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null && !busy;
    final foreground = outlined ? ListsTokens.ink : ListsTokens.surface;
    return Opacity(
      opacity: enabled || busy ? 1 : 0.4,
      child: AdaptiveTap(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          height: 48,
          width: double.infinity,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: outlined ? ListsTokens.surface : ListsTokens.brand,
            borderRadius: BorderRadius.circular(999),
            border: outlined ? Border.all(color: ListsTokens.border) : null,
          ),
          child: busy
              ? SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: foreground,
                  ),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (icon != null) ...[
                      Icon(icon, size: 16, color: foreground),
                      const SizedBox(width: 6),
                    ],
                    Flexible(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: crawlText(
                          14,
                          weight: FontWeight.w500,
                          color: foreground,
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

/// Small inline pill. Filled brand by default ("Stamp" 36, "Continue" 34);
/// [outlined] is the white one with a border ("Try again", "Back to Lists").
///
/// The touch target is [tapHeight] tall even when the pill is shorter.
class CrawlPillButton extends StatelessWidget {
  const CrawlPillButton({
    super.key,
    required this.label,
    required this.onTap,
    this.height = 36,
    this.tapHeight = 44,
    this.outlined = false,
    this.fontSize = 12,
    this.icon,
  });

  final String label;
  final VoidCallback? onTap;
  final double height;
  final double tapHeight;
  final bool outlined;
  final double fontSize;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final foreground = outlined ? ListsTokens.ink : ListsTokens.surface;
    return AdaptiveTap(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: tapHeight < height ? height : tapHeight,
        ),
        child: Center(
          widthFactor: 1,
          child: Container(
            height: height,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: outlined ? ListsTokens.surface : ListsTokens.brand,
              borderRadius: BorderRadius.circular(999),
              border: outlined ? Border.all(color: ListsTokens.border) : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 14, color: foreground),
                  const SizedBox(width: 6),
                ],
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: crawlText(
                      fontSize,
                      weight: FontWeight.w500,
                      color: foreground,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The crawl drawn as a line through its stops, from their coordinates.
///
/// Straight segments between stops — the same straight-line model the
/// distance stat uses, not a walked path.
class CrawlRoutePainter extends CustomPainter {
  CrawlRoutePainter({
    required this.stops,
    required this.lineColor,
    required this.nodeColor,
    this.numberColor,
    this.strokeWidth = 3,
    this.nodeRadius = 5,
  });

  final List<CrawlStop> stops;
  final Color lineColor;
  final Color nodeColor;

  /// When set, each node carries its stop number in this colour.
  final Color? numberColor;
  final double strokeWidth;
  final double nodeRadius;

  @override
  void paint(Canvas canvas, Size size) {
    final points = layout(stops, size, inset: nodeRadius + strokeWidth);
    if (points.isEmpty) return;

    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = lineColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    final nodePaint = Paint()..color = nodeColor;
    for (var i = 0; i < points.length; i++) {
      canvas.drawCircle(points[i], nodeRadius, nodePaint);
      final color = numberColor;
      if (color == null) continue;
      final text = TextPainter(
        text: TextSpan(
          text: '${i + 1}',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: nodeRadius * 1.15,
            fontWeight: FontWeight.w600,
            color: color,
            height: 1,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      text.paint(canvas, points[i] - Offset(text.width / 2, text.height / 2));
    }
  }

  /// Projects the stops into [size], keeping the route's real proportions and
  /// centring it. Exposed for tests.
  static List<Offset> layout(
    List<CrawlStop> stops,
    Size size, {
    double inset = 0,
  }) {
    if (stops.isEmpty) return const [];
    final meanLat =
        stops.map((s) => s.lat).reduce((a, b) => a + b) / stops.length;
    // Shrink longitude by cos(latitude) so east-west isn't stretched.
    final scaleX = math.cos(meanLat * math.pi / 180);
    final xs = stops.map((s) => s.lng * scaleX).toList();
    final ys = stops.map((s) => -s.lat).toList();
    final minX = xs.reduce(math.min), maxX = xs.reduce(math.max);
    final minY = ys.reduce(math.min), maxY = ys.reduce(math.max);

    final width = math.max(size.width - inset * 2, 1.0);
    final height = math.max(size.height - inset * 2, 1.0);
    final spanX = maxX - minX, spanY = maxY - minY;
    // Stops stacked on one point (or one line) have no span to scale by.
    final scale = math.min(
      spanX > 0 ? width / spanX : double.infinity,
      spanY > 0 ? height / spanY : double.infinity,
    );
    final k = scale.isFinite ? scale : 0.0;
    final offsetX = inset + (width - spanX * k) / 2;
    final offsetY = inset + (height - spanY * k) / 2;

    return [
      for (var i = 0; i < stops.length; i++)
        Offset(offsetX + (xs[i] - minX) * k, offsetY + (ys[i] - minY) * k),
    ];
  }

  @override
  bool shouldRepaint(CrawlRoutePainter oldDelegate) =>
      oldDelegate.stops != stops ||
      oldDelegate.lineColor != lineColor ||
      oldDelegate.nodeColor != nodeColor ||
      oldDelegate.numberColor != numberColor;
}
