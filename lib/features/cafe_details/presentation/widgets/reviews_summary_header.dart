import 'package:flutter/material.dart';
import 'package:nook/core/extensions/extensions.dart';
import 'package:nook/core/utils/adaptive_tap.dart';
import 'package:nook/features/cafe_details/presentation/widgets/review_sheet_shell.dart';
import 'package:nook/features/cafe_details/presentation/widgets/reviews_logic.dart';

/// The score beside the five rating rows. The rows are the rating filter:
/// tap one to see only those reviews, tap it again to clear.
class ReviewsSummaryHeader extends StatelessWidget {
  const ReviewsSummaryHeader({
    super.key,
    required this.summary,
    required this.ratingFilter,
    required this.onRatingTap,
  });

  final ReviewsSummary summary;
  final int? ratingFilter;
  final ValueChanged<int> onRatingTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      // 12 above and 16 below in Figma. Each 18pt rating row is a 24pt
      // target here, which already adds 3 at either end.
      padding: const EdgeInsets.fromLTRB(
        ReviewTokens.gutter,
        9,
        ReviewTokens.gutter,
        13,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                summary.average.toStringAsFixed(1),
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 32,
                  fontWeight: FontWeight.w600,
                  color: ReviewTokens.ink,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 2),
              ReviewStars(rating: summary.average.round()),
              const SizedBox(height: 2),
              Text(
                reviewCountLabel(summary.total),
                style: context.textTheme.bodySmall?.copyWith(
                  color: ReviewTokens.muted,
                ),
              ),
            ],
          ),
          const SizedBox(width: 24),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var star = 5; star >= 1; star--)
                  _RatingRow(
                    star: star,
                    count: summary.countFor(star),
                    fraction: summary.fractionFor(star),
                    selected: ratingFilter == star,
                    dimmed: ratingFilter != null && ratingFilter != star,
                    onTap: () => onRatingTap(star),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RatingRow extends StatelessWidget {
  const _RatingRow({
    required this.star,
    required this.count,
    required this.fraction,
    required this.selected,
    required this.dimmed,
    required this.onTap,
  });

  final int star;
  final int count;
  final double fraction;
  final bool selected;
  final bool dimmed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final style =
        (selected
                ? context.textTheme.bodyExtraSmallMed
                : context.textTheme.bodyExtraSmall)
            .copyWith(
              color: selected ? ReviewTokens.ink : ReviewTokens.muted,
              fontWeight: selected ? FontWeight.w600 : null,
            );

    return Semantics(
      button: true,
      selected: selected,
      label:
          '$star star, ${reviewCountLabel(count)}. '
          '${selected ? 'Showing only these. Tap to clear.' : 'Tap to filter.'}',
      excludeSemantics: true,
      child: AdaptiveTap(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Opacity(
          opacity: dimmed ? 0.4 : 1,
          child: SizedBox(
            height: 24,
            child: Row(
              children: [
                SizedBox(width: 10, child: Text('$star', style: style)),
                const SizedBox(width: 8),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: SizedBox(
                      height: 6,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          const ColoredBox(color: ReviewTokens.tint),
                          FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: fraction.clamp(0.0, 1.0),
                            child: const DecoratedBox(
                              decoration: BoxDecoration(
                                color: ReviewTokens.brand,
                                borderRadius: BorderRadius.all(
                                  Radius.circular(3),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 18,
                  child: Text(
                    '$count',
                    textAlign: TextAlign.right,
                    style: style,
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
