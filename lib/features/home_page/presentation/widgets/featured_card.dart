import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:nook/features/cafe_details/presentation/pages/cafe_details_page.dart';
import 'package:nook/features/home_page/domain/entities/cafe_summary_entity.dart';

class FeaturedCard extends StatelessWidget {
  final CafeSummaryEntity cafe;

  const FeaturedCard({super.key, required this.width, required this.cafe});

  final double width;

  @override
  Widget build(BuildContext context) {
    final String heroTag = 'featured_${cafe.id}';
    final String imageUrl = cafe.featuredImageUrl?.trim().isNotEmpty == true
        ? cafe.featuredImageUrl!.trim()
        : 'https://images.unsplash.com/photo-1497935586351-b67a49e012bf';
    final List<String> visibleTags = cafe.tags.take(3).toList();

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
        height: 312,
        width: width,
        clipBehavior: Clip.hardEdge,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE0E0E0), width: 1.0),
        ),
        child: Column(
          children: [
            Expanded(
              flex: 19,
              child: Hero(
                tag: heroTag,
                child: Image.network(
                  imageUrl,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            Expanded(
              flex: 11,
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
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            if (cafe.systemBadge != null &&
                                cafe.systemBadge!.trim().isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: const Color(0xFF588157),
                                  ),
                                ),
                                child: Text(
                                  cafe.systemBadge!,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF588157),
                                  ),
                                ),
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
                                style: TextStyle(
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
                      children: [
                        for (int i = 0; i < visibleTags.length; i++) ...[
                          _TagChip(label: visibleTags[i]),
                          if (i != visibleTags.length - 1)
                            const SizedBox(width: 6),
                        ],
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

class _TagChip extends StatelessWidget {
  const _TagChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF588157)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          color: Color(0xFF588157),
        ),
      ),
    );
  }
}
