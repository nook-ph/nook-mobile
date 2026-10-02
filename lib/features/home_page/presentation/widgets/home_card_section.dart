import 'package:flutter/material.dart';
import 'package:nook/core/cafe/domain/entities/cafe_summary.dart';
import 'package:nook/core/extensions/extensions.dart';
import 'package:nook/core/utils/responsive_card_sizes.dart';
import 'package:nook/core/widgets/prototype_height.dart';
import 'package:nook/features/home_page/presentation/widgets/home_cafe_card.dart';

/// A titled horizontal row of compact cards. Renders nothing when it has no
/// cafes: an empty section is left out of the feed, not labelled.
class HomeCafeSection extends StatelessWidget {
  final String title;
  final List<CafeSummary> cafes;
  final bool isSkeleton;

  const HomeCafeSection({
    super.key,
    required this.title,
    required this.cafes,
    this.isSkeleton = false,
  });

  // Dummy cafe for the prototype: same shape as real data.
  static const _prototypeCafe = CafeSummary(
    id: '',
    name: 'Prototype Cafe Name',
    address: 'Prototype Address',
    rating: 4.9,
    coverImage: null,
    tags: ['Specialty'],
  );

  @override
  Widget build(BuildContext context) {
    if (cafes.isEmpty) return const SizedBox.shrink();

    final double imageHeight = ResponsiveCardSizes.cafeImageHeight(context);
    final double cardWidth = ResponsiveCardSizes.cafeCardWidth(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        HomeSectionTitle(title),
        const SizedBox(height: 12),
        PrototypeHeight(
          // Same widget as the real cards, so the row is exactly one card
          // tall at any text scale.
          prototype: HomeCafeCard(
            cafe: _prototypeCafe,
            width: cardWidth,
            height: imageHeight,
            isSkeleton: true,
          ),
          listView: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(
              horizontal: ResponsiveCardSizes.homeGutter,
            ),
            itemCount: cafes.length,
            separatorBuilder: (_, _) =>
                const SizedBox(width: ResponsiveCardSizes.homeCardGap),
            itemBuilder: (_, index) => HomeCafeCard(
              cafe: cafes[index],
              width: cardWidth,
              height: imageHeight,
              isSkeleton: isSkeleton,
            ),
          ),
        ),
      ],
    );
  }
}

class HomeSectionTitle extends StatelessWidget {
  const HomeSectionTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: ResponsiveCardSizes.homeGutter,
      ),
      child: Text(
        text,
        style: context.textTheme.titleMediumSemi.copyWith(
          color: context.colorScheme.black,
          fontSize: 16,
          fontWeight: FontWeight.w600,
          height: 1.5,
        ),
      ),
    );
  }
}
