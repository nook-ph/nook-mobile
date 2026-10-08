import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:nook/core/extensions/extensions.dart';
import 'package:nook/core/utils/adaptive_tap.dart';

class SearchEntryButton extends StatelessWidget {
  const SearchEntryButton({
    super.key,
    this.filled = false,
    this.hint = 'Search...',
  });

  /// Grey filled pill without a border, as on the home top bar. The default
  /// outlined style is what floats over the map.
  final bool filled;
  final String hint;

  static const double height = 52;

  /// Height of the [filled] variant.
  static const double filledHeight = 44;

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
        height: filled ? filledHeight : height,
        decoration: BoxDecoration(
          color: filled ? Theme.of(context).colorScheme.offWhite : Colors.white,
          borderRadius: BorderRadius.circular(100),
          border: filled ? null : Border.all(color: borderColor),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        alignment: Alignment.centerLeft,
        child: Row(
          children: [
            Icon(
              LucideIcons.search,
              size: filled ? 20 : null,
              color: filled ? Theme.of(context).colorScheme.gray : Colors.grey,
            ),
            const SizedBox(width: 8),
            Text(
              hint,
              style: context.textTheme.bodyMedium?.copyWith(
                color: filled
                    ? Theme.of(context).colorScheme.gray
                    : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
