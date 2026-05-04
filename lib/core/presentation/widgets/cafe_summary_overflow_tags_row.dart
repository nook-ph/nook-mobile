import 'package:flutter/material.dart';
import 'package:nook/core/utils/tag_icon_resolver.dart';

class CafeSummaryOverflowTagsRow extends StatelessWidget {
  const CafeSummaryOverflowTagsRow({
    super.key,
    required this.tags,
    this.isSkeleton = false,
  });

  final List<String> tags;
  final bool isSkeleton;

  static const double _fontSize = 12;
  static const double _hPadding = 24; // 12 * 2
  static const double _spacing = 6;
  static const double _borderWidth = 2; // 1px each side
  static const double _iconSize = 16;
  static const double _iconGap = 4;

  double _chipWidth(
    String label,
    TextScaler textScaler,
    String? fontFamily,
  ) {
    final tp = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(fontSize: _fontSize, fontFamily: fontFamily),
      ),
      textDirection: TextDirection.ltr,
      textScaler: textScaler,
    )..layout();
    final hasIcon = resolveTagIcon(label) != null;
    final iconExtra = hasIcon ? _iconSize + _iconGap : 0.0;
    // +2 for subpixel rounding safety
    return tp.width + _hPadding + _borderWidth + iconExtra + 2;
  }

  List<String> _computeVisibleLabels(
    double availableWidth,
    TextScaler textScaler,
    String? fontFamily,
  ) {
    if (tags.isEmpty) return [];

    final dotWidth = _chipWidth('...', textScaler, fontFamily);
    final List<String> result = [];
    double used = 0;

    for (int i = 0; i < tags.length; i++) {
      final w = _chipWidth(tags[i], textScaler, fontFamily);
      final isLast = i == tags.length - 1;

      if (isLast) {
        if (used + w <= availableWidth) {
          result.add(tags[i]);
        } else if (used + dotWidth <= availableWidth) {
          result.add('...');
        }
      } else {
        if (used + w + _spacing + dotWidth <= availableWidth) {
          result.add(tags[i]);
          used += w + _spacing;
        } else if (used + dotWidth <= availableWidth) {
          result.add('...');
          return result;
        } else {
          return result;
        }
      }
    }

    return result;
  }

  @override
  Widget build(BuildContext context) {
    final textScaler = MediaQuery.textScalerOf(context);
    final fontFamily = DefaultTextStyle.of(context).style.fontFamily;
    return LayoutBuilder(
      builder: (context, constraints) {
        final labels = _computeVisibleLabels(
          constraints.maxWidth,
          textScaler,
          fontFamily,
        );
        return Row(
          children: [
            for (int i = 0; i < labels.length; i++) ...[
              _TagChip(label: labels[i], isSkeleton: isSkeleton),
              if (i != labels.length - 1) const SizedBox(width: _spacing),
            ],
          ],
        );
      },
    );
  }
}

class _TagChip extends StatelessWidget {
  const _TagChip({required this.label, this.isSkeleton = false});

  final String label;
  final bool isSkeleton;

  @override
  Widget build(BuildContext context) {
    final icon = resolveTagIcon(label);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: isSkeleton ? null : Border.all(color: const Color(0xFF588157)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: const Color(0xFF588157)),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: Color(0xFF588157)),
          ),
        ],
      ),
    );
  }
}
