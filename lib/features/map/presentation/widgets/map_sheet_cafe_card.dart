import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:nook/core/cafe/domain/entities/cafe_summary.dart';
import 'package:nook/core/presentation/widgets/cafe_summary_overflow_tags_row.dart';
import 'package:nook/utils/theme/custom_themes/color_scheme.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:skeletonizer/skeletonizer.dart';

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

    return SizedBox(
      width: width,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          context.push('/cafe/${cafe.id}');
        },
        child: Column(
          children: [
            Expanded(
              flex: 22,
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
                    child: Image.network(
                      imageUrl,
                      width: double.infinity,
                      height: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: Colors.grey[300],
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.image_not_supported_outlined,
                            color: Color(0xFF9E9E9E),
                          ),
                        );
                      },
                    ),
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
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                PhosphorIconsFill.star,
                                size: 14,
                                color: colors.primary100,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                cafe.rating.toStringAsFixed(1),
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '(${cafe.reviewCount})',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF848586),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          const Icon(
                            LucideIcons.mapPin500,
                            size: 12,
                            color: Color(0xFF848586),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              cafe.locationLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF848586),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  CafeSummaryOverflowTagsRow(
                    tags: cafe.tags,
                    isSkeleton: isSkeleton,
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
