import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nook/core/block/block_cubit.dart';
import 'package:nook/core/utils/adaptive_tap.dart';
import 'package:nook/features/cafe_details/bloc/reviews_bloc.dart';
import 'package:nook/features/cafe_details/bloc/reviews_state.dart';
import 'package:nook/features/cafe_details/domain/entities/cafe_details_entity.dart';
import 'package:nook/features/cafe_details/presentation/utils/cafe_load_failure.dart';
import 'package:nook/features/cafe_details/presentation/widgets/cafe_details_common.dart';
import 'package:nook/features/cafe_details/presentation/widgets/reviews_logic.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

/// How many reviews carry each star rating, as the summary on the details
/// page draws it. Pure, so the counting is testable.
class ReviewDistribution {
  const ReviewDistribution._(this.counts, this.total, this.average);

  /// Index 0 is one star, index 4 is five stars.
  final List<int> counts;
  final int total;
  final double average;

  factory ReviewDistribution.from(Iterable<int> ratings) {
    final counts = List<int>.filled(5, 0);
    var sum = 0;
    var total = 0;
    for (final rating in ratings) {
      if (rating < 1 || rating > 5) continue;
      counts[rating - 1]++;
      sum += rating;
      total++;
    }
    return ReviewDistribution._(counts, total, total == 0 ? 0 : sum / total);
  }

  int countFor(int star) => counts[star - 1];

  /// Share of all reviews with [star] stars, 0 to 1.
  double fractionFor(int star) => total == 0 ? 0 : countFor(star) / total;
}

/// Reviews on the details page: the score with its spread, a sideways strip
/// of review cards so the section stays one card tall, and the way into the
/// full list.
class ReviewsPreviewSection extends StatelessWidget {
  const ReviewsPreviewSection({
    super.key,
    required this.onSeeAllTap,
    required this.onWriteReviewTap,
    this.currentUserId,
    this.onRetry,
  });

  final VoidCallback onSeeAllTap;
  final VoidCallback onWriteReviewTap;

  /// Reloads the reviews after a failed load. No retry is offered when null.
  final VoidCallback? onRetry;

  /// Who is signed in; null for a guest. One review per cafe, so the Write
  /// pill goes once this user has one here.
  final String? currentUserId;

  static const _previewCount = 6;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ReviewsBloc, ReviewsState>(
      builder: (context, state) {
        if (state is ReviewsError) {
          // The shared copy, never the exception's own text.
          final info = CafeLoadFailure.from(state.error ?? state.message).info;
          final retry = onRetry;
          return _Shell(
            onWriteReviewTap: null,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Reviews could not load. ${info.subtitle}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: CafeDetailsTokens.muted,
                  ),
                ),
                if (retry != null) ...[
                  const SizedBox(height: 12),
                  _OutlinedWideButton(label: 'Try again', onTap: retry),
                ],
              ],
            ),
          );
        }

        if (state is! ReviewsLoaded) {
          return const _Shell(onWriteReviewTap: null, child: _LoadingBody());
        }

        final blockedIds = context.watch<BlockCubit>().state;
        final reviews = state.reviews
            .where((review) => !blockedIds.contains(review.userId))
            .toList();

        if (reviews.isEmpty) {
          return _Shell(
            onWriteReviewTap: null,
            child: _EmptyBody(onWriteReviewTap: onWriteReviewTap),
          );
        }

        final distribution = ReviewDistribution.from(
          reviews.map((r) => r.rating),
        );
        final count = reviews.length;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Shell(
              onWriteReviewTap: hasOwnReview(reviews, currentUserId)
                  ? null
                  : onWriteReviewTap,
              child: _Summary(distribution: distribution),
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: _ReviewPreviewCard.height,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: CafeDetailsTokens.gutter,
                ),
                itemCount: reviews.length.clamp(0, _previewCount),
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (context, index) => _ReviewPreviewCard(
                  review: reviews[index],
                  onTap: onSeeAllTap,
                ),
              ),
            ),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: CafeDetailsTokens.gutter,
              ),
              child: _OutlinedWideButton(
                label: count == 1 ? 'See 1 review' : 'See all $count reviews',
                onTap: onSeeAllTap,
              ),
            ),
          ],
        );
      },
    );
  }
}

/// The section heading row and gutter, shared by every state.
class _Shell extends StatelessWidget {
  const _Shell({required this.child, required this.onWriteReviewTap});

  final Widget child;
  final VoidCallback? onWriteReviewTap;

