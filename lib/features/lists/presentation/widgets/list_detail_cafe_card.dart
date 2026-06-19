import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:nook/core/cafe/domain/entities/cafe_summary.dart';
import 'package:nook/core/extensions/extensions.dart';
import 'package:nook/core/presentation/widgets/cafe_card_image.dart';
import 'package:nook/core/utils/adaptive_tap.dart';
import 'package:nook/features/cafe_details/presentation/pages/cafe_details_page.dart';
import 'package:nook/features/lists/presentation/widgets/cafe_actions_bottom_sheet.dart';

class ListDetailCafeCard extends StatelessWidget {
  const ListDetailCafeCard({
    super.key,
    required this.cafe,
    required this.onRemove,
  });

  final CafeSummary cafe;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final imageUrl = (cafe.coverImage?.trim().isNotEmpty ?? false)
        ? cafe.coverImage!.trim()
        : 'https://images.unsplash.com/photo-1497935586351-b67a49e012bf';

    final ratingText = cafe.rating.toStringAsFixed(1);

    return AdaptiveTap(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CafeDetailsPage(cafeId: cafe.id),
          ),
        );
      },
      child: Container(
        clipBehavior: Clip.hardEdge,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE0E0E0), width: 1.0),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min, // <-- Forces the card to hug its children
          children: [
            Stack(
              children: [
                CafeCardImage(
                  imageUrl: imageUrl,
                  height: 110, // <-- Kept exactly the same
                  width: double.infinity,
                ),
                Positioned(
                  top: 6,
                  right: 6,
                  child: AdaptiveTap(
                    onTap: () => _openActionsSheet(context),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.45),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.more_vert,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            // REMOVED the Expanded widget from here
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min, // <-- Forces text column to hug text
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Text(
                          cafe.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Row(
                        children: [
                          Text(
                            ratingText,
                            style: context.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(width: 2),
                          const Icon(
                            Icons.star,
                            color: Color(0xFF588157),
                            size: 12,
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 6), // Tight gap between title and address
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 2.0),
                        child: Icon(
                          LucideIcons.mapPin,
                          size: 10,
                          color: Color(0xFF848586),
                        ),
                      ),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          cafe.address,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.textTheme.bodySmall?.copyWith(
                            color: const Color(0xFF848586),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openActionsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: false,
      builder: (_) => CafeActionsBottomSheet(
        cafeName: cafe.name,
        onViewDetails: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CafeDetailsPage(cafeId: cafe.id),
            ),
          );
        },
        onRemove: onRemove,
      ),
    );
  }
}