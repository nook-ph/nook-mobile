import 'package:flutter/widgets.dart';

class ResponsiveCardSizes {
  ResponsiveCardSizes._();

  /// Image-area height for the home page Featured card, in logical pixels.
  ///
  /// Scales with the device's available viewport height:
  ///   < 640  -> 200  (compact phones, e.g. iPhone SE)
  ///   640-779 -> 230 (standard phones)
  ///   780-899 -> 270 (large phones / phablets)
  ///   >= 900  -> 320 (tablets, foldables, desktop) — capped
  static double featuredImageHeight(BuildContext context) {
    final h = MediaQuery.sizeOf(context).height;
    if (h < 640) return 200;
    if (h < 780) return 230;
    if (h < 900) return 270;
    return 320;
  }

  /// Image-area height for the home page New / Trending / Top Rated
  /// `HomeCafeCard` rows, in logical pixels.
  ///
  /// Mirrors [featuredImageHeight] breakpoints at a smaller scale so that
  /// the secondary sections feel visually proportional to the featured one.
  ///   < 640  -> 130
  ///   640-779 -> 150
  ///   780-899 -> 175
  ///   >= 900  -> 200 — capped
  static double cafeImageHeight(BuildContext context) {
    final h = MediaQuery.sizeOf(context).height;
    if (h < 640) return 130;
    if (h < 780) return 150;
    if (h < 900) return 175;
    return 200;
  }
}
