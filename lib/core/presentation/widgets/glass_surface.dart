import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

/// Frosted glass for controls that float over moving content (the map, a
/// scrolling page): whatever is behind shows through, blurred, under a
/// milky tint with a bright hairline rim, like the tab bar.
///
/// A plain backdrop blur, not the tab bar's refraction: the refraction
/// shader cannot see the map (a platform view), and each refracting shape
/// costs memory.
class GlassSurface extends StatelessWidget {
  const GlassSurface({
    super.key,
    required this.child,
    this.shape = const StadiumBorder(),
    this.tint = defaultTint,
    this.blur = 14,
    this.shadow = true,
  });

  final Widget child;
  final ShapeBorder shape;

  /// The colour laid over the blur. Pass an opaque colour (the active
  /// recenter button's green) for a solid state.
  final Color tint;
  final double blur;

  /// A soft drop shadow, for controls that float; off for bars.
  final bool shadow;

  static const defaultTint = Color(0xB8FFFFFF);
  static const rim = Color(0x80FFFFFF);

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: ShapeDecoration(
        shape: shape,
        shadows: shadow
            ? const [
                BoxShadow(
                  color: Color(0x1F000000),
                  blurRadius: 12,
                  offset: Offset(0, 3),
                ),
              ]
            : null,
      ),
      child: ClipPath(
        clipper: ShapeBorderClipper(
          shape: shape,
          textDirection: Directionality.maybeOf(context),
        ),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: DecoratedBox(
            decoration: ShapeDecoration(color: tint, shape: _withRim(shape)),
            child: child,
          ),
        ),
      ),
    );
  }

  static ShapeBorder _withRim(ShapeBorder shape) {
    const side = BorderSide(color: rim, width: 0.5);
    return switch (shape) {
      StadiumBorder() => const StadiumBorder(side: side),
      CircleBorder() => const CircleBorder(side: side),
      RoundedRectangleBorder(:final borderRadius) => RoundedRectangleBorder(
        borderRadius: borderRadius,
        side: side,
      ),
      _ => shape,
    };
  }
}
