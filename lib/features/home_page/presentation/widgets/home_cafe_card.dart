import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:nook/core/cafe/domain/entities/cafe_summary.dart';
import 'package:nook/core/utils/tag_icon_resolver.dart';
import 'package:skeletonizer/skeletonizer.dart';

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
      child: GestureDetector(
        // Opaque ensures the entire area of the container intercepts the tap
        behavior: HitTestBehavior.opaque,
        onTap: () {
          // Prevent navigation if the card is in its skeleton/loading state
          if (isSkeleton) return;

          if (cafe.id.isNotEmpty) {
            context.push('/cafe/${cafe.id}');
          }
        },
        child: Container(
          width: 200,
          clipBehavior: Clip.hardEdge,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: isSkeleton
                ? null
                : Border.all(color: const Color(0xFFE0E0E0), width: 1.0),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  Skeleton.replace(
                    replace: isSkeleton,
                    replacement: Container(
                      height: 120,
                      width: double.infinity,
                      color: Colors.black,
                    ),
                    child: SizedBox(
                      height: 120,
                      width: double.infinity,
                      child: Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        // Ensure image doesn't block hits if loading fails
                        errorBuilder: (context, error, stackTrace) => Container(
                          height: 120,
                          color: Colors.grey[200],
                          child: const Icon(Icons.broken_image),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.star,
                            color: Color(0xFF588157),
                            size: 12,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            ratingText,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cafe.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          LucideIcons.mapPin500,
                          size: 11,
                          color: Color(0xFF848586),
                        ),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            cafe.locationLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF848586),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
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
                                        color: const Color(0xFFE0E0E0),
                                      ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (resolveTagIcon(primaryTag) != null) ...[
                                    Icon(
                                      resolveTagIcon(primaryTag),
                                      size: 11,
                                      color: Colors.black54,
                                    ),
                                    const SizedBox(width: 3),
                                  ],
                                  Flexible(
                                    child: Text(
                                      primaryTag,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Colors.black54,
                                        height: 1.1,
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
                        const Text(
                          '5.0 km',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF848685),
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
