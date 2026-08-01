import 'package:flutter/material.dart';
import 'package:nook/core/presentation/widgets/cafe_status_badge.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:nook/core/cafe/domain/entities/cafe_summary.dart';
import 'package:nook/core/presentation/widgets/cafe_distance_label.dart';
import 'package:nook/core/presentation/widgets/cafe_card_image.dart';
import 'package:nook/core/presentation/widgets/cafe_summary_overflow_tags_row.dart';
import 'package:nook/core/utils/adaptive_tap.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:nook/core/extensions/extensions.dart';

class FeaturedCard extends StatelessWidget {
  final CafeSummary cafe;
  final bool isSkeleton;
  final double width;
  final double height;

  const FeaturedCard({
    super.key,
    required this.width,
    required this.height,
    required this.cafe,
    this.isSkeleton = false,
  });

  static double cardWidth = 410.0;

  @override
  Widget build(BuildContext context) {
    final double imgHeight = height;

    final String imageUrl = cafe.coverImage?.trim().isNotEmpty == true
        ? cafe.coverImage!.trim()
        : 'https://images.unsplash.com/photo-1497935586351-b67a49e012bf';

    return AdaptiveTap(
      borderRadius: BorderRadius.circular(12),
      onTap: () {
        context.push('/cafe/${cafe.id}');
      },
      child: Container(
        width: width,
        clipBehavior: Clip.hardEdge,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: isSkeleton
              ? null
              : Border.all(color: context.colorScheme.border, width: 1.0),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Stack(
              children: [
                Skeleton.replace(
                  replace: isSkeleton,
                  replacement: Container(
                    height: imgHeight,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(12),
                        topRight: Radius.circular(12),
                      ),
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(12),
                      topRight: Radius.circular(12),
                    ),
                    child: CafeCardImage(
                      imageUrl: imageUrl,
                      height: imgHeight,
                      width: double.infinity,
                    ),
                  ),
                ),
                if (!isSkeleton)
                  Positioned(
                    top: 10,
                    left: 10,
                    child: CafeStatusBadge(cafeId: cafe.id),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Text(
                          cafe.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.textTheme.titleMediumSemi.copyWith(
                            color: context.colorScheme.black,
                          ),
                        ),
                      ),
                      // Nothing to average yet — "0.0 (0)" reads as a verdict
                      // rather than an absence.
                      if (cafe.reviewCount > 0)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              PhosphorIconsFill.star,
                              color: context.colorScheme.primary60,
                              size: 18,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              cafe.rating.toStringAsFixed(1),
                              style: context.textTheme.bodyLargeMed.copyWith(
                                color: context.colorScheme.black,
                                height: 1.2,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '(${cafe.reviewCount})',
                              style: context.textTheme.bodyMediumMed.copyWith(
                                color: context.colorScheme.gray,
                                height: 1.1,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        LucideIcons.mapPin400,
                        size: 16,
                        color: context.colorScheme.gray,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          cafe.locationLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.textTheme.bodyMedium!.copyWith(
                            color: context.colorScheme.gray,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
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
                      // Always device-relative; see CafeDistanceLabel.
                      CafeDistanceLabel(
                        lat: cafe.lat,
                        lng: cafe.lng,
                        style: context.textTheme.bodyMedium!.copyWith(
                          color: context.colorScheme.gray,
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
