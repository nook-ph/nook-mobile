import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:nook/core/cafe/domain/entities/cafe_summary.dart';
import 'package:nook/core/utils/adaptive_tap.dart';
import 'package:nook/features/cafe_details/presentation/pages/cafe_details_page.dart';
import 'package:nook/core/extensions/extensions.dart';

class RecommendedCard extends StatelessWidget {
  final CafeSummary cafe;
  const RecommendedCard({super.key, required this.cafe});

  @override
  Widget build(BuildContext context) {
    final String imageUrl = (cafe.coverImage?.trim().isNotEmpty ?? false)
        ? cafe.coverImage!.trim()
        : 'https://images.unsplash.com/photo-1497935586351-b67a49e012bf';

    final String ratingText = cafe.rating.toStringAsFixed(1);
    final String? primaryTag = cafe.tags.isNotEmpty
        ? cafe.tags.first.trim()
        : null;

    return AdaptiveTap(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CafeDetailsPage(cafeId: cafe.id),
          ),
        );
      },
      child: Container(
        width: double.infinity,
        height: 112,
        clipBehavior: Clip.hardEdge,
        decoration: BoxDecoration(
          color: Colors.white, // Added white background
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE0E0E0), width: 1.0),
        ),
        child: Row(
          children: [
            Expanded(
              flex: 4,
              child: Image.network(
                imageUrl,
                width: double.infinity,
                height: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
            Expanded(
              flex: 8,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                cafe.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(
                                  context,
                                ).textTheme.titleMediumSemi,
                              ),
                            ),
                            Row(
                              children: [
                                Text(
                                  ratingText,
                                  style: context.textTheme.bodySmallMed,
                                ),
                                const SizedBox(width: 4),
                                const Icon(
                                  Icons.star,
                                  color: Color(0xFF588157),
                                  size: 16,
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            const Icon(
                              LucideIcons.mapPin,
                              size: 12,
                              color: Color(0xFF848586),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                cafe.address,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: context.textTheme.bodySmallMed.copyWith(
                                  color: const Color(0xFF848586),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        if (primaryTag != null && primaryTag.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFFE0E0E0),
                              ),
                            ),
                            child: Text(
                              primaryTag,
                              style: context.textTheme.bodySmall?.copyWith(
                                color: Colors.black54,
                              ),
                            ),
                          )
                        else
                          const SizedBox.shrink(),
                        Text(
                          '5.0 km',
                          style: context.textTheme.bodySmallMed.copyWith(
                            color: const Color(0xFF848685),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
