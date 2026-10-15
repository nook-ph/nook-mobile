import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:nook/core/cafe/domain/places_progress.dart';
import 'package:nook/features/lists/presentation/widgets/list_tokens.dart';

/// "Been to 3 of 8": how many of a person's places they have been to, as a
/// small pill beside a title (the Saved tab's "Your lists", Home's "Your
/// places"). A ring fills with the share visited; once every place is Been
/// it turns into a check. Draws nothing when nothing is saved.
///
/// Read-only: it states progress, it is not a control.
class PlacesProgressPill extends StatelessWidget {
  const PlacesProgressPill({super.key, required this.progress});

  final PlacesProgress progress;

  static const _ring = 14.0;

  @override
  Widget build(BuildContext context) {
    final label = progress.label;
    if (label == null) return const SizedBox.shrink();
    return Semantics(
      container: true,
      label: progress.semanticsLabel,
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 4, 10, 4),
        decoration: BoxDecoration(
          color: ListsTokens.tint,
          borderRadius: BorderRadius.circular(100),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox.square(
              dimension: _ring,
              child: progress.isComplete
                  ? const Icon(
                      LucideIcons.circleCheck,
                      size: _ring,
                      color: ListsTokens.brand,
                    )
                  : CircularProgressIndicator(
                      value: progress.fraction,
                      strokeWidth: 2.5,
                      color: ListsTokens.brand,
                      backgroundColor: ListsTokens.checkbox,
                    ),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              maxLines: 1,
              style: listsText(
                12,
                weight: FontWeight.w500,
                color: ListsTokens.brand,
              ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
            ),
          ],
        ),
      ),
    );
  }
}

/// The Saved tab's large title with the progress pill at its end, centred
/// on the title's line.
class ListsTitleRow extends StatelessWidget {
  const ListsTitleRow({super.key, required this.title, required this.progress});

  final String title;
  final PlacesProgress progress;

  @override
  Widget build(BuildContext context) {
    final heading = Text(title, style: listsText(24, weight: FontWeight.w600));
    if (progress.isEmpty) return heading;
    return Row(
      children: [
        Expanded(child: heading),
        const SizedBox(width: 12),
        PlacesProgressPill(progress: progress),
      ],
    );
  }
}
