import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:nook/core/block/block_cubit.dart';
import 'package:nook/core/cafe/domain/use_cases/delete_review_usecase.dart';
import 'package:nook/core/extensions/extensions.dart';
import 'package:nook/core/utils/adaptive_tap.dart';
import 'package:nook/core/utils/error_info.dart';
import 'package:nook/core/utils/toast_helper.dart';
import 'package:nook/features/cafe_details/bloc/cafe_details_bloc.dart';
import 'package:nook/features/cafe_details/bloc/cafe_details_states.dart';
import 'package:nook/features/cafe_details/bloc/review_submit_bloc.dart';
import 'package:nook/features/cafe_details/bloc/review_submit_state.dart';
import 'package:nook/features/cafe_details/bloc/reviews_bloc.dart';
import 'package:nook/features/cafe_details/bloc/reviews_event.dart';
import 'package:nook/features/cafe_details/bloc/reviews_state.dart';
import 'package:nook/features/cafe_details/domain/entities/cafe_details_entity.dart';
import 'package:nook/features/cafe_details/presentation/utils/cafe_load_failure.dart';
import 'package:nook/features/cafe_details/presentation/widgets/cafe_guest_sign_in_sheet.dart';
import 'package:nook/features/cafe_details/presentation/widgets/review_row.dart';
import 'package:nook/features/cafe_details/presentation/widgets/review_sheet_shell.dart';
import 'package:nook/features/cafe_details/presentation/widgets/review_sort_sheet.dart';
import 'package:nook/features/cafe_details/presentation/widgets/reviews_logic.dart';
import 'package:nook/features/cafe_details/presentation/widgets/reviews_summary_header.dart';
import 'package:nook/features/cafe_details/presentation/widgets/write_review_sheet.dart';
import 'package:nook/injection_container.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Every review for one cafe: the score, the rating rows that double as the
/// filter, the sort pill, the list, and "Write a review" pinned underneath.
class ReviewsPage extends StatefulWidget {
  const ReviewsPage({
    super.key,
    required this.cafeId,
    this.cafeRating,
    this.reviewCount,
    this.cafeName,
    this.cafeImageUrl,
    this.currentUserId,
    this.deleteReview,
  });

  final String cafeId;
  final double? cafeRating;
  final int? reviewCount;

  /// Shown under the title and in the write sheet. Falls back to the cafe
  /// details already loaded above this page.
  final String? cafeName;
  final String? cafeImageUrl;

  /// Who is signed in; null for a guest. Defaults to the Supabase session.
  /// Tests pass their own.
  final ValueGetter<String?>? currentUserId;

  /// Deletes a review by id. Defaults to [DeleteReviewUseCase].
  final Future<void> Function(String reviewId)? deleteReview;

  @override
  State<ReviewsPage> createState() => _ReviewsPageState();
}

class _ReviewsPageState extends State<ReviewsPage> {
  static const _defaultSort = 'recommended';

  late final ReviewsBloc _reviewsBloc;
  String _sort = _defaultSort;
  int? _ratingFilter;

  /// The last load, which is never filtered: the rating filter is applied
  /// on the device, to rows that are all here already. The score, the rating
  /// rows and "has the user reviewed" are derived from it on every build, so
  /// they stay right while a rating filter is on and when the block list
  /// changes.
  List<ReviewEntity>? _allReviews;

  /// Reviews the user just deleted, hidden until the reload drops them.
  final Set<String> _deletedIds = {};

  @override
  void initState() {
    super.initState();
    _reviewsBloc = context.read<ReviewsBloc>();
    _resolveCafe();

    // The details page under this one shares the bloc and has loaded, or is
    // loading, exactly what this page opens with. Only ask when it has not.
    final state = _reviewsBloc.state;
    if (state is ReviewsLoaded && state.cafeId == widget.cafeId) {
      _allReviews = state.reviews;
    } else if (state is! ReviewsLoading) {
      _load();
    }
  }

  @override
  void dispose() {
    // The bloc is shared with the details page: hand it back in the default
    // order.
    if (_sort != _defaultSort) {
      _reviewsBloc.add(LoadReviewsRequested(cafeId: widget.cafeId));
    }
    super.dispose();
  }

  void _load() {
    _reviewsBloc.add(LoadReviewsRequested(cafeId: widget.cafeId, sort: _sort));
  }

  String? get _currentUserId {
    final resolve = widget.currentUserId;
    if (resolve != null) return resolve();
    return Supabase.instance.client.auth.currentUser?.id;
  }

  String? _cafeName;
  String? _cafeImageUrl;

