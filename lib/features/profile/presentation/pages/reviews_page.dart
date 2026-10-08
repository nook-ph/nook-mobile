import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:nook/core/cafe/domain/entities/cafe_details.dart';
import 'package:nook/core/utils/adaptive_tap.dart';
import 'package:nook/features/profile/presentation/cubit/profile_cubit.dart';
import 'package:nook/features/profile/presentation/profile_logic.dart';
import 'package:nook/features/profile/presentation/widgets/profile_review_row.dart';
import 'package:nook/features/profile/presentation/widgets/profile_review_sheets.dart';
import 'package:nook/features/profile/presentation/widgets/profile_sheet.dart';
import 'package:nook/features/profile/presentation/widgets/profile_tokens.dart';
import 'package:nook/features/profile/presentation/widgets/profile_ui.dart';

/// "Your reviews": everything the signed-in user has written, filtered by
/// star rating and sorted. Reads the reviews from the [ProfileCubit] above
/// it, so a delete here is gone from the profile too.
class ReviewsPage extends StatefulWidget {
  const ReviewsPage({super.key});

  @override
  State<ReviewsPage> createState() => _ReviewsPageState();
}

class _ReviewsPageState extends State<ReviewsPage> {
  /// Null shows every rating.
  int? _rating;
  ProfileReviewSort _sort = ProfileReviewSort.mostRecent;

  Future<void> _pickSort() async {
    final picked = await ProfileSheet.show<ProfileReviewSort>(
      context,
      builder: (_) => ProfileReviewSortSheet(selected: _sort),
    );
    if (picked == null || !mounted) return;
    setState(() => _sort = picked);
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ProfileCubit, ProfileState>(
      builder: (context, state) {
        final loaded = state is ProfileLoaded ? state : null;
        final failed =
            state is ProfileError || (loaded?.reviewsFailed ?? false);
        return Scaffold(
          backgroundColor: ProfileTokens.surface,
          appBar: ProfileNavBar(
            title: 'Your reviews',
            subtitle: loaded == null
                ? null
                : reviewCountLabel(loaded.reviews.length),
            textScaler: MediaQuery.textScalerOf(context),
          ),
          body: SafeArea(
            top: false,
            child: failed
                ? SingleChildScrollView(
                    child: ProfileMessage.error(
                      title: 'Could not load reviews.',
                      subtitle: 'Check your connection and try again.',
                      onAction: () =>
                          context.read<ProfileCubit>().loadProfile(),
                      top: 180,
                    ),
                  )
                : _content(loaded),
          ),
        );
      },
    );
  }

  /// The filter and sort controls over the list. [loaded] is null while the
  /// profile loads.
  Widget _content(ProfileLoaded? loaded) {
    final shown = loaded == null
        ? null
        : filterAndSortReviews(loaded.reviews, rating: _rating, sort: _sort);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(
            ProfileTokens.gutter,
            8,
            ProfileTokens.gutter,
            12,
          ),
          child: Row(
            children: [
              _RatingChip(
                selected: _rating == null,
                onTap: () => setState(() => _rating = null),
              ),
              for (var stars = 5; stars >= 1; stars--) ...[
                const SizedBox(width: 8),
                _RatingChip(
                  stars: stars,
                  selected: _rating == stars,
                  onTap: () => setState(() => _rating = stars),
                ),
              ],
            ],
          ),
        ),
        const ProfileDivider(),
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: ProfileTokens.gutter,
            vertical: 12,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  shown == null ? 'Loading…' : reviewCountLabel(shown.length),
                  style: ProfileTokens.text(14, weight: FontWeight.w600),
                ),
              ),
              _SortButton(label: _sort.label, onTap: _pickSort),
            ],
          ),
        ),
        Expanded(child: _list(loaded, shown)),
      ],
    );
  }

  Widget _list(ProfileLoaded? loaded, List<WrittenReview>? shown) {
    if (loaded == null || shown == null) {
      return const SingleChildScrollView(
        physics: NeverScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          ProfileTokens.gutter,
          8,
          ProfileTokens.gutter,
          24,
        ),
        child: ProfileReviewSkeleton(count: 4),
      );
    }

    if (loaded.reviews.isEmpty) {
      return const SingleChildScrollView(
        child: ProfileMessage(
          icon: LucideIcons.star,
          title: 'No reviews yet',
          subtitle: 'When you share reviews, they will appear here.',
          top: 80,
        ),
      );
    }

    final rating = _rating;
    if (shown.isEmpty) {
      return SingleChildScrollView(
        child: ProfileMessage(
          icon: LucideIcons.star,
          title: 'No reviews found.',
          subtitle: rating == null ? null : 'You have no $rating-star reviews.',
          actionLabel: 'Show all',
          onAction: () => setState(() => _rating = null),
          top: 80,
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        ProfileTokens.gutter,
        4,
        ProfileTokens.gutter,
        60,
      ),
      child: ProfileReviewList(
        reviews: shown,
        onMore: (review) => showProfileReviewOptions(context, review),
      ),
    );
  }
}

/// A rating filter pill: "All", or a number beside a star. Brand fill when
/// [selected], outlined otherwise.
class _RatingChip extends StatelessWidget {
  const _RatingChip({required this.selected, required this.onTap, this.stars});

  /// Null is the "All" chip.
  final int? stars;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final count = stars;
    return Semantics(
      button: true,
      selected: selected,
      label: count == null ? 'All ratings' : '$count stars',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? ProfileTokens.brand : null,
            borderRadius: BorderRadius.circular(100),
            // The same 1pt on both, so selecting a chip does not move it.
            border: Border.all(
              color: selected ? ProfileTokens.brand : ProfileTokens.border,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                count == null ? 'All' : '$count',
                style: ProfileTokens.text(
                  12,
                  weight: FontWeight.w500,
                  color: selected ? ProfileTokens.surface : ProfileTokens.ink,
                ),
              ),
              if (count != null) ...[
                const SizedBox(width: 4),
                Icon(
                  Icons.star,
                  size: 12,
                  color: selected ? ProfileTokens.surface : ProfileTokens.star,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// The outlined pill that names the current order and opens the sort sheet.
class _SortButton extends StatelessWidget {
  const _SortButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Sort by $label',
      excludeSemantics: true,
      child: AdaptiveTap(
        onTap: onTap,
        borderRadius: BorderRadius.circular(100),
        child: Container(
          constraints: const BoxConstraints(minHeight: 32),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: ProfileTokens.surface,
            borderRadius: BorderRadius.circular(100),
            border: Border.all(color: ProfileTokens.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: ProfileTokens.text(12, weight: FontWeight.w500),
              ),
              const SizedBox(width: 6),
              const Icon(
                LucideIcons.chevronDown,
                size: 14,
                color: ProfileTokens.ink,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
