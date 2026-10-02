import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:nook/core/extensions/extensions.dart';
import 'package:nook/core/utils/adaptive_tap.dart';
import 'package:nook/core/utils/responsive_card_sizes.dart';

/// Wordmark and the search field. Stays put in every home state, including
/// errors, so search is never taken away.
class HomeTopBar extends StatelessWidget {
  const HomeTopBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: ResponsiveCardSizes.homeGutter,
        vertical: 8,
      ),
      child: Row(
        children: [
          // Figma: the wordmark fills a 46.8 x 26 box by its width.
          SizedBox(
            width: 46.8,
            height: 26,
            // The file is 3960 px wide; decode it at the size it is drawn.
            child: Image.asset(
              'assets/logos/logoT.png',
              fit: BoxFit.contain,
              cacheWidth: (46.8 * MediaQuery.devicePixelRatioOf(context))
                  .ceil(),
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(child: HomeSearchEntry()),
        ],
      ),
    );
  }
}

/// The grey search pill of the home top bar; opens the search page.
class HomeSearchEntry extends StatelessWidget {
  const HomeSearchEntry({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    return Semantics(
      button: true,
      label: 'Search cafes',
      excludeSemantics: true,
      child: AdaptiveTap(
        onTap: () => context.push('/search'),
        borderRadius: BorderRadius.circular(100),
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: scheme.offWhite,
            borderRadius: BorderRadius.circular(100),
          ),
          child: Row(
            children: [
              Icon(LucideIcons.search, size: 18, color: scheme.gray),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  'Search cafes',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.textTheme.bodyMedium?.copyWith(
                    color: scheme.gray,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
