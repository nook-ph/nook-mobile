import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:nook/core/cafe/domain/entities/cafe_summary.dart';
import 'package:nook/core/extensions/extensions.dart';
import 'package:nook/core/presentation/widgets/cafe_card_image.dart';
import 'package:nook/core/presentation/widgets/cafe_status_badge.dart';
import 'package:nook/core/utils/adaptive_tap.dart';
import 'package:nook/features/home_page/presentation/widgets/home_meta_line.dart';
import 'package:nook/features/home_page/presentation/widgets/home_tag_chip.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:skeletonizer/skeletonizer.dart';

const _fallbackImage =
    'https://images.unsplash.com/photo-1497935586351-b67a49e012bf';

/// The compact card of the New / Trending / Top Rated / Near you rows: photo,
/// name, one meta line and one tag.
class HomeCafeCard extends StatelessWidget {
  final CafeSummary cafe;
  final bool isSkeleton;
  final double width;
  final double height;

  const HomeCafeCard({
    super.key,
    required this.cafe,
    required this.width,
    required this.height,
    this.isSkeleton = false,
  });

  @override
  Widget build(BuildContext context) {
    final String imageUrl = cafe.coverImage?.trim().isNotEmpty == true
        ? cafe.coverImage!.trim()
        : _fallbackImage;
    final String? primaryTag =
        cafe.tags.isNotEmpty && cafe.tags.first.trim().isNotEmpty
        ? cafe.tags.first.trim()
        : null;

    return AdaptiveTap(
      borderRadius: BorderRadius.circular(12),
      onTap: () {
        if (isSkeleton) return;
        if (cafe.id.isNotEmpty) context.push('/cafe/${cafe.id}');
      },
      child: SizedBox(
        width: width,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                Skeleton.replace(
                  replace: isSkeleton,
                  replacement: Container(
                    height: height,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: context.colorScheme.offWhite,
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: CafeCardImage(
                      imageUrl: imageUrl,
                      height: height,
                      width: double.infinity,
                    ),
                  ),
                ),
                // Your own status owns the top-left corner: it is the one
                // thing on a card that is about you rather than the cafe.
                if (!isSkeleton)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: CafeStatusBadge(cafeId: cafe.id),
                  ),
                // The community rating sits in the opposite corner and only
                // renders once there is something to average: "0.0" beside
                // an empty star made every new cafe look bad.
                if (!isSkeleton && cafe.reviewCount > 0)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: HomeRatingPill(rating: cafe.rating),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              cafe.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.textTheme.bodyLargeSemi.copyWith(
                color: context.colorScheme.black,
                fontSize: 14,
                fontWeight: FontWeight.w500,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 2),
            HomeMetaLine(
              area: homeCardArea(cafe),
              lat: cafe.lat,
              lng: cafe.lng,
            ),
            if (!isSkeleton) HomeOpenLine(hours: cafe.operatingHours),
            if (primaryTag != null) ...[
              // Figma: 2 between the lines plus the tag row's own 4 on top.
              const SizedBox(height: 6),
              HomeTagChip(label: primaryTag, isSkeleton: isSkeleton),
            ],
          ],
        ),
      ),
    );
  }
}

/// "★ 4.8" on a white pill over a card photo.
class HomeRatingPill extends StatelessWidget {
  const HomeRatingPill({super.key, required this.rating});

  final double rating;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: context.colorScheme.white,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            PhosphorIconsFill.star,
            color: context.colorScheme.primary60,
            size: 11,
          ),
          const SizedBox(width: 3),
          Text(
            rating.toStringAsFixed(1),
            style: context.textTheme.bodyExtraSmallMed.copyWith(
              color: context.colorScheme.black,
              fontSize: 10,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
