import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:nook/core/extensions/extensions.dart';
import 'package:nook/core/presentation/widgets/adaptive_buttons.dart';
import 'package:nook/core/presentation/widgets/review_photo_viewer.dart';
import 'package:nook/core/utils/adaptive_tap.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';

class ReviewCard extends StatelessWidget {
  const ReviewCard({
    super.key,
    required this.username,
    required this.cafeReviewed,
    required this.date,
    required this.rating,
    required this.reviewText,
    this.avatarUrl,
    this.photos = const [],
    this.isOwner = false,
    this.helpfulCount = 0,
    this.onHelpfulTap,
    this.onMoreTap,
    this.onDelete,
  });

  final String username;
  final String cafeReviewed;
  final String date;
  final double rating;
  final String reviewText;
  final String? avatarUrl;
  final List<String> photos;
  final bool isOwner;
  final int helpfulCount;
  final VoidCallback? onHelpfulTap;
  final VoidCallback? onMoreTap;
  final Future<void> Function()? onDelete;

  @override
  Widget build(BuildContext context) {
    const int maxVisiblePhotos = 3;
    const double photoSize = 100;
    const double photoSpacing = 8;

    final int extraCount = photos.length > maxVisiblePhotos
        ? photos.length - maxVisiblePhotos + 1
        : 0;
    final List<String> visiblePhotos = photos.length > maxVisiblePhotos
        ? photos.sublist(0, maxVisiblePhotos - 1)
        : photos;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE0E0E0), width: 1.0),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header: avatar + name/cafe + stars
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: const Color(0xFFE0E0E0),
                  backgroundImage: avatarUrl != null
                      ? NetworkImage(avatarUrl!)
                      : null,
                  child: avatarUrl == null
                      ? const Icon(Icons.person, color: Colors.white54)
                      : null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      RichText(
                        text: TextSpan(
                          style: context.textTheme.bodyMedium,
                          children: [
                            TextSpan(
                              text: username,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const TextSpan(
                              text: ' reviewed ',
                              style: TextStyle(
                                color: Colors.black54,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                            TextSpan(
                              text: cafeReviewed,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 3),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _StarRow(rating: rating),
              ],
            ),
            const SizedBox(height: 14),
            // Review text
            Text(
              reviewText,
              style: context.textTheme.bodyMedium?.copyWith(
                color: Colors.black87,
                height: 1.45,
              ),
            ),
            // Photos section
            if (photos.isNotEmpty) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  ...visiblePhotos.asMap().entries.map((entry) {
                    final index = entry.key;
                    final url = entry.value;
                    return Padding(
                      padding: EdgeInsets.only(
                        right:
                            index < visiblePhotos.length - 1 ||
                                extraCount > 0
                            ? photoSpacing
                            : 0,
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => showReviewPhotoViewer(
                            context,
                            imageUrls: photos,
                            initialIndex: index,
                          ),
                          child: Hero(
                            tag: 'photo-${url.hashCode}',
                            child: Image.network(
                              url,
                              width: photoSize,
                              height: photoSize,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  _PhotoPlaceholder(size: photoSize),
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                  if (extraCount > 0)
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => showReviewPhotoViewer(
                        context,
                        imageUrls: photos,
                        initialIndex: maxVisiblePhotos - 1,
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Hero(
                          tag:
                              'photo-${photos[maxVisiblePhotos - 1].hashCode}',
                          child: Stack(
                            children: [
                              Image.network(
                                photos[maxVisiblePhotos - 1],
                                width: photoSize,
                                height: photoSize,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    _PhotoPlaceholder(size: photoSize),
                              ),
                              Container(
                                width: photoSize,
                                height: photoSize,
                                color: Colors.black.withOpacity(0.45),
                                alignment: Alignment.center,
                                child: Text(
                                  '+$extraCount',
                                  style: context.textTheme.titleMediumSemi.copyWith(
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
            // Footer: hidden for owner, shown for public
            if (!isOwner) ...[
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: onHelpfulTap,
                    child: Row(
                      children: [
                        const Icon(
                          Icons.thumb_up_outlined,
                          size: 18,
                          color: Color(0xFF588157),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          helpfulCount > 0
                              ? 'helpful ($helpfulCount)'
                              : 'helpful',
                          style: context.textTheme.bodySmallMed.copyWith(
                            color: const Color(0xFF588157),
                          ),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: onMoreTap,
                    child: const Icon(
                      Icons.more_horiz,
                      color: Colors.black54,
                      size: 22,
                    ),
                  ),
                ],
              ),
            ] else if (onDelete != null) ...[
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  AdaptiveTap(
                    onTap: () => _openOptionsSheet(context),
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(
                        Icons.more_horiz,
                        color: Colors.black54,
                        size: 22,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _openOptionsSheet(BuildContext context) async {
    final deleteAction = onDelete;
    if (deleteAction == null) return;

    final shouldDelete = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0E0E0),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                AdaptiveTap(
                  onTap: () => Navigator.of(sheetContext).pop(true),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 22,
                      vertical: 16,
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.delete_outline,
                          color: Colors.red,
                          size: 22,
                        ),
                        const SizedBox(width: 14),
                        Text(
                          'Delete review',
                          style: context.textTheme.bodyMedium?.copyWith(
                            color: Colors.red,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (shouldDelete != true) return;
    if (!context.mounted) return;

    final confirmed = await _showDeleteConfirmDialog(context);
    if (confirmed != true) return;
    if (!context.mounted) return;

    await deleteAction();
  }
}

Future<bool?> _showDeleteConfirmDialog(BuildContext context) {
  return showDialog<bool>(
    context: context,
    builder: (dialogContext) => Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Delete this review?',
              style: dialogContext.textTheme.titleMediumSemi,
            ),
            const SizedBox(height: 16),
            Text(
              'This cannot be undone.',
              style: dialogContext.textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                AdaptiveTextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  child: Text(
                    'Cancel',
                    style: dialogContext.textTheme.bodyMedium?.copyWith(
                      color: Colors.grey,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                AdaptiveTextButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: Text(
                    'Delete',
                    style: dialogContext.textTheme.bodyMedium?.copyWith(
                      color: Colors.red,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

class _StarRow extends StatelessWidget {
  const _StarRow({required this.rating});

  final double rating;

  @override
  Widget build(BuildContext context) {
    return RatingBarIndicator(
      rating: rating,
      itemBuilder: (context, index) => Icon(
        PhosphorIconsFill.star,
        color: Theme.of(context).colorScheme.primary60,
      ),
      itemCount: 5,
      itemSize: 14,
    );
  }
}

class _PhotoPlaceholder extends StatelessWidget {
  const _PhotoPlaceholder({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFFD0D0D0),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(Icons.image, color: Colors.white54),
    );
  }
}
