import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:nook/core/analytics/discovery_events.dart';
import 'package:nook/core/analytics/log_app_event.dart';
import 'package:nook/core/cafe/domain/entities/cafe_summary.dart';
import 'package:nook/core/extensions/extensions.dart';
import 'package:nook/core/utils/adaptive_tap.dart';
import 'package:nook/core/utils/responsive_card_sizes.dart';
import 'package:nook/core/widgets/prototype_height.dart';
import 'package:nook/features/home_page/presentation/widgets/home_cafe_card.dart';
import 'package:nook/features/home_page/presentation/widgets/home_rail_impression.dart';

/// A titled horizontal row of compact cards. Renders nothing when it has no
/// cafes: an empty section is left out of the feed, not labelled.
class HomeCafeSection extends StatelessWidget {
  final String title;

  /// A short line under the title saying what the shelf is.
  final String? subtitle;
  final List<CafeSummary> cafes;
  final bool isSkeleton;

  /// The search sort that lists this shelf in full ("nearby", "newest",
  /// "trending", "top_rated"); the title then opens that list. Null keeps
  /// the title plain.
  final String? sort;

  /// The rail's analytics id (`home_rail_impression`,
  /// `home_rail_card_tapped`). Defaults to [sort], else the title in
  /// snake_case ("Laptop-friendly" -> `laptop_friendly`).
  final String? rail;

  const HomeCafeSection({
    super.key,
    required this.title,
    this.subtitle,
    required this.cafes,
    this.isSkeleton = false,
    this.sort,
    this.rail,
  });

  /// [rail], else [sort], else the title in snake_case.
  String get railId => rail ?? sort ?? railIdFor(title);

  /// "Specialty coffee near you" -> `specialty_coffee_near_you`.
  static String railIdFor(String title) => title
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'^_+|_+$'), '');

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
    final railId = this.railId;

    final section = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        HomeSectionTitle(
          title,
          subtitle: subtitle,
          onSeeAll: sort == null || isSkeleton
              ? null
              : () {
                  logAppEvent(
                    HomeEvents.seeAllTapped,
                    properties: {'sort': sort!},
                  );
                  context.push('/search?sort=$sort');
                },
        ),
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
              section: sort ?? title,
              position: index,
              rail: isSkeleton ? null : railId,
            ),
          ),
        ),
      ],
    );
    if (isSkeleton) return section;
    return HomeRailImpression(rail: railId, child: section);
  }
}

class HomeSectionTitle extends StatelessWidget {
  const HomeSectionTitle(
    this.text, {
    super.key,
    this.subtitle,
    this.onSeeAll,
    this.trailing,
  });

  final String text;

  /// Muted line under the title; the shelf's voice lives here, the title
  /// stays plain.
  final String? subtitle;

  /// Opens the shelf's full list. With it the whole title row is a button
  /// ending in "See all" (docs/ux/find-a-cafe.md, finding 4: shelves were a
  /// dead end after a few cards).
  final VoidCallback? onSeeAll;

  /// Read-only content at the row's end (Your places' progress pill). Not
  /// shown with [onSeeAll], which owns that end.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final heading = Text(
      text,
      style: context.textTheme.titleMediumSemi.copyWith(
        color: context.colorScheme.black,
        fontSize: 16,
        fontWeight: FontWeight.w600,
        height: 1.5,
      ),
    );
    final sub = subtitle;
    final title = sub == null
        ? heading
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              heading,
              Text(
                sub,
                style: context.textTheme.bodySmall?.copyWith(
                  fontSize: 13,
                  height: 1.35,
                  color: context.colorScheme.gray,
                ),
              ),
            ],
          );
    final seeAll = onSeeAll;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: ResponsiveCardSizes.homeGutter,
      ),
      child: seeAll == null
          ? (trailing == null
                ? title
                : Row(
                    children: [
                      Expanded(child: title),
                      const SizedBox(width: 12),
                      trailing!,
                    ],
                  ))
          : AdaptiveTap(
              onTap: seeAll,
              child: Semantics(
                button: true,
                label: sub == null ? '$text, see all' : '$text, $sub, see all',
                excludeSemantics: true,
                // 8 above and below brings the row to a 40pt tap target.
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Expanded(child: title),
                      Text(
                        'See all',
                        style: context.textTheme.bodySmall?.copyWith(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: context.colorScheme.primary,
                        ),
                      ),
                      Icon(
                        LucideIcons.chevronRight,
                        size: 16,
                        color: context.colorScheme.primary,
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}