  /// Read once, outside build: the name and photo for the title and the
  /// write sheet, from the cafe details already loaded above this page.
  void _resolveCafe() {
    final state = context.read<CafeDetailsBloc?>()?.state;
    final cafe = state is CafeDetailsLoaded ? state.data.cafeDetails : null;
    _cafeName = widget.cafeName ?? cafe?.name;
    _cafeImageUrl = widget.cafeImageUrl ?? cafe?.featuredImageUrl;
  }

  void _onRatingTap(int star) {
    setState(() => _ratingFilter = toggleRatingFilter(_ratingFilter, star));
  }

  void _clearFilter() {
    if (_ratingFilter == null) return;
    setState(() => _ratingFilter = null);
  }

  Future<void> _openSort() async {
    final chosen = await ReviewSortSheet.show(context, current: _sort);
    if (chosen == null || chosen == _sort || !mounted) return;
    setState(() => _sort = chosen);
    _load();
  }

  void _writeReview() {
    if (_currentUserId == null) {
      CafeGuestSignInSheet.show(context, action: CafeGuestAction.writeReview);
      return;
    }
    WriteReviewSheet.show(
      context,
      cafeId: widget.cafeId,
      cafeName: _cafeName,
      cafeImageUrl: _cafeImageUrl,
    );
  }

  /// Height of the pinned Write bar (hairline, 12 above the 48 button, then
  /// 8 or the home indicator), so toasts land above it.
  double _writeBarHeight() {
    final inset = MediaQuery.viewPaddingOf(context).bottom;
    return 61 + (inset > 8 ? inset : 8);
  }

  Future<void> _deleteOwnReview(ReviewEntity review) async {
    final delete = widget.deleteReview ?? sl<DeleteReviewUseCase>().call;
    try {
      await delete(review.id);
    } catch (_) {
      if (!mounted) return;
      showPrimaryToast(
        context,
        'Could not delete your review. Please try again.',
      );
      return;
    }
    if (!mounted) return;
    setState(() => _deletedIds.add(review.id));
    // The Write bar comes back with the delete, so the toast sits above it.
    showPrimaryToast(
      context,
      'Review deleted',
      bottomOffset: _writeBarHeight(),
    );
    _load();
  }

  void _onReviewsChanged(BuildContext context, ReviewsState state) {
    if (state is! ReviewsLoaded) return;
    setState(() => _allReviews = state.reviews);
  }

