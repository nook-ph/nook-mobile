import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:nook/core/utils/adaptive_tap.dart';
import 'package:nook/features/map/presentation/widgets/map_tokens.dart';

/// The search field floating over the map: "Search cafes" with the place
/// results are measured from underneath. The field opens search; the "Near …"
/// line is its own target and opens the place chooser.
class MapSearchPill extends StatelessWidget {
  const MapSearchPill({
    super.key,
    this.origin = 'Current location',
    this.onOriginTap,
  });

  /// Where distances are measured from: "Current location", or the chosen
  /// place ("IT Park, Cebu City").
  final String origin;

  /// Opens the "Search near" sheet. Null leaves the line as plain text.
  final VoidCallback? onOriginTap;

  static const double height = 52;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final near = textTheme.bodySmall?.copyWith(
      fontSize: 10,
      height: 1.5,
      color: MapTokens.muted,
    );
    final nearLine = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Near', maxLines: 1, style: near),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            origin,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: near?.copyWith(
              fontWeight: FontWeight.w500,
              color: MapTokens.ink,
            ),
          ),
        ),
      ],
    );
    final originTap = onOriginTap;

    return AdaptiveTap(
      onTap: () => context.push('/search'),
      borderRadius: BorderRadius.circular(100),
      child: Container(
        height: height,
        padding: const EdgeInsets.only(left: 16),
        decoration: BoxDecoration(
          color: MapTokens.surface,
          borderRadius: BorderRadius.circular(100),
          boxShadow: MapTokens.floatShadow(blur: 10, y: 2),
        ),
        child: Row(
          children: [
            const Icon(LucideIcons.search, size: 18, color: MapTokens.ink),
            const SizedBox(width: 10),
            Expanded(
              // 21 + 15 of text, centred in 52: 8 above and below.
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  Semantics(
                    button: true,
                    label: 'Search cafes',
                    excludeSemantics: true,
                    child: Text(
                      'Search cafes',
                      maxLines: 1,
                      style: textTheme.bodyMedium?.copyWith(
                        fontSize: 14,
                        height: 1.5,
                        color: MapTokens.muted,
                      ),
                    ),
                  ),
                  // The line takes what is left of the pill's height, so its
                  // target runs to the bottom edge and large text clips
                  // instead of overflowing.
                  Expanded(
                    child: originTap == null
                        ? Padding(
                            padding: const EdgeInsets.only(right: 16),
                            child: Align(
                              alignment: Alignment.topLeft,
                              child: nearLine,
                            ),
                          )
                        : Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Flexible(
                                child: _originTarget(originTap, nearLine),
                              ),
                            ],
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The "Near …" line as a button: as wide as its text (plus 16), as tall
  /// as the space under "Search cafes".
  Widget _originTarget(VoidCallback onTap, Widget nearLine) {
    return Semantics(
      button: true,
      label: 'Searching near $origin. Change place',
      excludeSemantics: true,
      child: GestureDetector(
        key: const ValueKey('map-search-origin'),
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.only(right: 16),
          child: Align(
            alignment: Alignment.topLeft,
            widthFactor: 1,
            child: nearLine,
          ),
        ),
      ),
    );
  }
}

/// Round button that recentres the map on the user.
class MapRecenterButton extends StatelessWidget {
  const MapRecenterButton({
    super.key,
    required this.onTap,
    this.active = false,
  });

  final VoidCallback onTap;

  /// The map is following the user: green with a white icon.
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: active ? 'Following my location' : 'Show my location',
      excludeSemantics: true,
      child: AdaptiveTap(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: active ? MapTokens.brand : MapTokens.surface,
            shape: BoxShape.circle,
            boxShadow: MapTokens.floatShadow(),
          ),
          child: Icon(
            LucideIcons.locate,
            size: 20,
            color: active ? MapTokens.surface : MapTokens.ink,
          ),
        ),
      ),
    );
  }
}
