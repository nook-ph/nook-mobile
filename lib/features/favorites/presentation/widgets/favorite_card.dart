import 'package:flutter/material.dart';
import 'package:nook/core/cafe/domain/entities/cafe_summary.dart';
import 'package:nook/features/cafe_details/presentation/pages/cafe_details_page.dart';

class FavoriteCard extends StatelessWidget {
  final CafeSummary cafe;

  const FavoriteCard({super.key, required this.cafe});

  @override
  Widget build(BuildContext context) {
    // Handle image URL safely
    final String imageUrl = cafe.coverImage?.trim().isNotEmpty == true
      ? cafe.coverImage!.trim()
        : 'https://images.unsplash.com/photo-1497935586351-b67a49e012bf';

    final String ratingText = cafe.rating.toStringAsFixed(1);

    const String distancePlaceholder = "0.8km away";
    const String descriptionPlaceholder =
        '"The seasonal pour-over here is unmatched. Quiet, airy..."';

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CafeDetailsPage(cafeId: cafe.id),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        height: 112, // Fixed height to match RecommendedCard
        width: double.infinity,
        clipBehavior: Clip.hardEdge, // Ensures image clips to border radius
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color(0xFFE0E0E0),
            width: 1.0,
          ), // No shadow, just border
        ),
        child: Row(
          children: [
            // Left Side: Image spanning full height
            Expanded(
              flex: 4,
              child: Image.network(
                imageUrl,
                width: double.infinity,
                height: double.infinity,
                fit: BoxFit.cover,
              ),
            ),

            // Right Side: Cafe Details
            Expanded(
              flex: 8,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top: Title & Heart Icon
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            cafe.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                        const Icon(
                          Icons.favorite,
                          color: Color(0xFF1B4D3E), // Dark green
                          size:
                              20, // Slightly smaller to fit nicely in the flex layout
                        ),
                      ],
                    ),

                    // Middle: Rating & Distance
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.star,
                          color: Color(0xFFF29C38),
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          ratingText,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 6.0),
                          child: Text(
                            '•',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.black38,
                            ),
                          ),
                        ),
                        const Text(
                          distancePlaceholder,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.black54,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),

                    // Bottom: Italicized Description
                    const Text(
                      descriptionPlaceholder,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontStyle: FontStyle.italic,
                        color: Colors.black54,
                        height: 1.2,
                      ),
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
