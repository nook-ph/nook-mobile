import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nook/features/cafe_details/bloc/reviews_bloc.dart';
import 'package:nook/features/cafe_details/bloc/reviews_state.dart';
import 'package:nook/features/cafe_details/domain/entities/cafe_details_entity.dart';

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
    return BlocBuilder<ReviewsBloc, ReviewsState>(
      builder: (context, state) {
        if (state is ReviewsError) {
          return _ErrorReviewsSection(message: state.message);
        }

        if (state is! ReviewsLoaded) {
          return const _LoadingReviewsSection();
        }

        final reviews = state.reviews;
        if (reviews.isEmpty) {
          return _EmptyReviewsSection(onWriteReviewTap: onWriteReviewTap);
        }

        final displayedReviews = reviews.take(3).toList();
        final resolvedReviewCount = reviews.length;
        final resolvedRating = _averageRating(reviews);

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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.star_rounded,
                        color: Colors.black,
                        size: 22,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        resolvedRating.toStringAsFixed(1),
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: Colors.black,
                          height: 1,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    '$resolvedReviewCount Reviews',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: Color(0xFF616161),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ...displayedReviews
                  .map(
                    (review) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: ReviewCard(review: review),
                    ),
                  )
                  .toList(),
              const SizedBox(height: 4),
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
      },
    );
  }

  double _averageRating(List<ReviewEntity> reviews) {
    if (reviews.isEmpty) return 0;

    final total = reviews.fold<int>(0, (sum, review) => sum + review.rating);
    return total / reviews.length;
  }
}

class _LoadingReviewsSection extends StatelessWidget {
  const _LoadingReviewsSection();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Reviews',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w500,
              color: Colors.black,
            ),
          ),
          SizedBox(height: 16),
          Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 28),
              child: CircularProgressIndicator(color: Color(0xFF344E41)),
            ),
          ),
          SizedBox(height: 40),
        ],
      ),
    );
  }
}

class _ErrorReviewsSection extends StatelessWidget {
  const _ErrorReviewsSection({required this.message});

  final String message;

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
              fontSize: 20,
              fontWeight: FontWeight.w500,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w400,
              color: Color(0xFF848685),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

class _EmptyReviewsSection extends StatelessWidget {
  const _EmptyReviewsSection({required this.onWriteReviewTap});

  final VoidCallback onWriteReviewTap;

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
              fontSize: 20,
              fontWeight: FontWeight.w500,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 16),
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
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
              ),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

class ReviewCard extends StatefulWidget {
  const ReviewCard({super.key, required this.review});

  final ReviewEntity review;

  @override
  State<ReviewCard> createState() => _ReviewCardState();
}

class _ReviewCardState extends State<ReviewCard> {
  bool _isExpanded = false;
  static const int _collapsedCharLimit = 90;

