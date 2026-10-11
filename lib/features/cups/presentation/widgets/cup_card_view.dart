import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:nook/core/extensions/extensions.dart';
import 'package:nook/core/utils/adaptive_tap.dart';
import 'package:nook/features/cafe_details/presentation/widgets/review_sheet_shell.dart';
import 'package:nook/features/cups/domain/entities/cup.dart';
import 'package:nook/features/gallery/presentation/widgets/gallery_image.dart';
import 'package:nook/features/profile/presentation/widgets/profile_ui.dart';
import 'package:nook/features/public_profile/presentation/widgets/review_author_link.dart';

/// One cup on a cafe's page and its Cups list (docs/references/cups):
/// Klarna's card (who and when on the left, stars on the right, a footer
/// with the Helpful pill and "…" at opposite ends), Google Maps' photos
/// under the words with a "+N" tile for the rest.
///
/// Every part is optional but the header: a photo-only cup has no stars
/// and no note, a text-only one no photos.
class CupCardView extends StatelessWidget {
  const CupCardView({
    super.key,
    required this.card,
    this.onOpenPhoto,
    this.onHelpful,
    this.onMore,
    this.noteLines = 4,
    this.showAuthor = true,
  });

  final CupCard card;

  /// False where every cup is the same person's (a profile): the header is
  /// then the visit's day.
  final bool showAuthor;

  /// Opens the card's photos full screen at the tapped one.
  final ValueChanged<int>? onOpenPhoto;

  /// Helpful on someone else's card. Null hides the pill (your own card,
  /// or a card with nothing to vote on).
  final VoidCallback? onHelpful;

  /// "…": report and block, or edit and delete on your own.
  final VoidCallback? onMore;
  final int noteLines;

  @override
  Widget build(BuildContext context) {
    final note = card.note?.trim() ?? '';
    final helpful = onHelpful;
    final more = onMore;
    final showHelpfulCount = helpful == null && card.helpfulCount > 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showAuthor) _Header(card: card) else _DayHeader(card: card),
        if (card.hasPhotos) ...[
          const SizedBox(height: 10),
          CupPhotoStrip(photos: card.photos, onOpen: onOpenPhoto),
        ],
        if (card.textItems.isNotEmpty) ...[
          const SizedBox(height: 10),
          CupItemChips(items: card.textItems),
        ],
        if (note.isNotEmpty) ...[
          const SizedBox(height: 10),
          CupNoteText(text: note, maxLines: noteLines),
        ],
        if (helpful != null || more != null || showHelpfulCount) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              if (helpful != null)
                Flexible(
                  child: _HelpfulPill(
                    voted: card.hasVoted,
                    count: card.helpfulCount,
                    onTap: helpful,
                  ),
                )
              else if (showHelpfulCount)
                Expanded(
                  child: Text(
                    card.helpfulCount == 1
                        ? '1 person found this helpful'
                        : '${card.helpfulCount} people found this helpful',
                    style: context.textTheme.bodySmall?.copyWith(
                      color: ReviewTokens.muted,
                      fontSize: 12,
                    ),
                  ),
                ),
              const Spacer(),
              if (more != null)
                Semantics(
                  button: true,
                  label: card.isMine ? 'Your cup options' : 'Cup options',
                  excludeSemantics: true,
                  child: AdaptiveTap(
                    onTap: more,
                    borderRadius: BorderRadius.circular(22),
                    child: const SizedBox.square(
                      dimension: 44,
                      child: Icon(
                        LucideIcons.ellipsis,
                        size: 20,
                        color: ReviewTokens.muted,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ] else
          const SizedBox(height: 4),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.card});

  final CupCard card;

  @override
  Widget build(BuildContext context) {
    final rating = card.rating;
    final name = card.label;
    final linked = !card.isMine && card.userId.isNotEmpty;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: ReviewAuthorLink(
            userId: card.userId,
            name: name,
            isOwn: card.isMine,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 44),
              child: Row(
                children: [
                  ProfileAvatar(
                    name: card.username.isEmpty
                        ? (card.fullName ?? '')
                        : card.username,
                    size: 36,
                    imageUrl: card.avatarUrl,
                    initialSize: 14,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ReviewAuthorName(
                          name: card.isMine ? 'Your cup' : name,
                          linked: linked,
                          style: context.textTheme.bodyMediumMed.copyWith(
                            color: card.isMine
                                ? ReviewTokens.brand
                                : ReviewTokens.ink,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          [
                            cupDateLabel(card.visitedAt, DateTime.now()),
                            if (card.visitsByAuthor > 1)
                              '${card.visitsByAuthor} visits here',
                          ].join(' · '),
                          style: context.textTheme.bodySmall?.copyWith(
                            color: ReviewTokens.muted,
                            fontSize: 12,
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
        if (rating != null) ...[
          const SizedBox(width: 8),
          CupStars(rating: rating),
        ],
      ],
    );
  }
}

class _DayHeader extends StatelessWidget {
  const _DayHeader({required this.card});

  final CupCard card;

  @override
  Widget build(BuildContext context) {
    final rating = card.rating;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 32),
      child: Row(
        children: [
          Expanded(
            child: Text(
              cupDateLabel(card.visitedAt, DateTime.now()),
              style: context.textTheme.bodyMediumMed.copyWith(
                color: ReviewTokens.ink,
                fontSize: 14,
              ),
            ),
          ),
          if (rating != null) CupStars(rating: rating),
        ],
      ),
    );
  }
}

/// Five small stars, [rating] of them filled. Only drawn for a rated cup:
/// no stars is not zero stars.
class CupStars extends StatelessWidget {
  const CupStars({super.key, required this.rating, this.size = 14});

  final int rating;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$rating out of 5 stars',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 1; i <= 5; i++)
            Icon(
              i <= rating ? Icons.star_rounded : Icons.star_outline_rounded,
              size: size,
              color: i <= rating ? ReviewTokens.star : const Color(0xFFC4C4C4),
            ),
        ],
      ),
    );
  }
}

