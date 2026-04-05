import 'package:flutter/material.dart';

class ReviewsSection extends StatelessWidget {
  const ReviewsSection({
    super.key,
    required this.onSeeMoreTap,
    required this.onWriteReviewTap,
  });

  final VoidCallback onSeeMoreTap;
  final VoidCallback onWriteReviewTap;

  @override
  Widget build(BuildContext context) {
    const bool hasReviews = true;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Reviews',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w500,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 16),
          if (hasReviews) ...[
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.star_rounded, color: Colors.black, size: 22),
                    SizedBox(width: 8),
                    Text(
                      '4.2',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: Colors.black,
                        height: 1,
                      ),
                    ),
                  ],
                ),
                Text(
                  '643 Reviews',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: Color(0xFF616161),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
          if (hasReviews) ...[
            const ReviewCardPlaceholder(photoCount: 1),
            const SizedBox(height: 12),
            const ReviewCardPlaceholder(photoCount: 2),
            const SizedBox(height: 12),
            const ReviewCardPlaceholder(photoCount: 3),
            const SizedBox(height: 12),
            const ReviewCardPlaceholder(photoCount: 0),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: onSeeMoreTap,
                style: OutlinedButton.styleFrom(
                  backgroundColor: Colors.white,
                  side: const BorderSide(color: Color(0xFFE0E0E0), width: 1),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text(
                  'See more',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ] else
            Column(
              children: [
                const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.rate_review_outlined,
                          size: 64,
                          color: Color(0xFFBDBDBD),
                        ),
                        SizedBox(height: 12),
                        Text(
                          'No reviews yet',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.black,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Be the first to leave a review!',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w400,
                            color: Color(0xFF848685),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: onWriteReviewTap,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF344E41),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text(
                      'Write a Review',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

class ReviewCardPlaceholder extends StatefulWidget {
  const ReviewCardPlaceholder({super.key, this.photoCount = 0});

  final int photoCount;

  @override
  State<ReviewCardPlaceholder> createState() => _ReviewCardPlaceholderState();
}

class _ReviewCardPlaceholderState extends State<ReviewCardPlaceholder> {
  bool _isExpanded = false;
  static const int _collapsedCharLimit = 90;

  static const String _reviewContent =
      'SHERRY SHERRY SHERRY SHERRYSHERRYSHERRYSHERRYSHERRYSHERRYSHERRYSHERRYSHERRYSHERRYSHERRYSHERRYSHERRYSHERRY';

  @override
  Widget build(BuildContext context) {
    final bool hasOverflow = _reviewContent.length > _collapsedCharLimit;
    final String reviewPreview = hasOverflow
        ? '${_reviewContent.substring(0, _collapsedCharLimit).trimRight()}...'
        : _reviewContent;
    final int visiblePhotoCount = widget.photoCount > 3 ? 3 : widget.photoCount;
    final double photoHeight = switch (visiblePhotoCount) {
      1 => 156,
      2 => 128,
      _ => 104,
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE0E0E0), width: 1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: Color(0xFFE0E0E0),
                        ),
                        SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Reviewer name',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.black,
                              ),
                            ),

                            Text(
                              '00/00/00',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w400,
                                color: Color(0xFF848685),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    children: [
                      Icon(Icons.star, size: 16, color: Color(0xFFFFB800)),
                      Icon(Icons.star, size: 16, color: Color(0xFFFFB800)),
                      Icon(Icons.star, size: 16, color: Color(0xFFFFB800)),
                      Icon(Icons.star, size: 16, color: Color(0xFFFFB800)),
                      Icon(
                        Icons.star_border,
                        size: 16,
                        color: Color(0xFFFFB800),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Divider(height: 1, thickness: 1, color: Color(0xFFE0E0E0)),
          const SizedBox(height: 18),
          Text(
            _isExpanded ? _reviewContent : reviewPreview,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w400,
              color: Color(0xFF848685),
            ),
          ),
          if (hasOverflow) ...[
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () {
                setState(() {
                  _isExpanded = !_isExpanded;
                });
              },
              child: Text(
                _isExpanded ? 'See less' : 'See more',
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
          if (visiblePhotoCount > 0) ...[
            const SizedBox(height: 18),
            Row(
              children: List.generate(visiblePhotoCount, (index) {
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      right: index == visiblePhotoCount - 1 ? 0 : 8,
                    ),
                    child: Container(
                      height: photoHeight,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE9E9E9),
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ],
        ],
      ),
    );
  }
}
