import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:nook/core/utils/adaptive_tap.dart';
import 'package:nook/features/map/presentation/widgets/map_search_pill.dart';
import 'package:nook/features/map/presentation/widgets/map_tokens.dart';

/// Round button beside the map's search field that switches between the map
/// and the full cafe list.
///
/// The icon shows what a tap gives: the map while the list is open, the list
/// while the sheet is away or collapsed to its chips.
class MapListToggleButton extends StatelessWidget {
  const MapListToggleButton({
    super.key,
    required this.listOpen,
    required this.onTap,
  });

  final bool listOpen;
  final VoidCallback onTap;

  /// As tall as the search field beside it.
  static const double size = MapSearchPill.height;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: listOpen ? 'Hide list' : 'Show list',
      excludeSemantics: true,
      child: AdaptiveTap(
        key: const ValueKey('map-list-toggle'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(size / 2),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: MapTokens.surface,
            shape: BoxShape.circle,
            boxShadow: MapTokens.floatShadow(blur: 10, y: 2),
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: Icon(
              listOpen ? LucideIcons.map : LucideIcons.list,
              key: ValueKey(listOpen),
              size: 20,
              color: MapTokens.ink,
            ),
          ),
        ),
      ),
    );
  }
}

/// Slides the cafe sheet down out of view as [hidden] runs from 0 to 1.
///
/// The slide covers the sheet's whole box plus room for its shadow, so the
/// sheet is gone at any extent, including one it is springing to on the way
/// back. While hidden it takes no touches and is left out of the semantics
/// tree.
class MapSheetSlide extends StatelessWidget {
  const MapSheetSlide({super.key, required this.hidden, required this.child});

  final Animation<double> hidden;
  final Widget child;

  static const double shadowRoom = 24;

  /// Where the sheet's top edge sits above the bottom while sliding: its
  /// resting [sheetTop] less how far the slide has carried it.
  static double visibleTop({
    required double sheetTop,
    required double panelHeight,
    required double hidden,
  }) {
    final top = sheetTop - hidden * (panelHeight + shadowRoom);
    return top < 0 ? 0 : top;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final travel = constraints.maxHeight + shadowRoom;
        return AnimatedBuilder(
          animation: hidden,
          child: child,
          builder: (context, child) {
            final t = hidden.value;
            final away = t > 0 && hidden.status != AnimationStatus.reverse;
            return IgnorePointer(
              ignoring: away,
              child: ExcludeSemantics(
                excluding: away,
                child: Transform.translate(
                  offset: Offset(0, t * travel),
                  child: child,
                ),
              ),
            );
          },
        );
      },
    );
  }
}
