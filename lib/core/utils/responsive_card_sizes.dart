import 'package:flutter/widgets.dart';

class ResponsiveCardSizes {
  ResponsiveCardSizes._();

  /// Photo height of the home page Featured card (Figma: 350 x 196).
  static const double featuredPhotoHeight = 196;

  /// Photo height of a compact home card (Figma: 210 x 140).
  static const double cafePhotoHeight = 140;

  /// Image-area height for the home page Featured card, in logical pixels.
  /// Fixed: the design uses one height on every phone.
  static double featuredImageHeight(BuildContext context) =>
      featuredPhotoHeight;

  /// Image-area height for the home page New / Trending / Top Rated
  /// `HomeCafeCard` rows, in logical pixels. Fixed, like the featured one.
  static double cafeImageHeight(BuildContext context) => cafePhotoHeight;

  /// Side gutter of the home feed, in logical pixels.
  static const double homeGutter = 20;

  /// Gap between neighbouring cards in a horizontal home row.
  static const double homeCardGap = 12;

  /// Width of the home page Featured card: one card per page, inset by the
  /// gutter on both sides, so it can never run off a narrow phone.
  ///
  /// Capped so a tablet does not stretch one photo across the whole screen.
  static double featuredCardWidthFor(double viewportWidth) {
    return (viewportWidth - homeGutter * 2).clamp(200.0, 520.0);
  }

  static double featuredCardWidth(BuildContext context) =>
      featuredCardWidthFor(MediaQuery.sizeOf(context).width);

  /// Width of a compact home card. Sized from the viewport so that one full
  /// card and a clear slice of the next are always visible (210 on a 390pt
  /// phone, 193 on a 360pt one).
  static double cafeCardWidthFor(double viewportWidth) {
    return ((viewportWidth - homeGutter - homeCardGap) / 1.7).clamp(
      160.0,
      260.0,
    );
  }

  static double cafeCardWidth(BuildContext context) =>
      cafeCardWidthFor(MediaQuery.sizeOf(context).width);
}
