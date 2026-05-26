import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:nook/utils/theme/custom_themes/color_scheme.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';

class ReviewCard extends StatelessWidget {
  const ReviewCard({
    super.key,
    required this.username,
    required this.cafeReviewed,
    required this.date,
    required this.rating,
    required this.reviewText,
    this.avatarUrl,
    this.photos = const [],
    this.isOwner = false,
    this.helpfulCount = 0,
    this.onHelpfulTap,
    this.onMoreTap,
  });

  final String username;
  final String cafeReviewed;
  final String date;
  final double rating;
  final String reviewText;
  final String? avatarUrl;
  final List<String> photos;
  final bool isOwner;
  final int helpfulCount;
  final VoidCallback? onHelpfulTap;
  final VoidCallback? onMoreTap;

  @override
  Widget build(BuildContext context) {
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
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE0E0E0), width: 1.0),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header: avatar + name/cafe + stars
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: const Color(0xFFE0E0E0),
                  backgroundImage: avatarUrl != null
                      ? NetworkImage(avatarUrl!)
                      : null,
                  child: avatarUrl == null
                      ? const Icon(Icons.person, color: Colors.white54)
                      : null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      RichText(
                        text: TextSpan(
                          style: const TextStyle(
                            fontSize: 15,
                            color: Colors.black,
                          ),
                          children: [
                            TextSpan(
                              text: username,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const TextSpan(
                              text: ' reviewed ',
                              style: TextStyle(
                                color: Colors.black54,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                            TextSpan(
                              text: cafeReviewed,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        date,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.black45,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _StarRow(rating: rating),
              ],
            ),
            const SizedBox(height: 14),
            // Review text
            Text(
              reviewText,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black87,
                height: 1.45,
              ),
            ),
            // Photos section
            if (photos.isNotEmpty) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  ...visiblePhotos.asMap().entries.map((entry) {
                    return Padding(
                      padding: EdgeInsets.only(
                        right:
                            entry.key < visiblePhotos.length - 1 ||
                                extraCount > 0
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
                          errorBuilder: (_, __, ___) =>
                              _PhotoPlaceholder(size: photoSize),
                        ),
                      ),
                    );
                  }),
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
                            errorBuilder: (_, __, ___) =>
                                _PhotoPlaceholder(size: photoSize),
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
            // Footer: hidden for owner, shown for public
            if (!isOwner) ...[
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: onHelpfulTap,
                    child: Row(
                      children: [
                        const Icon(
                          Icons.thumb_up_outlined,
                          size: 18,
                          color: Color(0xFF588157),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          helpfulCount > 0
                              ? 'helpful ($helpfulCount)'
                              : 'helpful',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF588157),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: onMoreTap,
                    child: const Icon(
                      Icons.more_horiz,
                      color: Colors.black54,
                      size: 22,
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
    return RatingBarIndicator(
      rating: rating,
      itemBuilder: (context, index) => Icon(
        PhosphorIconsFill.star,
        color: Theme.of(context).colorScheme.primary60,
      ),
      itemCount: 5,
      itemSize: 14,
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
