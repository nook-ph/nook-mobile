import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:nook/core/presentation/widgets/cafe_card_image.dart';
import 'package:nook/core/utils/adaptive_tap.dart';
import 'package:nook/features/cafe_details/domain/entities/cafe_details_entity.dart';

/// One menu item as a floating-image card: rounded photo, name and price
/// below, no border box.
///
/// Shared by the details page's "Menu Highlights" strip and the full menu
/// page, which each had their own copy. The full menu page's version boxed the
/// card and split a fixed 178px height with `Expanded(flex: 3/2)`, leaving the
/// text roughly 71px for about 73px of content — a permanent
/// "BOTTOM OVERFLOWED BY 1.6 PIXELS" on every card. Sizing to content instead
/// of dividing a fixed height is what removes it.
class MenuHighlightCard extends StatelessWidget {
  const MenuHighlightCard({
    super.key,
    required this.item,
    required this.width,
    this.onTap,
  });

  final MenuItemEntity item;
  final double width;

  /// Full menu page opens the variants sheet; the highlights strip is display
  /// only, so it passes nothing and the card stays untappable.
  final VoidCallback? onTap;

  static const double imageHeight = 106;

  /// Total height a horizontal list needs to show this card without clipping.
  static const double listHeight = 178;

  @override
  Widget build(BuildContext context) {
    final imageUrl = item.imageUrl;
    final hasImage = imageUrl != null && imageUrl.isNotEmpty;

    final card = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: hasImage
              ? CafeCardImage(
                  imageUrl: imageUrl,
                  height: imageHeight,
                  width: double.infinity,
                )
              : Container(
                  height: imageHeight,
                  color: const Color(0xFFF5F5F5),
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.image_outlined,
                    color: Color(0xFFBDBDBD),
                  ),
                ),
        ),
        const Gap(8),
        Text(
          item.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const Gap(2),
        Text(
          // displayPrice, not price: items with variants cover a range, and
          // the highlights strip used to flatten that to the base price.
          '₱${item.displayPrice}',
          style: Theme.of(
            context,
          ).textTheme.bodyLarge?.copyWith(color: const Color(0xFF767574)),
        ),
      ],
    );

    return SizedBox(
      width: width,
      child: onTap == null
          ? card
          : AdaptiveTap(
              onTap: onTap!,
              borderRadius: BorderRadius.circular(12),
              child: card,
            ),
    );
  }
}
