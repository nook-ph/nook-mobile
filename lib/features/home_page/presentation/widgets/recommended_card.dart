import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:nook/features/cafe_details/presentation/pages/cafe_details_page.dart';
import 'package:nook/features/home_page/domain/entities/cafe_summary_entity.dart';

class RecommendedCard extends StatelessWidget {
  final CafeSummaryEntity cafe;
  const RecommendedCard({super.key, required this.cafe});

  @override
  Widget build(BuildContext context) {
    final String heroTag = 'recommended_${cafe.id}';
    final String imageUrl = cafe.featuredImageUrl?.trim().isNotEmpty == true
        ? cafe.featuredImageUrl!.trim()
        : 'https://images.unsplash.com/photo-1497935586351-b67a49e012bf';
    final String ratingText = cafe.rating.toStringAsFixed(1);
    final String? primaryTag = cafe.tags.isNotEmpty ? cafe.tags.first : null;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CafeDetailsPage(heroTag: heroTag),
          ),
        );
      },
      child: Container(
        width: double.infinity,
        clipBehavior: Clip.hardEdge,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE0E0E0), width: 1.0),
        ),
        height: 112,
        child: Row(
          children: [
            Expanded(
              flex: 4,
              child: Hero(
                tag: heroTag,
                child: Image.network(
                  imageUrl,
                  width: double.infinity,
                  height: double.infinity,
                  fit: BoxFit.cover,
                ),
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
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  ratingText,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                const Icon(
                                  Icons.star,
                                  color: Color(0xFF588157),
                                  size: 16,
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
                                cafe.address,
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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            if (primaryTag != null &&
                                primaryTag.trim().isNotEmpty)
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
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.black54,
                                  ),
                                ),
                              ),
                            if (primaryTag != null &&
                                primaryTag.trim().isNotEmpty)
                              const SizedBox(width: 6),
                          ],
                        ),
                        const Text(
                          '5.0 km',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF848685),
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
