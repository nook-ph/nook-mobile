import 'package:flutter/material.dart';

class ReviewCard extends StatelessWidget {
  const ReviewCard({
    super.key,
    required this.name,
    required this.date,
    required this.rating,
    required this.reviewText,
    this.photos = const [],
  });

  final String name;
  final String date;
  final double rating;
  final String reviewText;
  final List<String> photos; // list of image URLs

  @override
  Widget build(BuildContext context) {
    const double cardWidth = 344;
    const int maxVisiblePhotos = 3;
    const double photoSize = 100;
    const double photoSpacing = 8;

    final int extraCount = photos.length > maxVisiblePhotos
        ? photos.length - maxVisiblePhotos + 1
        : 0;
    final List<String> visiblePhotos = photos.length > maxVisiblePhotos
        ? photos.sublist(0, maxVisiblePhotos - 1)
        : photos;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE0E0E0), width: 1.0),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header row: name + rating
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Colors.black,
                  ),
                ),
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: rating.toStringAsFixed(1),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Colors.black,
                        ),
                      ),
                      const TextSpan(
                        text: '/5',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            // Date + Stars row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  date,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF588157),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                _StarRow(rating: rating),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(color: Color(0xFFE0E0E0), height: 1),
            const SizedBox(height: 12),
            // Review text
            Text(
              reviewText,
              style: const TextStyle(
                fontSize: 13,
                color: Colors.black87,
                height: 1.4,
              ),
            ),
            // Photos section (only shown if photos is not empty)
            if (photos.isNotEmpty) ...[
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  // Visible photos
                  ...visiblePhotos.asMap().entries.map((entry) {
                    return Padding(
                      padding: EdgeInsets.only(
                        right: entry.key < visiblePhotos.length - 1 || extraCount > 0
                            ? photoSpacing
                            : 0,
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          entry.value,
                          width: photoSize,
                          height: photoSize,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _PhotoPlaceholder(
                            size: photoSize,
                          ),
                        ),
                      ),
                    );
                  }),
                  // "+N" overflow tile
                  if (extraCount > 0)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Stack(
                        children: [
                          Image.network(
                            photos[maxVisiblePhotos - 1],
                            width: photoSize,
                            height: photoSize,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _PhotoPlaceholder(
                              size: photoSize,
                            ),
                          ),
                          Container(
                            width: photoSize,
                            height: photoSize,
                            color: Colors.black.withOpacity(0.45),
                            alignment: Alignment.center,
                            child: Text(
                              '+$extraCount',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StarRow extends StatelessWidget {
  const _StarRow({required this.rating});

  final double rating;

  @override
  Widget build(BuildContext context) {
    const int totalStars = 5;
    const Color starColor = Color(0xFF588157);
    const double starSize = 16;

    return Row(
      children: List.generate(totalStars, (index) {
        final double fill = (rating - index).clamp(0.0, 1.0);
        if (fill >= 1.0) {
          return const Icon(Icons.star, color: starColor, size: starSize);
        } else if (fill > 0.0) {
          return const Icon(Icons.star_half, color: starColor, size: starSize);
        } else {
          return const Icon(Icons.star_border, color: starColor, size: starSize);
        }
      }),
    );
  }
}

class _PhotoPlaceholder extends StatelessWidget {
  const _PhotoPlaceholder({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFFD0D0D0),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(Icons.image, color: Colors.white54),
    );
  }
}
