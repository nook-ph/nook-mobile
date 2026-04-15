import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:nook/features/cafe_details/presentation/pages/cafe_details_page.dart';
import 'package:nook/features/home_page/domain/entities/cafe_summary_entity.dart';
import 'package:skeletonizer/skeletonizer.dart';

class HomeCafeCard extends StatelessWidget {
  final CafeSummaryEntity cafe;
  final bool isSkeleton;

  const HomeCafeCard({
    super.key,
    required this.cafe,
    this.isSkeleton = false,
  });

  @override
  Widget build(BuildContext context) {
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
            builder: (context) => CafeDetailsPage(cafeId: cafe.id),
          ),
        );
      },
      child: Align(
        alignment: Alignment.topCenter,
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
                      child: Image.network(imageUrl, fit: BoxFit.cover),
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
                            cafe.address,
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
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: isSkeleton
                                  ? null
                                  : Border.all(color: const Color(0xFFE0E0E0)),
                            ),
                            child: Text(
                              primaryTag,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.black54,
                                height: 1.1, // 3. Tightened line height
                              ),
                            ),
                          )
                        else
                          const SizedBox.shrink(),
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