  @override
  Widget build(BuildContext context) {
    final onWrite = onWriteReviewTap;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: CafeDetailsTokens.gutter),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(child: CafeSectionTitle('Reviews')),
              if (onWrite != null) _WriteReviewPill(onTap: onWrite),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _WriteReviewPill extends StatelessWidget {
  const _WriteReviewPill({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AdaptiveTap(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      // The pill is 32 tall as drawn; the padding around it makes the
      // touch target 44.
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Container(
          height: 32,
          padding: const EdgeInsets.only(left: 10, right: 14),
          decoration: BoxDecoration(
            color: CafeDetailsTokens.brand,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(PhosphorIcons.plus(), size: 14, color: Colors.white),
              const SizedBox(width: 4),
              Text(
                'Write a review',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.distribution});

  final ReviewDistribution distribution;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final total = distribution.total;
    return Row(
      children: [
        Text(
          distribution.average.toStringAsFixed(1),
          style: textTheme.titleLarge?.copyWith(
            fontSize: 32,
            fontWeight: FontWeight.w600,
            color: CafeDetailsTokens.ink,
            height: 1.1,
          ),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            ReviewStars(rating: distribution.average.round(), size: 16),
            const SizedBox(height: 2),
            Text(
              total == 1 ? '1 review' : '$total reviews',
              style: textTheme.bodySmall?.copyWith(
                color: CafeDetailsTokens.muted,
              ),
            ),
          ],
        ),
        const SizedBox(width: 20),
        Expanded(
          child: Semantics(
            label: [
              for (var star = 5; star >= 1; star--)
                '$star stars: ${distribution.countFor(star)}',
            ].join(', '),
            child: ExcludeSemantics(
              child: Column(
                children: [
                  for (var star = 5; star >= 1; star--)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 10,
                            child: Text(
                              '$star',
                              style: textTheme.bodySmall?.copyWith(
                                fontSize: 10,
                                color: CafeDetailsTokens.muted,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(2),
                              child: SizedBox(
                                height: 4,
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    const ColoredBox(
                                      color: CafeDetailsTokens.tint,
                                    ),
                                    FractionallySizedBox(
                                      alignment: Alignment.centerLeft,
                                      widthFactor: distribution.fractionFor(
                                        star,
                                      ),
                                      child: const ColoredBox(
                                        color: CafeDetailsTokens.brand,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Five stars, the first [rating] of them filled.
class ReviewStars extends StatelessWidget {
  const ReviewStars({super.key, required this.rating, this.size = 12});

  final int rating;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$rating out of 5 stars',
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 1; i <= 5; i++)
              Padding(
                padding: EdgeInsets.only(left: i == 1 ? 0 : 2),
                child: Icon(
                  i <= rating
                      ? PhosphorIconsFill.star
                      : PhosphorIconsRegular.star,
                  size: size,
                  color: i <= rating
                      ? CafeDetailsTokens.star
                      : const Color(0xFFC4C4C4),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ReviewPreviewCard extends StatelessWidget {
  const _ReviewPreviewCard({required this.review, required this.onTap});

  final ReviewEntity review;
  final VoidCallback onTap;

  static const height = 150.0;
  static const _width = 290.0;

  static const _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  static String formatDate(DateTime date) =>
      '${_months[date.month - 1]} ${date.day}, ${date.year}';

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final name = (review.name ?? '').trim().isEmpty
        ? 'Anonymous'
        : review.name!.trim();

    return AdaptiveTap(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: _width,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          border: Border.all(color: CafeDetailsTokens.border),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: Color(0xFFDAD7CD),
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    name[0].toUpperCase(),
                    style: textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w500,
                      color: CafeDetailsTokens.ink,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w500,
                          color: CafeDetailsTokens.ink,
                        ),
                      ),
                      Text(
                        formatDate(review.createdAt),
                        style: textTheme.bodySmall?.copyWith(
                          fontSize: 10,
                          color: CafeDetailsTokens.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                ReviewStars(rating: review.rating),
              ],
            ),
            const SizedBox(height: 10),
            Expanded(
              child: Text(
                review.content,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: textTheme.bodySmall?.copyWith(
                  color: CafeDetailsTokens.ink,
                  height: 1.5,
                ),
              ),
            ),
            if (review.helpfulCount > 0)
              Row(
                children: [
                  Icon(
                    PhosphorIcons.thumbsUp(),
                    size: 14,
                    color: CafeDetailsTokens.muted,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Helpful · ${review.helpfulCount}',
                    style: textTheme.bodySmall?.copyWith(
                      fontSize: 10,
                      color: CafeDetailsTokens.muted,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _OutlinedWideButton extends StatelessWidget {
  const _OutlinedWideButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AdaptiveTap(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        constraints: const BoxConstraints(minHeight: 48),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border.all(color: CafeDetailsTokens.border),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.w500,
            color: CafeDetailsTokens.brand,
          ),
        ),
      ),
    );
  }
}

class _EmptyBody extends StatelessWidget {
  const _EmptyBody({required this.onWriteReviewTap});

  final VoidCallback onWriteReviewTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 22, 16, 16),
      decoration: BoxDecoration(
        color: CafeDetailsTokens.tint,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(
            PhosphorIcons.chatCircle(),
            size: 24,
            color: CafeDetailsTokens.muted,
          ),
          const SizedBox(height: 8),
          Text(
            'No reviews yet',
            style: textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w600,
              color: CafeDetailsTokens.ink,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Be the first to leave a review!',
            textAlign: TextAlign.center,
            style: textTheme.bodySmall?.copyWith(
              color: CafeDetailsTokens.muted,
            ),
          ),
          const SizedBox(height: 16),
          AdaptiveTap(
            onTap: onWriteReviewTap,
            borderRadius: BorderRadius.circular(999),
            child: Container(
              constraints: const BoxConstraints(minHeight: 48),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: CafeDetailsTokens.brand,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                'Write a review',
                style: textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingBody extends StatelessWidget {
  const _LoadingBody();

  @override
  Widget build(BuildContext context) {
    Widget box(double height, {double? width}) => Container(
      height: height,
      width: width,
      decoration: BoxDecoration(
        color: CafeDetailsTokens.tint,
        borderRadius: BorderRadius.circular(8),
      ),
    );
    return Semantics(
      label: 'Loading reviews',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [box(40, width: 180), const SizedBox(height: 14), box(120)],
      ),
    );
  }
}
