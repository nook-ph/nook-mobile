import 'package:flutter/material.dart';
import 'package:nook/core/cafe/domain/entities/cafe_summary.dart';
import 'package:nook/core/utils/adaptive_tap.dart';
import 'package:nook/features/lists/presentation/widgets/list_tokens.dart';
import 'package:nook/features/lists/presentation/widgets/lists_ui.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

/// One cafe in a custom list or Want to try (Figma "Custom list"): photo,
/// name, rating and area, and the ⋯ that opens the cafe's actions.
class ListCafeRow extends StatelessWidget {
  const ListCafeRow({
    super.key,
    required this.cafe,
    required this.onTap,
    required this.onMore,
  });

  final CafeSummary cafe;
  final VoidCallback onTap;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    final rated = cafe.reviewCount > 0;
    final location = cafe.locationLabel.trim();

    return Row(
      children: [
        Expanded(
          child: AdaptiveTap(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                children: [
                  ListsThumb(imageUrl: cafe.coverImage, size: 56),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          cafe.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: listsText(14, weight: FontWeight.w500),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            if (rated) ...[
                              const Icon(
                                Icons.star_rounded,
                                size: 14,
                                color: ListsTokens.accent,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                cafe.rating.toStringAsFixed(1),
                                style: listsText(12, weight: FontWeight.w500),
                              ),
                              const SizedBox(width: 4),
                            ],
                            if (location.isNotEmpty)
                              Flexible(
                                child: Text(
                                  rated ? '· $location' : location,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: listsText(
                                    12,
                                    color: ListsTokens.muted,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Semantics(
          button: true,
          label: 'Options for ${cafe.name}',
          child: AdaptiveTap(
            onTap: onMore,
            borderRadius: BorderRadius.circular(22),
            child: const SizedBox(
              width: 44,
              height: 44,
              // The glyph sits on the gutter; the target reaches inwards.
              child: Align(
                alignment: Alignment.centerRight,
                child: Icon(
                  PhosphorIconsFill.dotsThreeOutline,
                  size: 18,
                  color: ListsTokens.ink,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
