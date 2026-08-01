import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:nook/core/cafe/domain/cafe_open_status.dart';
import 'package:nook/core/cafe/domain/entities/cafe_summary.dart';
import 'package:nook/core/utils/adaptive_tap.dart';
import 'package:nook/core/presentation/widgets/cafe_card_image.dart';
import 'package:nook/core/presentation/widgets/cafe_open_badge.dart';
import 'package:nook/core/presentation/widgets/cafe_rating_label.dart';
import 'package:nook/core/presentation/widgets/cafe_summary_overflow_tags_row.dart';
import 'package:nook/utils/theme/custom_themes/color_scheme.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:nook/utils/theme/custom_themes/text_theme.dart';

/// Map bottom-sheet list row: hero image, then info + tags.
class MapSheetCafeCard extends StatelessWidget {
  const MapSheetCafeCard({
    super.key,
    required this.width,
    required this.cafe,
    this.isSkeleton = false,
  });

  final double width;
  final CafeSummary cafe;
  final bool isSkeleton;

  static const String _fallbackImageUrl =
      'https://images.unsplash.com/photo-1497935586351-b67a49e012bf';

  /// Featured image, else first extra photo, else fallback.
  static String _imageUrl(CafeSummary cafe) {
    final featured = cafe.coverImage?.trim();
    if (featured != null && featured.isNotEmpty) {
      return featured;
    }
    for (final raw in cafe.photoUrls) {
      final url = raw.trim();
      if (url.isNotEmpty) return url;
    }
    return _fallbackImageUrl;
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final imageUrl = _imageUrl(cafe);
    // Skeleton rows carry a placeholder cafe, so suppress the badge rather than
    // flash a real status onto a shimmering card.
    final openStatus = isSkeleton
        ? CafeOpenStatus.unknown
        : CafeOpenStatus.resolve(cafe.operatingHours);

    return SizedBox(
      width: width,
      child: AdaptiveTap(
        onTap: () {
          context.push('/cafe/${cafe.id}');
        },
        child: Column(
          children: [
            Expanded(
              flex: 30,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Skeleton.replace(
                    replace: isSkeleton,
                    replacement: Container(
                      width: double.infinity,
                      height: double.infinity,
                      color: Colors.black,
                    ),
                    child: CafeCardImage(imageUrl: imageUrl),
                  ),
                ),
              ),
            ),
            Expanded(
              flex: 11,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              cafe.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleMediumSemi
                                  .copyWith(
                                    color: Theme.of(context).colorScheme.black,
                                  ),
                            ),
                          ),
                          if (cafe.reviewCount > 0) const SizedBox(width: 8),
                          CafeRatingLabel(
                            rating: cafe.rating,
                            reviewCount: cafe.reviewCount,
                            starSize: 18,
                            starColor: colors.primary60,
                            ratingStyle: Theme.of(context)
                                .textTheme
                                .bodyLargeMed
                                .copyWith(color: colors.black, height: 1.2),
                            countStyle: Theme.of(context)
                                .textTheme
                                .bodyMediumMed
                                .copyWith(color: colors.gray, height: 1.1),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Icon(
                            LucideIcons.mapPin400,
                            size: 16,
                            color: Theme.of(context).colorScheme.gray,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              cafe.locationLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodyMedium!
                                  .copyWith(
                                    color: Theme.of(context).colorScheme.gray,
                                  ),
                            ),
                          ),
                          // Kept out of the Expanded so the status always fits
                          // and the address truncates instead — "Open" is the
                          // more decision-relevant of the two.
                          if (openStatus.state != CafeOpenState.unknown) ...[
                            const SizedBox(width: 8),
                            CafeOpenBadge(status: openStatus),
                          ],
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: CafeSummaryOverflowTagsRow(
                          tags: cafe.tags,
                          isSkeleton: isSkeleton,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        cafe.distanceMeters != null
                            ? '${(cafe.distanceMeters! / 1000).toStringAsFixed(1)} km'
                            : '',
                        style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                          color: colors.gray,
                          height: 1.1,
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
    );
  }
}
