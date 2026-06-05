import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:nook/core/cafe/domain/entities/cafe_summary.dart';
import 'package:nook/core/presentation/widgets/cafe_summary_overflow_tags_row.dart';
import 'package:nook/core/utils/adaptive_tap.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:nook/core/extensions/extensions.dart';

class FeaturedCard extends StatelessWidget {
  final CafeSummary cafe;
  final bool isSkeleton;
  final double width;

  const FeaturedCard({
    super.key,
    required this.width,
    required this.cafe,
    this.isSkeleton = false,
  });

  static double cardWidth = 420.0;

  @override
  Widget build(BuildContext context) {
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
            LayoutBuilder(
              builder: (context, constraints) {
                final imageHeight = constraints.maxWidth / (3 / 2);
                return SizedBox(
                  width: constraints.maxWidth,
                  height: imageHeight,
                  child: Skeleton.replace(
                    replace: isSkeleton,
                    replacement: Container(
                      width: double.infinity,
                      height: double.infinity,
                      color: Colors.black,
                    ),

                    child: Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      frameBuilder:
                          (context, child, frame, wasSynchronouslyLoaded) {
                            if (wasSynchronouslyLoaded) return child;
                            return AnimatedOpacity(
                              opacity: frame == null ? 0 : 1,
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeIn,
                              child: child,
                            );
                          },
                      errorBuilder: (context, error, stackTrace) => Container(
                        height: imageHeight,
                        color: Colors.grey[200],
                        child: const Icon(Icons.broken_image),
                      ),
                    ),
                  ),
                );
              },
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
