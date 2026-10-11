import 'package:flutter/material.dart';

/// What a cafe with no photo shows where its photo would be: a generic cafe
/// photo bundled with the app, marked "Sample photo" so nobody takes it for
/// the real place.
///
/// The photo is picked from the cafe's name, so a cafe always gets the same
/// one and a shelf of photo-less cafes reads as a row of different places
/// rather than one repeated picture. It fills the box of the photo it
/// replaces, so cards don't reflow when a cafe gets its first photo.
///
/// The "Sample photo" pill only shows when the box has room for it; small
/// thumbnails (list rows, crawl stops) show the photo alone. Credits for the
/// photos: `assets/images/placeholder_cafes/CREDITS.md`.
class CafePhotoPlaceholder extends StatelessWidget {
  const CafePhotoPlaceholder({super.key, this.seed, this.showLabel = true});

  /// Picks the photo: usually the cafe's name. Null gives the first photo.
  final String? seed;

  /// Whether to show the "Sample photo" pill when the box is big enough.
  final bool showLabel;

  static const label = 'Sample photo';

  static const _dir = 'assets/images/placeholder_cafes';

  /// The bundled photos, in hash order. Same list, same order as the
  /// webapp's `PLACEHOLDER_PHOTOS`, so a cafe gets the same photo on both.
  static const photos = <String>[
    'cafe-latte',
    'cafe-espresso',
    'cafe-croissants',
    'cafe-lounge',
    'cafe-window-bar',
    'cafe-sunlit-tables',
    'cafe-pastries-window',
    'cafe-corner',
  ];

  /// Physical widths at or under this get the 480 px thumbnail.
  static const thumbMaxWidth = 480.0;

  /// The index into [photos] for [seed]. Stable across runs (not
  /// `String.hashCode`, which may change between Dart versions).
  static int indexFor(String? seed) {
    if (seed == null || seed.isEmpty) return 0;
    var hash = 0;
    for (final unit in seed.codeUnits) {
      hash = (hash * 31 + unit) & 0x7fffffff;
    }
    return hash % photos.length;
  }

  /// The asset path of [seed]'s photo, at thumbnail size when [thumb].
  static String assetFor(String? seed, {bool thumb = false}) =>
      '$_dir/${photos[indexFor(seed)]}${thumb ? '_thumb' : ''}.webp';

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return Semantics(
      label: label,
      image: true,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final finite =
              constraints.hasBoundedWidth && constraints.hasBoundedHeight;
          final thumb =
              finite &&
              constraints.maxWidth * dpr <= thumbMaxWidth &&
              constraints.maxHeight * dpr <= thumbMaxWidth * 3 / 4;
          final roomForLabel =
              showLabel &&
              (!finite ||
                  (constraints.maxHeight >= 84 && constraints.maxWidth >= 96));
          return Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(
                assetFor(seed, thumb: thumb),
                fit: BoxFit.cover,
                excludeFromSemantics: true,
                gaplessPlayback: true,
                // Never a blank hole while the asset decodes.
                frameBuilder: (_, child, frame, sync) => sync || frame != null
                    ? child
                    : const ColoredBox(color: Color(0xFFE5E7EB)),
              ),
              if (roomForLabel)
                const Positioned(left: 8, bottom: 8, child: SamplePhotoPill()),
            ],
          );
        },
      ),
    );
  }
}

/// The quiet "Sample photo" marker drawn over a placeholder photo. Same
/// translucent-dark pill as the hero's photo counter.
class SamplePhotoPill extends StatelessWidget {
  const SamplePhotoPill({super.key});

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          child: Text(
            CafePhotoPlaceholder.label,
            maxLines: 1,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.white,
              height: 1.3,
            ),
          ),
        ),
      ),
    );
  }
}