/// The card's photos: one, two or three across, the third showing "+N"
/// when there are more, each with its drink under it when it has one.
class CupPhotoStrip extends StatelessWidget {
  const CupPhotoStrip({super.key, required this.photos, this.onOpen});

  final List<CupItem> photos;
  final ValueChanged<int>? onOpen;

  static const _gap = 8.0;

  @override
  Widget build(BuildContext context) {
    final shown = math.min(photos.length, 3);
    final extra = photos.length - shown;
    final anyDrink = photos.take(shown).any((p) => p.label != null);
    return LayoutBuilder(
      builder: (context, box) {
        final width = box.maxWidth;
        final double tileWidth;
        final double aspect;
        switch (shown) {
          case 1:
            tileWidth = (width - _gap) / 2;
            aspect = 4 / 5;
          case 2:
            tileWidth = (width - _gap) / 2;
            aspect = 1;
          default:
            tileWidth = (width - _gap * 2) / 3;
            aspect = 4 / 5;
        }
        final dpr = MediaQuery.devicePixelRatioOf(context);
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < shown; i++) ...[
              if (i > 0) const SizedBox(width: _gap),
              SizedBox(
                width: tileWidth,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _PhotoTile(
                      photo: photos[i],
                      width: tileWidth,
                      height: tileWidth / aspect,
                      cacheWidth: math.max(1, (tileWidth * dpr).round()),
                      more: i == shown - 1 && extra > 0 ? extra : 0,
                      onTap: onOpen == null ? null : () => onOpen!(i),
                    ),
                    if (anyDrink)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          photos[i].label ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.textTheme.bodySmall?.copyWith(
                            color: ReviewTokens.ink,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _PhotoTile extends StatelessWidget {
  const _PhotoTile({
    required this.photo,
    required this.width,
    required this.height,
    required this.cacheWidth,
    required this.more,
    required this.onTap,
  });

  final CupItem photo;
  final double width;
  final double height;
  final int cacheWidth;

  /// Photos past this one, drawn as "+N" over it.
  final int more;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final drink = photo.label;
    final label = more > 0
        ? 'Open photos, $more more'
        : (drink == null ? 'Open photo' : 'Open photo, $drink');
    return Semantics(
      button: onTap != null,
      image: true,
      label: label,
      excludeSemantics: true,
      child: AdaptiveTap(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: SizedBox(
            width: width,
            height: height,
            child: Stack(
              fit: StackFit.expand,
              children: [
                GalleryImage(url: photo.imageUrl ?? '', cacheWidth: cacheWidth),
                if (more > 0)
                  ColoredBox(
                    color: const Color(0x8C0A0F0D),
                    child: Center(
                      child: Text(
                        '+$more',
                        style: context.textTheme.bodyLargeSemi.copyWith(
                          color: Colors.white,
                          fontSize: 20,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// What someone had, named but without a photo: one chip each, with its
/// kind's icon.
class CupItemChips extends StatelessWidget {
  const CupItemChips({super.key, required this.items});

  final List<CupItem> items;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final item in items)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: ReviewTokens.tint.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  cupKindIcon(item.kind),
                  size: 14,
                  color: ReviewTokens.brand,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    item.label ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.textTheme.bodySmall?.copyWith(
                      color: ReviewTokens.ink,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// The icon for an item's kind; a cup for an unknown (legacy) one.
IconData cupKindIcon(CupItemKind? kind) => switch (kind) {
  CupItemKind.drink => LucideIcons.cupSoda,
  CupItemKind.food => LucideIcons.croissant,
  CupItemKind.space => LucideIcons.armchair,
  _ => LucideIcons.coffee,
};

/// A note, [maxLines] at first with an inline "More" (Google Maps').
class CupNoteText extends StatefulWidget {
  const CupNoteText({super.key, required this.text, this.maxLines = 4});

  final String text;
  final int maxLines;

  @override
  State<CupNoteText> createState() => _CupNoteTextState();
}

class _CupNoteTextState extends State<CupNoteText> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final style = context.textTheme.bodyMedium?.copyWith(
      color: ReviewTokens.ink,
      fontSize: 14,
      height: 1.5,
    );
    return LayoutBuilder(
      builder: (context, box) {
        final painter = TextPainter(
          text: TextSpan(text: widget.text, style: style),
          maxLines: widget.maxLines,
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
        )..layout(maxWidth: box.maxWidth);
        final clipped = painter.didExceedMaxLines;
        painter.dispose();
        final text = Text(
          widget.text,
          maxLines: _open ? null : widget.maxLines,
          overflow: _open ? null : TextOverflow.ellipsis,
          style: style,
        );
        if (!clipped) return text;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            text,
            Semantics(
              button: true,
              child: AdaptiveTap(
                onTap: () => setState(() => _open = !_open),
                borderRadius: BorderRadius.circular(8),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    minHeight: 44,
                    minWidth: 44,
                  ),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    widthFactor: 1,
                    child: Text(
                      _open ? 'Less' : 'More',
                      style: context.textTheme.bodyMediumMed.copyWith(
                        color: ReviewTokens.brand,
                        fontSize: 14,
                        decoration: TextDecoration.underline,
                        decorationColor: ReviewTokens.brand,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Klarna's count pill: a thumb and the count, filled once you voted.
class _HelpfulPill extends StatelessWidget {
  const _HelpfulPill({
    required this.voted,
    required this.count,
    required this.onTap,
  });

  final bool voted;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = voted ? ReviewTokens.brand : ReviewTokens.muted;
    return Semantics(
      button: true,
      selected: voted,
      label: count == 0 ? 'Helpful' : 'Helpful, $count',
      excludeSemantics: true,
      child: AdaptiveTap(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Container(
            constraints: const BoxConstraints(minHeight: 32),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: voted ? ReviewTokens.brand.withValues(alpha: 0.08) : null,
              border: Border.all(
                color: voted ? ReviewTokens.brand : ReviewTokens.border,
              ),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  voted ? Icons.thumb_up : Icons.thumb_up_outlined,
                  size: 15,
                  color: color,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    count == 0 ? 'Helpful' : 'Helpful · $count',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.textTheme.bodySmall?.copyWith(
                      color: color,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// "Today", "Yesterday", "3 days ago", "2 weeks ago", then "Mar 4" this
/// year or "Mar 4, 2025" before.
String cupDateLabel(DateTime date, DateTime now) {
  final days = DateTime(
    now.year,
    now.month,
    now.day,
  ).difference(DateTime(date.year, date.month, date.day)).inDays;
  if (days <= 0) return 'Today';
  if (days == 1) return 'Yesterday';
  if (days < 7) return '$days days ago';
  if (days < 28) {
    final weeks = days ~/ 7;
    return weeks == 1 ? '1 week ago' : '$weeks weeks ago';
  }
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  final day = '${months[date.month - 1]} ${date.day}';
  return date.year == now.year ? day : '$day, ${date.year}';
}
