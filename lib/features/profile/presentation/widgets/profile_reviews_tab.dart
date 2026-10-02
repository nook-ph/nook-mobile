import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:nook/core/cafe/domain/entities/cafe_details.dart';
import 'package:nook/features/profile/presentation/profile_logic.dart';
import 'package:nook/features/profile/presentation/widgets/profile_review_row.dart';
import 'package:nook/features/profile/presentation/widgets/profile_tokens.dart';
import 'package:nook/features/profile/presentation/widgets/profile_ui.dart';

/// The Reviews tab of the profile: the user's latest reviews as plain rows,
/// with a way through to all of them when there are more than fit here.
class ProfileReviewsTab extends StatelessWidget {
  const ProfileReviewsTab({
    super.key,
    required this.reviews,
    required this.onMore,
    required this.onSeeAll,
    this.loading = false,
  });

  final List<WrittenReview> reviews;
  final bool loading;

  /// Opens the options for one review.
  final ValueChanged<WrittenReview> onMore;

  /// Opens the Your reviews page.
  final VoidCallback onSeeAll;

  /// How many reviews the tab shows before handing over to Your reviews.
  static const previewCount = 4;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const SingleChildScrollView(
        physics: NeverScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          ProfileTokens.gutter,
          20,
          ProfileTokens.gutter,
          24,
        ),
        child: ProfileReviewSkeleton(),
      );
    }

    if (reviews.isEmpty) {
      return const SingleChildScrollView(
        child: ProfileMessage(
          icon: LucideIcons.star,
          title: 'No reviews yet',
          subtitle: 'When you share reviews, they will appear here.',
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        ProfileTokens.gutter,
        16,
        ProfileTokens.gutter,
        24,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ProfileReviewList(
            reviews: reviews.take(previewCount).toList(),
            onMore: onMore,
          ),
          if (reviews.length > previewCount) ...[
            const SizedBox(height: 20),
            ProfilePillButton(
              label: 'See all ${reviewCountLabel(reviews.length)}',
              onTap: onSeeAll,
              style: ProfilePillStyle.outlined,
              height: 44,
            ),
          ],
        ],
      ),
    );
  }
}
