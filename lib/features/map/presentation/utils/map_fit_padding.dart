import 'dart:ui' show Size;

/// Edge padding for a fit-to-bounds camera, in logical pixels.
class MapFitPadding {
  const MapFitPadding({
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
  });

  final double left;
  final double top;
  final double right;
  final double bottom;

  @override
  String toString() =>
      'MapFitPadding(left: $left, top: $top, right: $right, bottom: $bottom)';
}

/// Smallest strip of map, in logical pixels, a fit must leave for the pins.
const double kMinFitViewportExtent = 80.0;

/// Shrinks fit-to-bounds padding until it fits inside [viewport].
///
/// MapLibre solves a fit by looking for the camera that puts the bounds inside
/// `viewport - padding`. Hand it padding that meets or exceeds the viewport and
/// that rectangle is zero or negative, the zoom derived from it is NaN, and the
/// native `setCamera` throws a C++ exception. Nothing on the Dart side can
/// catch that one: it unwinds past the method channel into `std::terminate`,
/// and iOS ends the process with SIGABRT — the app vanishes with no error
/// screen at all.
///
/// The caller's numbers describe intent (keep pins clear of the sheet), not a
/// promise the map is big enough to honour them. So when they do not fit, both
/// sides of the axis are scaled down together — the bottom inset stays the
/// largest one, the sheet still gets the most clearance available, and at least
/// [minimumExtent] pixels survive for the pins themselves.
///
/// A [viewport] that is empty or not yet measured yields no padding rather than
/// a guess.
MapFitPadding resolveMapFitPadding({
  required Size viewport,
  required double left,
  required double top,
  required double right,
  required double bottom,
  double minimumExtent = kMinFitViewportExtent,
}) {
  final (resolvedLeft, resolvedRight) = _shrinkToFit(
    left,
    right,
    viewport.width,
    minimumExtent,
  );
  final (resolvedTop, resolvedBottom) = _shrinkToFit(
    top,
    bottom,
    viewport.height,
    minimumExtent,
  );

  return MapFitPadding(
    left: resolvedLeft,
    top: resolvedTop,
    right: resolvedRight,
    bottom: resolvedBottom,
  );
}

/// Scales [start] and [end] together until they leave [minimum] of [extent].
(double, double) _shrinkToFit(
  double start,
  double end,
  double extent,
  double minimum,
) {
  final safeStart = _atLeastZero(start);
  final safeEnd = _atLeastZero(end);

  if (!extent.isFinite || extent <= 0) return (0, 0);

  final available = extent - _atLeastZero(minimum);
  if (available <= 0) return (0, 0);

  final total = safeStart + safeEnd;
  if (total <= available) return (safeStart, safeEnd);

  // Derive the far side by subtraction rather than scaling it too. Scaling
  // both independently can land their sum a float's width over `available`,
  // and the guarantee this function exists to make has to be exact.
  final scaledStart = safeStart * (available / total);
  return (scaledStart, available - scaledStart);
}

double _atLeastZero(double value) => value.isFinite && value > 0 ? value : 0;
