import 'package:flutter/material.dart';

class ReviewsSection extends StatelessWidget {
  const ReviewsSection({super.key, required this.onSeeMoreTap});

  final VoidCallback onSeeMoreTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Reviews',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 16),
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
                        Text(
                          'Reviewer name',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.black,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 6),
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
              ),
              SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '4.8',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.black,
                    ),
                  ),
                  SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.star, size: 12, color: Color(0xFFFFB800)),
                      Icon(Icons.star, size: 12, color: Color(0xFFFFB800)),
                      Icon(Icons.star, size: 12, color: Color(0xFFFFB800)),
                      Icon(Icons.star, size: 12, color: Color(0xFFFFB800)),
                      Icon(
                        Icons.star_border,
                        size: 12,
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
