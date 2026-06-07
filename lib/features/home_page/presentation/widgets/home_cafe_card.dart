import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:nook/core/cafe/domain/entities/cafe_summary.dart';
import 'package:nook/core/presentation/widgets/cafe_card_image.dart';
import 'package:nook/core/utils/adaptive_tap.dart';
import 'package:nook/core/utils/tag_icon_resolver.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:nook/core/extensions/extensions.dart';

class HomeCafeCard extends StatelessWidget {
  final CafeSummary cafe;
  final bool isSkeleton;

  const HomeCafeCard({super.key, required this.cafe, this.isSkeleton = false});

  static double cardWidth = 280.0;
  static const double _imageAspectRatio = 16 / 10;

  @override
  Widget build(BuildContext context) {
    final double width = cardWidth;
    final double imgHeight = width / _imageAspectRatio;

    final String imageUrl = cafe.coverImage?.trim().isNotEmpty == true
        ? cafe.coverImage!.trim()
        : 'https://images.unsplash.com/photo-1497935586351-b67a49e012bf';

    final String ratingText = cafe.rating.toStringAsFixed(1);
    final String? primaryTag = cafe.tags.isNotEmpty ? cafe.tags.first : null;

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
            // Image
            Stack(
              children: [
                Skeleton.replace(
                  replace: isSkeleton,
                  replacement: Container(
                    height: imgHeight,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: CafeCardImage(
                      imageUrl: imageUrl,
                      height: imgHeight,
                      width: double.infinity,
                    ),
                  ),
                ),
                Positioned(
                  top: 10,
                  left: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Icon(
                          PhosphorIconsFill.star,
                          color: context.colorScheme.primary60,
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          ratingText,
                          style: context.textTheme.bodyExtraSmallMed.copyWith(
                            color: context.colorScheme.black,
                            height: 1.1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            // Info
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    cafe.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.textTheme.bodyLargeSemi,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Icon(
                        LucideIcons.mapPin400,
                        size: 14,
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
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (primaryTag != null && primaryTag.trim().isNotEmpty)
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: isSkeleton
                                  ? null
                                  : Border.all(
                                      color: context.colorScheme.primary60,
                                    ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (resolveTagIcon(primaryTag) != null) ...[
                                  Icon(
                                    resolveTagIcon(primaryTag),
                                    size: 12,
                                    color: context.colorScheme.primary60,
                                  ),
                                  const SizedBox(width: 4),
                                ],
                                Flexible(
                                  child: Text(
                                    primaryTag,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: context.textTheme.bodySmallMed
                                        .copyWith(
                                          color: context.colorScheme.gray,
                                        ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        const SizedBox.shrink(),
                      const SizedBox(width: 6),
                      Text(
                        cafe.distanceMeters != null
                            ? '${(cafe.distanceMeters! / 1000).toStringAsFixed(1)} km'
                            : '',
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