  @override
  Widget build(BuildContext context) {
    final reviewContent = widget.review.content;
    final hasOverflow = reviewContent.length > _collapsedCharLimit;
    final reviewPreview = hasOverflow
        ? '${reviewContent.substring(0, _collapsedCharLimit).trimRight()}...'
        : reviewContent;
    final resolvedImageUrls = widget.review.imageUrls
      .map(_resolveImageUrl)
      .where((url) => url.isNotEmpty)
      .toList(growable: false);

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
          Row(
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
                          backgroundColor: const Color(0xFFE0E0E0),
                          child: Text(
                            _avatarInitial(widget.review.name),
                            style: const TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.review.name ?? 'Anonymous',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black,
                                ),
                              ),
                              Text(
                                _formatDate(widget.review.createdAt),
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w400,
                                  color: Color(0xFF848685),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                fit: FlexFit.loose,
                child: Align(
                  alignment: Alignment.topRight,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(5, (index) {
                      final isFilled = index < widget.review.rating;
                      return Icon(
                        isFilled ? Icons.star : Icons.star_border,
                        size: 16,
                        color: const Color(0xFFFFB800),
                      );
                    }),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Divider(height: 1, thickness: 1, color: Color(0xFFE0E0E0)),
          const SizedBox(height: 18),
          Text(
            _isExpanded ? reviewContent : reviewPreview,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w400,
              color: Color(0xFF848685),
            ),
          ),
          if (resolvedImageUrls.isNotEmpty) ...[
            const SizedBox(height: 14),
            _buildImageStrip(resolvedImageUrls),
          ],
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
        ],
      ),
    );
  }

  String _avatarInitial(String? name) {
    if (name == null || name.trim().isEmpty) {
      return 'A';
    }

    return name.trim()[0].toUpperCase();
  }

  Widget _buildImageStrip(List<String> imageUrls) {
    final visibleUrls = imageUrls.take(3).toList(growable: false);
    final count = visibleUrls.length;
    final height = _imageHeightForCount(count);

    if (count == 1) {
      return _buildImageTile(url: visibleUrls.first, height: height);
    }

    return SizedBox(
      height: height,
      child: Row(
        children: [
          for (int i = 0; i < visibleUrls.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            Expanded(
              child: _buildImageTile(url: visibleUrls[i], height: height),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildImageTile({required String url, required double height}) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.network(
          url,
          fit: BoxFit.cover,
          errorBuilder: (_, error, ___) {
            debugPrint('[ReviewCard] image load failed url=$url error=$error');
            return Container(
              color: const Color(0xFFF0F0F0),
              child: const Icon(
                Icons.broken_image_outlined,
                color: Color(0xFFBDBDBD),
              ),
            );
          },
        ),
      ),
    );
  }

  double _imageHeightForCount(int count) {
    if (count <= 1) return 156;
    if (count == 2) return 122;
    return 94;
  }

  String _formatDate(DateTime date) {
    final mm = date.month.toString().padLeft(2, '0');
    final dd = date.day.toString().padLeft(2, '0');
    final yy = (date.year % 100).toString().padLeft(2, '0');
    return '$mm/$dd/$yy';
  }

  String _resolveImageUrl(String raw) {
    var candidate = raw.trim();
    if (candidate.isEmpty) return '';

    if ((candidate.startsWith('"') && candidate.endsWith('"')) ||
        (candidate.startsWith("'") && candidate.endsWith("'"))) {
      candidate = candidate.substring(1, candidate.length - 1).trim();
    }

    if (candidate.startsWith('//')) {
      candidate = 'https:$candidate';
    }

    // Repair malformed values like "https://https://host/path".
    while (true) {
      final lowered = candidate.toLowerCase();
      if (lowered.startsWith('https://https://')) {
        candidate = 'https://${candidate.substring('https://https://'.length)}';
        continue;
      }
      if (lowered.startsWith('http://http://')) {
        candidate = 'http://${candidate.substring('http://http://'.length)}';
        continue;
      }
      if (lowered.startsWith('http://https://')) {
        candidate = 'https://${candidate.substring('http://https://'.length)}';
        continue;
      }
      if (lowered.startsWith('https://http://')) {
        candidate = 'https://${candidate.substring('https://http://'.length)}';
        continue;
      }
      break;
    }

    Uri? parsed;
    try {
      parsed = Uri.parse(candidate);
    } catch (_) {
      return '';
    }

    if ((parsed.host == 'https' || parsed.host == 'http') &&
        parsed.path.startsWith('//')) {
      candidate = 'https:${parsed.path}';
      try {
        parsed = Uri.parse(candidate);
      } catch (_) {
        return '';
      }
    }

    if (!parsed.hasScheme) {
      candidate = 'https://$candidate';
      try {
        parsed = Uri.parse(candidate);
      } catch (_) {
        return '';
      }
    }

    if (parsed.scheme == 'http' &&
        parsed.host.isNotEmpty &&
        parsed.host != 'localhost' &&
        parsed.host != '127.0.0.1') {
      parsed = parsed.replace(scheme: 'https');
    }

    return parsed.toString();
  }
}