  @override
  Widget build(BuildContext context) {
    final cafeName = _cafeName;
    final state = context.watch<ReviewsBloc>().state;
    final blocked = context.watch<BlockCubit>().state;
    final userId = _currentUserId;

    List<ReviewEntity> visible(List<ReviewEntity> reviews) => visibleReviews(
      reviews,
      blockedUserIds: blocked,
      deletedReviewIds: _deletedIds,
    );

    final loaded = state is ReviewsLoaded;
    final failed = state is ReviewsError;
    final filter = _ratingFilter;
    final reviews = loaded
        ? pinOwnReviewFirst(
            visible(
              filter == null
                  ? state.reviews
                  : [
                      for (final review in state.reviews)
                        if (review.rating == filter) review,
                    ],
            ),
            userId,
          )
        : const <ReviewEntity>[];

    // Everything the cafe has, whatever the filter. Null on the first load.
    final all = _allReviews;
    final everyReview = all != null
        ? visible(all)
        : (loaded ? visible(state.reviews) : null);
    final summary = everyReview == null
        ? null
        : ReviewsSummary.from(everyReview);

    // One review per cafe: once the user has posted, the button goes. It is
    // also held back until the page knows, and when the load failed.
    final showWriteBar =
        !failed && everyReview != null && !hasOwnReview(everyReview, userId);
    final toastOffset = showWriteBar ? _writeBarHeight() : 0.0;

    final Widget body;
    if (state is ReviewsError) {
      body = _ErrorBody(
        info: CafeLoadFailure.from(state.error ?? state.message).info,
        onRetry: _load,
      );
    } else if (summary == null) {
      // First load: nothing to show yet, so skeleton the whole page.
      body = const _LoadingBody();
    } else if (loaded && summary.total == 0 && _ratingFilter == null) {
      body = const _EmptyBody();
    } else {
      // Built row by row: a cafe can have hundreds of reviews, each with
      // photos, and only a screenful is ever looked at.
      const leading = 3;
      body = ListView.builder(
        padding: const EdgeInsets.only(bottom: 24),
        itemCount:
            leading + (loaded && reviews.isNotEmpty ? reviews.length : 1),
        itemBuilder: (context, index) {
          if (index == 0) {
            return ReviewsSummaryHeader(
              summary: summary,
              ratingFilter: _ratingFilter,
              onRatingTap: _onRatingTap,
            );
          }
          if (index == 1) {
            return const Divider(
              height: 1,
              thickness: 1,
              color: ReviewTokens.border,
            );
          }
          if (index == 2) {
            return _Controls(
              count: loaded ? reviews.length : null,
              ratingFilter: _ratingFilter,
              sortLabel: reviewSortLabel(_sort),
              onClearFilter: _clearFilter,
              onSortTap: _openSort,
            );
          }
          if (!loaded) return const _ListSkeleton();
          if (reviews.isEmpty) {
            return _NoMatches(star: _ratingFilter, onShowAll: _clearFilter);
          }

          final i = index - leading;
          final review = reviews[i];
          return Column(
            key: ValueKey(review.id),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (i > 0)
                const Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: ReviewTokens.gutter,
                  ),
                  child: Divider(
                    height: 1,
                    thickness: 1,
                    color: ReviewTokens.border,
                  ),
                ),
              Padding(
                padding: _rowPadding(
                  first: i == 0,
                  own: review.userId == userId,
                ),
                child: ReviewRow(
                  key: ValueKey(review.id),
                  review: review,
                  isOwn: review.userId == userId,
                  currentUserId: userId,
                  cafeName: cafeName,
                  toastBottomOffset: toastOffset,
                  onDeleteConfirmed: () => _deleteOwnReview(review),
                ),
              ),
            ],
          );
        },
      );
    }

    return Scaffold(
      backgroundColor: ReviewTokens.surface,
      appBar: AppBar(
        backgroundColor: ReviewTokens.surface,
        surfaceTintColor: ReviewTokens.surface,
        shadowColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Reviews',
              style: context.textTheme.bodyLargeSemi.copyWith(
                color: ReviewTokens.ink,
                fontSize: 16,
              ),
            ),
            if (cafeName != null && cafeName.isNotEmpty)
              Text(
                cafeName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.textTheme.bodySmall?.copyWith(
                  color: ReviewTokens.muted,
                ),
              ),
          ],
        ),
        leading: AdaptiveTap(
          onTap: () => Navigator.of(context).pop(),
          child: const Padding(
            padding: EdgeInsets.all(8),
            child: Icon(Icons.arrow_back, color: ReviewTokens.ink),
          ),
        ),
      ),
      body: MultiBlocListener(
        listeners: [
          BlocListener<ReviewSubmitBloc, ReviewSubmitState>(
            listener: (context, state) {
              if (state is ReviewSubmitSuccess) _load();
            },
          ),
          BlocListener<ReviewsBloc, ReviewsState>(listener: _onReviewsChanged),
        ],
        child: body,
      ),
      bottomNavigationBar: showWriteBar ? _WriteBar(onTap: _writeReview) : null,
    );
  }

  /// Figma puts 16 between a review and the divider either side of it, and
  /// 4 above the first. The row's own tap targets already carry 4 above (the
  /// ⋯) and 11 below (Helpful), which is taken off here.
  static EdgeInsets _rowPadding({required bool first, required bool own}) {
    return EdgeInsets.fromLTRB(
      ReviewTokens.gutter,
      first ? (own ? 4 : 0) : (own ? 16 : 12),
      ReviewTokens.gutter,
      own ? 16 : 5,
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls({
    required this.count,
    required this.ratingFilter,
    required this.sortLabel,
    required this.onClearFilter,
    required this.onSortTap,
  });

  /// Null while the list is loading.
  final int? count;
  final int? ratingFilter;
  final String sortLabel;
  final VoidCallback onClearFilter;
  final VoidCallback onSortTap;

  @override
  Widget build(BuildContext context) {
    final filter = ratingFilter;
    final total = count;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        ReviewTokens.gutter,
        8,
        ReviewTokens.gutter,
        4,
      ),
      child: Row(
        children: [
          if (total != null)
            Text(
              reviewCountLabel(total),
              style: context.textTheme.bodyMediumMed.copyWith(
                color: ReviewTokens.ink,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          if (filter != null) ...[
            const SizedBox(width: 8),
            AdaptiveTap(
              onTap: onClearFilter,
              borderRadius: BorderRadius.circular(999),
              child: Semantics(
                button: true,
                label: 'Showing $filter star reviews. Tap to clear.',
                excludeSemantics: true,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 44),
                  child: Center(
                    widthFactor: 1,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: ReviewTokens.tint,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.star,
                            size: 12,
                            color: ReviewTokens.star,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            filter == 1 ? '1 star' : '$filter stars',
                            style: context.textTheme.bodySmallMed.copyWith(
                              color: ReviewTokens.ink,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.close,
                            size: 12,
                            color: ReviewTokens.ink,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
          const Spacer(),
          AdaptiveTap(
            onTap: onSortTap,
            borderRadius: BorderRadius.circular(999),
            child: Semantics(
              button: true,
              label: 'Sort by $sortLabel',
              excludeSemantics: true,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 44),
                child: Center(
                  widthFactor: 1,
                  child: Container(
                    height: 32,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: ReviewTokens.surface,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: ReviewTokens.border),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          sortLabel,
                          style: context.textTheme.bodySmallMed.copyWith(
                            color: ReviewTokens.ink,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(
                          LucideIcons.chevronDown,
                          size: 14,
                          color: ReviewTokens.mutedIcon,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WriteBar extends StatelessWidget {
  const _WriteBar({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: ReviewTokens.surface,
        border: Border(top: BorderSide(color: ReviewTokens.border)),
      ),
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(
          ReviewTokens.gutter,
          12,
          ReviewTokens.gutter,
          8,
        ),
        child: ReviewPrimaryButton(
          label: 'Write a review',
          icon: LucideIcons.plus,
          onTap: onTap,
        ),
      ),
    );
  }
}

class _EmptyBody extends StatelessWidget {
  const _EmptyBody();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ReviewStars(rating: 0, size: 28),
            const SizedBox(height: 16),
            Text(
              'No reviews yet',
              textAlign: TextAlign.center,
              style: context.textTheme.bodyLargeSemi.copyWith(
                color: ReviewTokens.ink,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Be the first to say what it is like to sit and work here.',
              textAlign: TextAlign.center,
              style: context.textTheme.bodyMedium?.copyWith(
                color: ReviewTokens.muted,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoMatches extends StatelessWidget {
  const _NoMatches({required this.star, required this.onShowAll});

  final int? star;
  final VoidCallback onShowAll;

  @override
  Widget build(BuildContext context) {
    final rating = star;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 40),
      child: Column(
        children: [
          Text(
            'No reviews found',
            style: context.textTheme.bodyLargeSemi.copyWith(
              color: ReviewTokens.ink,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            rating == null
                ? 'Nothing to show here yet.'
                : 'This cafe has no $rating-star reviews.',
            textAlign: TextAlign.center,
            style: context.textTheme.bodyMedium?.copyWith(
              color: ReviewTokens.muted,
              fontSize: 14,
            ),
          ),
          if (rating != null)
            AdaptiveTap(
              onTap: onShowAll,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  'Show all',
                  style: context.textTheme.bodyMediumMed.copyWith(
                    color: ReviewTokens.brand,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// The load failed: the shared error copy and one outlined action. The page
/// keeps its header; the Write bar is held back.
class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.info, required this.onRetry});

  final ErrorInfo info;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: const BoxDecoration(
                color: ReviewTokens.tint,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                LucideIcons.triangleAlert,
                size: 22,
                color: ReviewTokens.brand,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              info.title,
              textAlign: TextAlign.center,
              style: context.textTheme.bodyLargeSemi.copyWith(
                color: ReviewTokens.ink,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              info.subtitle,
              textAlign: TextAlign.center,
              style: context.textTheme.bodyMedium?.copyWith(
                color: ReviewTokens.muted,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),
            Semantics(
              button: true,
              child: AdaptiveTap(
                onTap: onRetry,
                borderRadius: BorderRadius.circular(999),
                child: Container(
                  height: 44,
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  decoration: BoxDecoration(
                    color: ReviewTokens.surface,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: ReviewTokens.border),
                  ),
                  child: Center(
                    widthFactor: 1,
                    child: Text(
                      'Try again',
                      style: context.textTheme.bodyMediumMed.copyWith(
                        color: ReviewTokens.ink,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Stand-in reviews with the real row's shape, for [Skeletonizer].
final List<ReviewEntity> _placeholderReviews = List.generate(
  4,
  (i) => ReviewEntity(
    id: 'placeholder-$i',
    cafeId: '',
    userId: '',
    rating: 5,
    content:
        'A placeholder line that stands in for review text while the real '
        'reviews are still loading from the server.',
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
    name: 'Reviewer name',
  ),
);

class _ListSkeleton extends StatelessWidget {
  const _ListSkeleton();

  @override
  Widget build(BuildContext context) {
    return Skeletonizer(
      enabled: true,
      child: Column(
        children: [
          for (final review in _placeholderReviews)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                ReviewTokens.gutter,
                12,
                ReviewTokens.gutter,
                5,
              ),
              child: ReviewRow(review: review, showOptions: false),
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
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      children: [
        Skeletonizer(
          enabled: true,
          child: ReviewsSummaryHeader(
            summary: const ReviewsSummary(
              average: 4.5,
              total: 10,
              counts: {5: 6, 4: 3, 3: 1},
            ),
            ratingFilter: null,
            onRatingTap: (_) {},
          ),
        ),
        const Divider(height: 1, thickness: 1, color: ReviewTokens.border),
        const SizedBox(height: 8),
        const _ListSkeleton(),
      ],
    );
  }
}
