import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:nook/core/cafe/domain/places_progress.dart';
import 'package:nook/core/utils/adaptive_tap.dart';
import 'package:nook/features/lists/presentation/widgets/list_tokens.dart';

/// "1 been · 2 to try": a person's places as two counts, in a small pill
/// beside a title (the Saved tab's "Your lists", Home's "Your places").
/// Draws nothing when nothing is saved.
///
/// The glyph says the state at a glance: a bookmark while nothing is Been
/// (the Want to try icon), a filled pie for the share Been, a check once
/// nothing is left to try. No ring: a thin arc on a grey track is the shape
/// of Material's loading spinner. The glyph scales with the text.
///
/// With [onTap] it is a button that opens the Want to try list; the target
/// is 48dp tall around the pill.
class PlacesProgressPill extends StatelessWidget {
  const PlacesProgressPill({super.key, required this.progress, this.onTap});

  final PlacesProgress progress;
  final VoidCallback? onTap;

  static const double _fontSize = 12;

  /// The pill's minimum touch height when it is a button.
  static const double minTarget = 48;

  @override
  Widget build(BuildContext context) {
    final label = progress.label;
    if (label == null) return const SizedBox.shrink();
    final glyph = MediaQuery.textScalerOf(context).scale(_fontSize) * 1.15;

    final pill = Container(
      padding: const EdgeInsets.fromLTRB(8, 4, 10, 4),
      decoration: BoxDecoration(
        color: ListsTokens.tint,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox.square(
            dimension: glyph,
            child: progress.isComplete
                ? Icon(
                    LucideIcons.circleCheck,
                    size: glyph,
                    color: ListsTokens.brand,
                  )
                : progress.been == 0
                ? Icon(
                    LucideIcons.bookmark,
                    size: glyph,
                    color: ListsTokens.brand,
                  )
                : CustomPaint(painter: _PiePainter(progress.fraction)),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: listsText(
                _fontSize,
                weight: FontWeight.w500,
                color: ListsTokens.brand,
              ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
            ),
          ),
        ],
      ),
    );

    final tap = onTap;
    if (tap == null) {
      return Semantics(
        container: true,
        label: progress.semanticsLabel,
        excludeSemantics: true,
        child: pill,
      );
    }
    return Semantics(
      container: true,
      button: true,
      label: '${progress.semanticsLabel}, open Want to try',
      excludeSemantics: true,
      child: AdaptiveTap(
        onTap: tap,
        borderRadius: BorderRadius.circular(100),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: minTarget),
          child: Align(widthFactor: 1, child: pill),
        ),
      ),
    );
  }
}

/// A pie: the Been share filled from twelve o'clock, inside a brand
/// outline. The outline is the track, at well over 3:1 on the pill's grey.
class _PiePainter extends CustomPainter {
  const _PiePainter(this.fraction);

  final double fraction;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = math.max(1.25, size.width / 10);
    final rect = Offset.zero & size;
    final ring = rect.deflate(stroke / 2);
    canvas.drawOval(
      ring,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = ListsTokens.brand,
    );
    // A sliver is still a visible wedge: at least 1/12.
    final share = fraction.clamp(1 / 12, 1.0);
    canvas.drawArc(
      ring,
      -math.pi / 2,
      2 * math.pi * share,
      true,
      Paint()..color = ListsTokens.brand,
    );
  }

  @override
  bool shouldRepaint(_PiePainter old) => old.fraction != fraction;
}

/// From this text scale a title and the pill no longer share a line: the
/// pill moves under the title, which is the landmark. Measured at 16sp,
/// since Android scales large text less than small.
bool placesProgressStacks(BuildContext context) =>
    MediaQuery.textScalerOf(context).scale(16) >= 1.6 * 16;

/// The Saved tab's large title with the progress pill at its end, centred
/// on the title's line; under the title at large text.
class ListsTitleRow extends StatelessWidget {
  const ListsTitleRow({
    super.key,
    required this.title,
    required this.progress,
    this.onProgressTap,
  });

  final String title;
  final PlacesProgress progress;

  /// Opens the Want to try list; only while there is something to try.
  final VoidCallback? onProgressTap;

  @override
  Widget build(BuildContext context) {
    final heading = Text(title, style: listsText(24, weight: FontWeight.w600));
    if (progress.isEmpty) return heading;
    final pill = PlacesProgressPill(
      progress: progress,
      onTap: progress.wantToTry > 0 ? onProgressTap : null,
    );
    if (placesProgressStacks(context)) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [heading, pill],
      );
    }
    return Row(
      children: [
        Expanded(child: heading),
        const SizedBox(width: 12),
        Flexible(child: pill),
      ],
    );
  }
}
