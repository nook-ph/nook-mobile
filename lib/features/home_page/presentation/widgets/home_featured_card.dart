import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:nook/core/cafe/domain/entities/cafe_summary.dart';
import 'package:nook/core/extensions/extensions.dart';
import 'package:nook/core/presentation/widgets/cafe_card_image.dart';
import 'package:nook/core/presentation/widgets/cafe_status_badge.dart';
import 'package:nook/core/utils/adaptive_tap.dart';
import 'package:nook/core/utils/responsive_card_sizes.dart';
import 'package:nook/features/home_page/presentation/widgets/home_meta_line.dart';
import 'package:nook/features/home_page/presentation/widgets/home_tag_chip.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:skeletonizer/skeletonizer.dart';

const _fallbackImage =
    'https://images.unsplash.com/photo-1497935586351-b67a49e012bf';

/// A featured cafe: one full-width photo, name and rating on the first line,
/// area and distance on the second, then its tags.
class FeaturedCard extends StatelessWidget {
  final CafeSummary cafe;
  final bool isSkeleton;
  final double width;
  final double height;

  const FeaturedCard({
    super.key,
    required this.width,
    required this.height,
    required this.cafe,
    this.isSkeleton = false,
  });

  @override
  Widget build(BuildContext context) {
    final String imageUrl = cafe.coverImage?.trim().isNotEmpty == true
        ? cafe.coverImage!.trim()
        : _fallbackImage;

    return AdaptiveTap(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        if (isSkeleton) return;
        if (cafe.id.isNotEmpty) context.push('/cafe/${cafe.id}');
      },
      child: SizedBox(
        width: width,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                Skeleton.replace(
                  replace: isSkeleton,
                  replacement: Container(
                    height: height,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: context.colorScheme.offWhite,
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: CafeCardImage(
                      imageUrl: imageUrl,
                      height: height,
                      width: double.infinity,
                    ),
                  ),
                ),
                if (!isSkeleton)
                  Positioned(
                    top: 10,
                    left: 10,
                    child: CafeStatusBadge(cafeId: cafe.id),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text(
                    cafe.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.textTheme.bodyLargeSemi.copyWith(
                      color: context.colorScheme.black,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      height: 1.5,
                    ),
                  ),
                ),
                // Nothing to average yet: "0.0 (0)" reads as a verdict
                // rather than an absence.
                if (cafe.reviewCount > 0) ...[
                  const SizedBox(width: 8),
                  Icon(
                    PhosphorIconsFill.star,
                    color: context.colorScheme.primary60,
                    size: 13,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    cafe.rating.toStringAsFixed(1),
                    style: context.textTheme.bodyLargeMed.copyWith(
                      color: context.colorScheme.black,
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '(${cafe.reviewCount})',
                    style: context.textTheme.bodyMedium?.copyWith(
                      color: context.colorScheme.gray,
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 2),
            HomeMetaLine(
              area: cafe.locationLabel,
              lat: cafe.lat,
              lng: cafe.lng,
            ),
            if (cafe.tags.isNotEmpty) ...[
              // Figma: 2 between the lines plus the tag row's own 6 on top.
              const SizedBox(height: 8),
              HomeTagChips(tags: cafe.tags, isSkeleton: isSkeleton),
            ],
          ],
        ),
      ),
    );
  }
}

/// Featured cafes one per page, with the next card's edge showing and a row
/// of page dots underneath.
class FeaturedCarousel extends StatefulWidget {
  const FeaturedCarousel({
    super.key,
    required this.cafes,
    this.isSkeleton = false,
  });

  final List<CafeSummary> cafes;
  final bool isSkeleton;

  @override
  State<FeaturedCarousel> createState() => _FeaturedCarouselState();
}

class _FeaturedCarouselState extends State<FeaturedCarousel> {
  static const _prototypeCafe = CafeSummary(
    id: '',
    name: 'Prototype Cafe Name',
    address: 'Prototype Address',
    rating: 4.9,
    reviewCount: 1,
    tags: ['Specialty'],
  );

  PageController? _controller;
  double _fraction = 0;
  int _page = 0;

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  /// One page is a card plus the gap to the next, measured against the
  /// viewport left of the gutter, so the following card peeks at the edge.
  PageController _controllerFor(double cardWidth, double viewportWidth) {
    final fraction =
        ((cardWidth + ResponsiveCardSizes.homeCardGap) / viewportWidth).clamp(
          0.1,
          1.0,
        );
    final current = _controller;
    if (current != null && (fraction - _fraction).abs() < 0.0001) {
      return current;
    }
    current?.dispose();
    _fraction = fraction;
    return _controller = PageController(
      viewportFraction: fraction,
      initialPage: _page,
    );
  }

  @override
  Widget build(BuildContext context) {
    final cafes = widget.cafes;
    final cardWidth = ResponsiveCardSizes.featuredCardWidth(context);
    final imageHeight = ResponsiveCardSizes.featuredImageHeight(context);
    final viewportWidth =
        MediaQuery.sizeOf(context).width - ResponsiveCardSizes.homeGutter;
    final controller = _controllerFor(cardWidth, viewportWidth);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: ResponsiveCardSizes.homeGutter),
          // The invisible prototype gives the pager its height at any text
          // scale, so nothing is hard-coded.
          child: Stack(
            // The pager draws the neighbouring cards outside its own box.
            clipBehavior: Clip.none,
            children: [
              // Stretches the stack, and so the pager, to the full width.
              const SizedBox(width: double.infinity),
              IgnorePointer(
                child: Opacity(
                  opacity: 0,
                  child: FeaturedCard(
                    width: cardWidth,
                    height: imageHeight,
                    cafe: _prototypeCafe,
                    isSkeleton: true,
                  ),
                ),
              ),
              Positioned.fill(
                child: PageView.builder(
                  controller: controller,
                  padEnds: false,
                  clipBehavior: Clip.none,
                  itemCount: cafes.length,
                  onPageChanged: (page) => setState(() => _page = page),
                  itemBuilder: (_, i) => Align(
                    alignment: Alignment.topLeft,
                    child: FeaturedCard(
                      width: cardWidth,
                      height: imageHeight,
                      cafe: cafes[i],
                      isSkeleton: widget.isSkeleton,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (cafes.length > 1 && !widget.isSkeleton) ...[
          // Figma: dots sit 12 below the card.
          const SizedBox(height: 12),
          _PageDots(count: cafes.length, current: _page),
        ],
      ],
    );
  }
}

class _PageDots extends StatelessWidget {
  const _PageDots({required this.count, required this.current});

  final int count;
  final int current;

  /// A long feed would turn the dots into a ruler.
  static const _max = 8;

  @override
  Widget build(BuildContext context) {
    final shown = count > _max ? _max : count;
    final active = current >= shown ? shown - 1 : current;
    return Semantics(
      label: 'Featured cafe ${current + 1} of $count',
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < shown; i++)
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              // Figma: 5 between dots.
              margin: const EdgeInsets.symmetric(horizontal: 2.5),
              width: i == active ? 16 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: i == active
                    ? context.colorScheme.primary100
                    : context.colorScheme.border,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
        ],
      ),
    );
  }
}
