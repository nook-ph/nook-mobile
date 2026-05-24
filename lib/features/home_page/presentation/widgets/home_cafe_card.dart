import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:nook/core/cafe/domain/entities/cafe_summary.dart';
import 'package:nook/core/utils/adaptive_tap.dart';
import 'package:nook/core/utils/tag_icon_resolver.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:nook/utils/theme/custom_themes/text_theme.dart';
import 'package:nook/utils/theme/custom_themes/color_scheme.dart';

class HomeCafeCard extends StatelessWidget {
  final CafeSummary cafe;
  final bool isSkeleton;

  const HomeCafeCard({super.key, required this.cafe, this.isSkeleton = false});

  @override
  Widget build(BuildContext context) {
    final String imageUrl = cafe.coverImage?.trim().isNotEmpty == true
        ? cafe.coverImage!.trim()
        : 'https://images.unsplash.com/photo-1497935586351-b67a49e012bf';
    final String ratingText = cafe.rating.toStringAsFixed(1);
    final String? primaryTag = cafe.tags.isNotEmpty ? cafe.tags.first : null;

    return Align(
      alignment: Alignment.topCenter,
      child: AdaptiveTap(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          if (isSkeleton) return;
          if (cafe.id.isNotEmpty) {
            context.push('/cafe/${cafe.id}');
          }
        },
        child: Container(
          width: 280,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(12)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  Skeleton.replace(
                    replace: isSkeleton,
                    replacement: Container(
                      height: 180,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: SizedBox(
                        height: 180,
                        width: double.infinity,
                        child: Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              Container(
                                height: 120,
                                color: Colors.grey[200],
                                child: const Icon(Icons.broken_image),
                              ),
                        ),
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
                            color: Theme.of(context).colorScheme.primary60,
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            ratingText,
                            style: Theme.of(context).textTheme.bodyExtraSmallMed
                                .copyWith(
                                  color: Theme.of(context).colorScheme.black,
                                  height: 1.1,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cafe.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyLargeSemi,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Icon(
                          LucideIcons.mapPin400,
                          size: 14,
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
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.primary60,
                                      ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (resolveTagIcon(primaryTag) != null) ...[
                                    Icon(
                                      resolveTagIcon(primaryTag),
                                      size: 12,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary60,
                                    ),
                                    const SizedBox(width: 4),
                                  ],
                                  Flexible(
                                    child: Text(
                                      primaryTag,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmallMed
                                          .copyWith(
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.primary40,
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
                          '5.0 km',
                          style: Theme.of(context).textTheme.bodyExtraSmallMed
                              .copyWith(
                                color: Theme.of(context).colorScheme.gray,
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
      ),
    );
  }
}
