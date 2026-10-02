import 'package:flutter/material.dart';
import 'package:nook/core/extensions/extensions.dart';
import 'package:nook/core/utils/tag_icon_resolver.dart';

/// How many tag chips a featured card shows before folding the rest into a
/// "+N" chip.
const homeFeaturedTagLimit = 2;

/// Splits [tags] into the ones shown and the count folded into "+N".
({List<String> shown, int more}) homeFeaturedTags(List<String> tags) {
  final clean = [
    for (final tag in tags)
      if (tag.trim().isNotEmpty) tag.trim(),
  ];
  if (clean.length <= homeFeaturedTagLimit) return (shown: clean, more: 0);
  return (
    shown: clean.sublist(0, homeFeaturedTagLimit),
    more: clean.length - homeFeaturedTagLimit,
  );
}

/// One tag as an outlined pill, with the tag's icon when the app has one.
class HomeTagChip extends StatelessWidget {
  const HomeTagChip({super.key, required this.label, this.isSkeleton = false});

  final String label;
  final bool isSkeleton;

  @override
  Widget build(BuildContext context) {
    final icon = resolveTagIcon(label);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        // The skeleton keeps a transparent border of the same width, so a
        // skeleton chip is exactly as tall as a real one. The featured and
        // compact carousels size themselves from a skeleton prototype; a
        // borderless prototype was 2pt short and clipped the real chips.
        border: Border.all(
          color: isSkeleton ? Colors.transparent : context.colorScheme.border,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: context.colorScheme.primary100),
            const SizedBox(width: 5),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.textTheme.bodySmall?.copyWith(
                color: context.colorScheme.black,
                fontSize: 10,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The featured card's chip row: up to [homeFeaturedTagLimit] tags, then
/// "+N". Chips shrink with an ellipsis before the row can overflow.
class HomeTagChips extends StatelessWidget {
  const HomeTagChips({super.key, required this.tags, this.isSkeleton = false});

  final List<String> tags;
  final bool isSkeleton;

  @override
  Widget build(BuildContext context) {
    final split = homeFeaturedTags(tags);
    if (split.shown.isEmpty) return const SizedBox.shrink();
    return Row(
      children: [
        for (var i = 0; i < split.shown.length; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          Flexible(
            child: HomeTagChip(label: split.shown[i], isSkeleton: isSkeleton),
          ),
        ],
        if (split.more > 0) ...[
          const SizedBox(width: 6),
          HomeTagChip(label: '+${split.more}', isSkeleton: isSkeleton),
        ],
      ],
    );
  }
}
