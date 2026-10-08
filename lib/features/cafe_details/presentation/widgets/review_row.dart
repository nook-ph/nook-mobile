import 'package:flutter/material.dart';
import 'package:nook/core/presentation/widgets/cafe_card_image.dart';
import 'package:nook/core/extensions/extensions.dart';
import 'package:nook/core/presentation/widgets/review_photo_viewer.dart';
import 'package:nook/core/utils/adaptive_tap.dart';
import 'package:nook/core/utils/toast_helper.dart';
import 'package:nook/features/cafe_details/domain/entities/cafe_details_entity.dart';
import 'package:nook/features/cafe_details/presentation/widgets/cafe_guest_sign_in_sheet.dart';
import 'package:nook/features/cafe_details/presentation/widgets/review_actions_sheet.dart';
import 'package:nook/features/cafe_details/presentation/widgets/review_sheet_shell.dart';
import 'package:nook/features/cafe_details/presentation/widgets/reviews_logic.dart';
import 'package:nook/features/public_profile/presentation/widgets/review_author_link.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// One review as the Reviews page lists it: a plain row, separated from its
/// neighbours by a divider. The signed-in user's own review is tinted and
/// labelled "Your review".
///
/// The ⋯ opens report and block on someone else's review, and delete on the
/// viewer's own. A guest sees it too: every review action asks them to sign
/// in rather than failing quietly.
class ReviewRow extends StatefulWidget {
  const ReviewRow({
    super.key,
    required this.review,
    this.isOwn = false,
    this.currentUserId,
    this.cafeId,
    this.cafeName,
    this.onDeleteConfirmed,
    this.toastBottomOffset = 0,
    this.showOptions = true,
  });

  final ReviewEntity review;
  final bool isOwn;

  /// Null for a guest.
  final String? currentUserId;

  /// The cafe the page is showing, filed with a report. The review's own
  /// `cafeId` is used when this is null.
  final String? cafeId;

  /// Named in the delete copy and the photo viewer caption.
  final String? cafeName;

  /// Called once the user has confirmed deleting their own review. The ⋯ is
  /// left off an own review when this is null.
  final VoidCallback? onDeleteConfirmed;

  /// Lifts report and block toasts above the page's pinned bar.
  final double toastBottomOffset;

  /// False for skeleton rows.
  final bool showOptions;

  @override
  State<ReviewRow> createState() => _ReviewRowState();
}

class _ReviewRowState extends State<ReviewRow> {
  /// Longer reviews collapse to this many characters behind "See more".
  static const int _collapsedCharLimit = 180;

  bool _expanded = false;
  late bool _helpful;
  late int _helpfulCount;
  bool _voting = false;

  @override
  void initState() {
    super.initState();
    _helpful = widget.review.hasVoted;
    _helpfulCount = widget.review.helpfulCount;
  }

