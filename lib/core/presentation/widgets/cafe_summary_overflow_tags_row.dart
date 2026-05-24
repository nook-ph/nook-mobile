import 'package:flutter/material.dart';
import 'package:nook/core/utils/tag_icon_resolver.dart';
import 'package:nook/utils/theme/custom_themes/color_scheme.dart';
import 'package:nook/utils/theme/custom_themes/text_theme.dart';

class CafeSummaryOverflowTagsRow extends StatelessWidget {
  const CafeSummaryOverflowTagsRow({
    super.key,
    required this.tags,
    this.isSkeleton = false,
  });

  final List<String> tags;
  final bool isSkeleton;

  static const double _hPadding = 24;
  static const double _spacing = 6;
  static const double _borderWidth = 2;
  static const double _iconSize = 16;
  static const double _iconGap = 4;

  double _chipWidth(String label, TextScaler textScaler, TextStyle baseStyle) {
    final tp = TextPainter(
      text: TextSpan(text: label, style: baseStyle),
      textDirection: TextDirection.ltr,
      textScaler: textScaler,
    )..layout();

    final iconExtra = resolveTagIcon(label) != null ? _iconSize + _iconGap : 0.0;
    return tp.width + _hPadding + _borderWidth + iconExtra + 2;
  }

  List<String> _computeVisibleLabels(
    double availableWidth,
    TextScaler textScaler,
    TextStyle baseStyle,
  ) {
    if (tags.isEmpty) return [];

    final dotWidth = _chipWidth('...', textScaler, baseStyle);
    final List<String> result = [];
    double used = 0;

    for (int i = 0; i < tags.length; i++) {
      final w = _chipWidth(tags[i], textScaler, baseStyle);
      final isLast = i == tags.length - 1;

      if (isLast) {
        if (used + w <= availableWidth) result.add(tags[i]);
        else if (used + dotWidth <= availableWidth) result.add('...');
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
    final baseStyle = Theme.of(context).textTheme.bodySmallMed;

    return LayoutBuilder(
      builder: (context, constraints) {
        final labels = _computeVisibleLabels(
          constraints.maxWidth,
          textScaler,
          baseStyle,
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
    final borderColor = Theme.of(context).colorScheme.primary60;
    final iconColor = Theme.of(context).colorScheme.primary60;
    final textColor = Theme.of(context).colorScheme.primary40;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: isSkeleton ? null : Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: iconColor),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmallMed.copyWith(
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}
