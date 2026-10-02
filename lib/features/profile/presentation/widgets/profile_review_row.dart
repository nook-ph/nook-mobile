import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:nook/core/cafe/domain/entities/cafe_details.dart';
import 'package:nook/core/presentation/widgets/cafe_card_image.dart';
import 'package:nook/core/presentation/widgets/review_photo_viewer.dart';
import 'package:nook/core/utils/adaptive_tap.dart';
import 'package:nook/features/profile/presentation/profile_logic.dart';
import 'package:nook/features/profile/presentation/widgets/profile_tokens.dart';
import 'package:nook/features/profile/presentation/widgets/profile_ui.dart';

/// One of the signed-in user's reviews as a plain row: the cafe's photo and
/// name, the date, the stars, the text and its photos. [onMore] opens the
/// options for it.
class ProfileReviewRow extends StatelessWidget {
  const ProfileReviewRow({super.key, required this.review, this.onMore});

  final WrittenReview review;
  final VoidCallback? onMore;

  static const _photoSize = 72.0;
  static const _maxPhotos = 4;

  @override
  Widget build(BuildContext context) {
    final photos = review.imageUrls;
    final shown = photos.take(_maxPhotos).toList();
    final text = review.content.trim();
    final date = formatReviewDate(review.createdAt);
    final more = onMore;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const _CafeThumb(),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    review.cafeName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: ProfileTokens.text(14, weight: FontWeight.w500),
                  ),
                  Text(
                    date,
                    style: ProfileTokens.text(10, color: ProfileTokens.muted),
                  ),
                ],
              ),
            ),
            if (more != null)
              AdaptiveTap(
                onTap: more,
                borderRadius: BorderRadius.circular(22),
                child: Semantics(
                  button: true,
                  label: 'Review options',
                  // The 18 glyph sits flush right in a 44 touch target.
                  child: const SizedBox(
                    width: 44,
                    height: 40,
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Icon(
                        LucideIcons.ellipsis,
                        size: 18,
                        color: ProfileTokens.ink,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        ProfileStars(rating: review.rating),
        if (text.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(text, style: ProfileTokens.text(14)),
        ],
        if (shown.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 0; i < shown.length; i++)
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => showReviewPhotoViewer(
                    context,
                    imageUrls: photos,
                    initialIndex: i,
                    date: date,
                    cafeName: review.cafeName,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Stack(
                      children: [
                        CafeCardImage(
                          imageUrl: shown[i],
                          width: _photoSize,
                          height: _photoSize,
                        ),
                        if (i == shown.length - 1 &&
                            photos.length > shown.length)
                          Container(
                            width: _photoSize,
                            height: _photoSize,
                            color: const Color(0x73000000),
                            alignment: Alignment.center,
                            child: Text(
                              '+${photos.length - shown.length}',
                              style: ProfileTokens.text(
                                14,
                                weight: FontWeight.w500,
                                color: ProfileTokens.surface,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

/// The 40pt square that leads a review row. The reviews query carries no
/// cafe photo yet, so this is a tinted tile until it does.
class _CafeThumb extends StatelessWidget {
  const _CafeThumb();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: ProfileTokens.tint,
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Icon(
        LucideIcons.coffee,
        size: 18,
        color: ProfileTokens.muted,
      ),
    );
  }
}

/// Five 14pt stars, filled up to [rating], 2 apart.
class ProfileStars extends StatelessWidget {
  const ProfileStars({super.key, required this.rating});

  final int rating;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$rating out of 5 stars',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 1; i <= 5; i++) ...[
            if (i > 1) const SizedBox(width: 2),
            Icon(
              i <= rating ? Icons.star : Icons.star_border,
              size: 14,
              color: i <= rating ? ProfileTokens.star : ProfileTokens.starEmpty,
            ),
          ],
        ],
      ),
    );
  }
}

/// [reviews] as rows with a hairline between them.
class ProfileReviewList extends StatelessWidget {
  const ProfileReviewList({
    super.key,
    required this.reviews,
    required this.onMore,
  });

  final List<WrittenReview> reviews;
  final ValueChanged<WrittenReview> onMore;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < reviews.length; i++) ...[
          if (i > 0) ...[
            const SizedBox(height: 16),
            const ProfileDivider(),
            const SizedBox(height: 16),
          ],
          ProfileReviewRow(
            key: ValueKey('review-${reviews[i].id}'),
            review: reviews[i],
            onMore: () => onMore(reviews[i]),
          ),
        ],
      ],
    );
  }
}

/// [count] grey review rows, shown while the reviews load.
class ProfileReviewSkeleton extends StatelessWidget {
  const ProfileReviewSkeleton({super.key, this.count = 3});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Loading reviews',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < count; i++) ...[
            if (i > 0) const SizedBox(height: 20),
            const Row(
              children: [
                ProfileSkeleton(width: 40, height: 40, radius: 10),
                SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ProfileSkeleton(width: 150, height: 14),
                    SizedBox(height: 6),
                    ProfileSkeleton(width: 80, height: 10),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            const ProfileSkeleton(width: 90, height: 12),
            const SizedBox(height: 10),
            const ProfileSkeleton(height: 12),
            const SizedBox(height: 10),
            const FractionallySizedBox(
              widthFactor: 260 / 350,
              child: ProfileSkeleton(height: 12),
            ),
          ],
        ],
      ),
    );
  }
}
