import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:nook/core/utils/adaptive_tap.dart';
import 'package:nook/features/map/presentation/widgets/map_search_pill.dart';
import 'package:nook/features/map/presentation/widgets/map_tokens.dart';

/// Round button beside the map's search field that puts the cafe list away
/// for a map-only view and brings it back.
///
/// The icon shows what a tap gives: the map while the list is up, the list
/// while it is put away.
class MapListToggleButton extends StatelessWidget {
  const MapListToggleButton({
    super.key,
    required this.listHidden,
    required this.onTap,
  });

  final bool listHidden;
  final VoidCallback onTap;

  /// As tall as the search field beside it.
  static const double size = MapSearchPill.height;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: listHidden ? 'Show list' : 'Hide list',
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
              listHidden ? LucideIcons.list : LucideIcons.map,
              key: ValueKey(listHidden),
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
/// The sheet keeps its own extent while it is away, so it comes back at the
/// snap position it was left at. [sheetTop] is how far the sheet's top edge
/// sits above the bottom; the slide covers that plus room for its shadow, so
/// the edge and anything pinned to it move together. While hidden the sheet
/// takes no touches and is left out of the semantics tree.
class MapSheetSlide extends StatelessWidget {
  const MapSheetSlide({
    super.key,
    required this.hidden,
    required this.sheetTop,
    required this.child,
  });

  final Animation<double> hidden;

  /// Null before the sheet has been measured; the slide then covers the
  /// whole box.
  final double? sheetTop;
  final Widget child;

  static const double _shadowRoom = 24;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final travel = (sheetTop ?? constraints.maxHeight) + _shadowRoom;
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
