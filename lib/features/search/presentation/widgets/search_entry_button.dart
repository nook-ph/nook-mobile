import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:nook/core/extensions/extensions.dart';
import 'package:nook/core/utils/adaptive_tap.dart';
import 'package:nook/utils/theme/custom_themes/color_scheme.dart';

class SearchEntryButton extends StatelessWidget {
  const SearchEntryButton({super.key});

  static const double height = 52;

 
  static double mapSearchBarBottom(
    BuildContext context, {
    double topPaddingBelowSafeArea = 8,
  }) {
    return MediaQuery.paddingOf(context).top + topPaddingBelowSafeArea + height;
  }

  
  static double mapBottomSheetTop(
    BuildContext context, {
    double topPaddingBelowSafeArea = 8,
    double gapBelowSearchBar = 12,
  }) {
    return mapSearchBarBottom(
          context,
          topPaddingBelowSafeArea: topPaddingBelowSafeArea,
        ) +
        gapBelowSearchBar;
  }

  @override
  Widget build(BuildContext context) {
    final borderColor = Theme.of(context).colorScheme.border;

    return AdaptiveTap(
      onTap: () => context.push('/search'),
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(color: borderColor),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        alignment: Alignment.centerLeft,
        child: Row(
          children: [
            const Icon(LucideIcons.search, color: Colors.grey),
            const SizedBox(width: 8),
            Text(
              'Search...',
              style: context.textTheme.bodyMedium?.copyWith(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
