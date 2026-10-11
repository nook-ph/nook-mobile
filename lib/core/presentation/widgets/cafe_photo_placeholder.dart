import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

/// What a cafe with no photo shows where its photo would be: a cup on a
/// tinted surface, never a stock photo standing in for the real place.
///
/// The tint is picked from the cafe's name, so a shelf of photo-less cafes
/// reads as a row of different places rather than one repeated grey block.
/// The surface keeps the size of the photo it replaces, so cards don't reflow
/// when a cafe gets its first photo.
///
/// The "No photo yet" caption only shows when the box has room for it; small
/// thumbnails (list rows, pins) show the cup alone. The card around it
/// already carries the cafe's name, so the tile doesn't repeat it.
class CafePhotoPlaceholder extends StatelessWidget {
  const CafePhotoPlaceholder({
    super.key,
    this.seed,
    this.showCaption = true,
    this.caption = 'No photo yet',
  });

  /// Picks the tint: usually the cafe's name or id. Null gives the first tint.
  final String? seed;

  /// Whether to show [caption] when the box is big enough for it.
  final bool showCaption;

  final String caption;

  /// Warm, low-contrast surfaces from the app's sage / latte palette. Each
  /// keeps the cup above 3:1 against it.
  static const tints = <PlaceholderTint>[
    PlaceholderTint(Color(0xFFEDF0E8), Color(0xFF5B7360)), // sage
    PlaceholderTint(Color(0xFFF3ECE3), Color(0xFF7A5E46)), // latte
    PlaceholderTint(Color(0xFFEFEEEA), Color(0xFF66655F)), // stone
    PlaceholderTint(Color(0xFFE8EEEC), Color(0xFF4F6D66)), // eucalyptus
    PlaceholderTint(Color(0xFFF4EEE6), Color(0xFF85633F)), // crema
  ];

  /// The tint for [seed]. Stable across runs (not `String.hashCode`, which
  /// may change between Dart versions).
  static PlaceholderTint tintFor(String? seed) {
    if (seed == null || seed.isEmpty) return tints.first;
    var hash = 0;
    for (final unit in seed.codeUnits) {
      hash = (hash * 31 + unit) & 0x7fffffff;
    }
    return tints[hash % tints.length];
  }

  @override
  Widget build(BuildContext context) {
    final tint = tintFor(seed);
    return Semantics(
      label: caption,
      image: true,
      child: ColoredBox(
        color: tint.surface,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final shortest = constraints.biggest.shortestSide;
            final finite = shortest.isFinite;
            final iconSize = finite
                ? (shortest * 0.32).clamp(14.0, 34.0)
                : 28.0;
            final roomForCaption =
                showCaption &&
                (!finite ||
                    (constraints.maxHeight >= 84 &&
                        constraints.maxWidth >= 96));
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  PhosphorIcon(
                    PhosphorIcons.coffee(PhosphorIconsStyle.duotone),
                    size: iconSize,
                    color: tint.ink,
                    duotoneSecondaryOpacity: 0.18,
                  ),
                  if (roomForCaption) ...[
                    const SizedBox(height: 6),
                    Text(
                      caption,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: tint.ink,
                        height: 1.2,
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// A placeholder surface and the colour of the cup and caption on it.
@immutable
class PlaceholderTint {
  const PlaceholderTint(this.surface, this.ink);

  final Color surface;
  final Color ink;
}