  @override
  void didUpdateWidget(covariant ReviewRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.review.id != widget.review.id) {
      _helpful = widget.review.hasVoted;
      _helpfulCount = widget.review.helpfulCount;
      _expanded = false;
    }
  }

  bool get _hasOptions =>
      widget.showOptions && (!widget.isOwn || widget.onDeleteConfirmed != null);

  Future<void> _openOptions() async {
    final review = widget.review;
    if (widget.isOwn) {
      final confirmed = await showOwnReviewSheet(
        context,
        cafeName: widget.cafeName,
      );
      if (confirmed) widget.onDeleteConfirmed?.call();
      return;
    }
    await showReviewActionsSheet(
      context,
      reviewId: review.id,
      cafeId: widget.cafeId ?? review.cafeId,
      authorId: review.userId,
      authorName: review.name,
      toastBottomOffset: widget.toastBottomOffset,
      currentUserId: () => widget.currentUserId,
    );
  }

  Future<void> _toggleHelpful() async {
    // Marking your own review helpful is not a vote.
    if (_voting || widget.isOwn) return;
    final userId = widget.currentUserId;
    if (userId == null) {
      await CafeGuestSignInSheet.show(
        context,
        action: CafeGuestAction.helpfulReview,
      );
      return;
    }

    final wasHelpful = _helpful;
    setState(() {
      _voting = true;
      _helpful = !wasHelpful;
      _helpfulCount += wasHelpful ? -1 : 1;
    });

    try {
      final votes = Supabase.instance.client.from('review_helpful_votes');
      if (wasHelpful) {
        await votes
            .delete()
            .eq('review_id', widget.review.id)
            .eq('user_id', userId);
      } else {
        await votes.insert({'review_id': widget.review.id, 'user_id': userId});
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _helpful = wasHelpful;
          _helpfulCount += wasHelpful ? 1 : -1;
        });
        // The mark just flipped back; say why rather than leave it looking
        // like the tap was missed.
        showPrimaryToast(
          context,
          "Couldn't update. Please try again.",
          bottomOffset: widget.toastBottomOffset,
        );
      }
    } finally {
      if (mounted) setState(() => _voting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final review = widget.review;
    final name = (review.name ?? '').trim().isEmpty
        ? 'Anonymous'
        : review.name!.trim();
    final content = review.content.trim();
    final overflows = content.length > _collapsedCharLimit;
    final shown = overflows && !_expanded
        ? '${content.substring(0, _collapsedCharLimit).trimRight()}...'
        : content;
    final photos = review.imageUrls
        .map(resolveReviewImageUrl)
        .where((url) => url.isNotEmpty)
        .toList(growable: false);
    final date = formatReviewDate(review.createdAt);

    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // 44 tall for the ⋯ target; the avatar and names keep their 36.
        SizedBox(
          height: 44,
          child: Row(
            children: [
              Expanded(
                child: ReviewAuthorLink(
                  userId: review.userId,
                  name: name,
                  isOwn: widget.isOwn,
                  child: SizedBox(
                    height: 44,
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          alignment: Alignment.center,
                          decoration: const BoxDecoration(
                            color: Color(0xFFDAD7CD),
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            name[0].toUpperCase(),
                            style: context.textTheme.bodyMediumMed.copyWith(
                              color: ReviewTokens.ink,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              ReviewAuthorName(
                                name: name,
                                linked:
                                    !widget.isOwn && review.userId.isNotEmpty,
                                style: context.textTheme.bodyMediumMed.copyWith(
                                  color: ReviewTokens.ink,
                                  fontSize: 14,
                                  height: 1.5,
                                ),
                              ),
                              Text(
                                widget.isOwn ? 'Your review · $date' : date,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: context.textTheme.bodySmall?.copyWith(
                                  color: widget.isOwn
                                      ? ReviewTokens.brand
                                      : ReviewTokens.muted,
                                  fontSize: 10,
                                  height: 1.5,
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
              if (_hasOptions)
                AdaptiveTap(
                  onTap: _openOptions,
                  borderRadius: BorderRadius.circular(22),
                  child: Semantics(
                    button: true,
                    label: 'Review options',
                    child: SizedBox.square(
                      dimension: 44,
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: Icon(
                          PhosphorIconsFill.dotsThreeOutline,
                          size: 16,
                          color: ReviewTokens.ink,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        ReviewStars(rating: review.rating),
        if (content.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            shown,
            style: context.textTheme.bodyMedium?.copyWith(
              color: ReviewTokens.ink,
              fontSize: 14,
              height: 1.45,
            ),
          ),
        ],
        if (overflows)
          AdaptiveTap(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text(
                _expanded ? 'See less' : 'See more',
                style: context.textTheme.bodySmallMed.copyWith(
                  color: ReviewTokens.brand,
                ),
              ),
            ),
          ),
        if (photos.isNotEmpty) ...[
          const SizedBox(height: 10),
          SizedBox(
            height: 72,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: photos.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) => _photo(photos, index),
            ),
          ),
        ],
        // No gap: the 40pt target already puts ~11 above the 18pt label.
        AdaptiveTap(
          onTap: _toggleHelpful,
          borderRadius: BorderRadius.circular(8),
          child: Semantics(
            button: true,
            selected: _helpful,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 40),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _helpful ? Icons.thumb_up : Icons.thumb_up_outlined,
                    size: 14,
                    color: _helpful
                        ? ReviewTokens.brand
                        : ReviewTokens.mutedIcon,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    helpfulLabel(_helpfulCount),
                    style: context.textTheme.bodySmall?.copyWith(
                      color: _helpful ? ReviewTokens.brand : ReviewTokens.muted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );

    if (!widget.isOwn) return body;
    return Container(
      // 12 all round in Figma; the 44pt head and 40pt Helpful targets
      // already carry 4 above and 11 below.
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 1),
      decoration: BoxDecoration(
        // #EEEEEE at 60%.
        color: const Color(0x99EEEEEE),
        borderRadius: BorderRadius.circular(12),
      ),
      child: body,
    );
  }

  Widget _photo(List<String> photos, int index) {
    final tagPrefix = 'reviews-page-review-${widget.review.id}';
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => showReviewPhotoViewer(
        context,
        imageUrls: photos,
        initialIndex: index,
        heroTagPrefix: tagPrefix,
        author: (widget.review.name ?? '').trim().isEmpty
            ? 'Anonymous'
            : widget.review.name!.trim(),
        date: formatReviewDate(widget.review.createdAt),
        cafeName: widget.cafeName,
      ),
      child: Hero(
        tag: '$tagPrefix-$index',
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox.square(
            dimension: 72,
            child: CafeCardImage(
              imageUrl: photos[index],
              placeholder: const ColoredBox(color: Color(0xFFF0F0F0)),
              errorWidget: Container(
                color: const Color(0xFFF0F0F0),
                child: const Icon(
                  Icons.broken_image_outlined,
                  color: Color(0xFFBDBDBD),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
