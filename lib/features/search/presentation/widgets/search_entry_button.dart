import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:nook/core/bloc/features/navigation/bloc/navigation_bloc.dart';
import 'package:nook/features/search/presentation/pages/search_results_page.dart';
import 'package:nook/utils/theme/custom_themes/color_scheme.dart';

/// Tappable search pill used on home and map; opens [SearchResultsPage].
class SearchEntryButton extends StatelessWidget {
  const SearchEntryButton({super.key});

  /// Fixed height of the search pill (must match the [Container] below).
  static const double height = 52;

  /// Y-offset from the top of the screen to the bottom edge of the map search
  /// row, matching [MapPage] `SafeArea` + `Padding` above this widget.
  /// Keep [topPaddingBelowSafeArea] in sync with map page vertical padding.
  static double mapSearchBarBottom(
    BuildContext context, {
    double topPaddingBelowSafeArea = 8,
  }) {
    return MediaQuery.paddingOf(context).top + topPaddingBelowSafeArea + height;
  }

  /// Top `Positioned` inset for the map bottom sheet: below the search bar plus
  /// [gapBelowSearchBar] breathing room.
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

  NavigationBloc? _tryReadNavigationBloc(BuildContext context) {
    try {
      return BlocProvider.of<NavigationBloc>(context, listen: false);
    } catch (_) {
      return null;
    }
  }

  void _openSearch(BuildContext context) {
    final navBloc = _tryReadNavigationBloc(context);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) {
          final page = const SearchResultsPage(query: '');
          if (navBloc == null) return page;
          return BlocProvider.value(value: navBloc, child: page);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final borderColor = Theme.of(context).colorScheme.border;

    return GestureDetector(
      onTap: () => _openSearch(context),
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(color: borderColor),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        alignment: Alignment.centerLeft,
        child: const Row(
          children: [
            Icon(LucideIcons.search, color: Colors.grey),
            SizedBox(width: 8),
            Text('Search...', style: TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}
