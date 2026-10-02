import 'package:flutter/material.dart';

/// Colours, shadows and sizes of the map redesign, from the Figma "Map —
/// redesign" section.
class MapTokens {
  const MapTokens._();

  static const ink = Color(0xFF0A0F0D);
  static const muted = Color(0xFF868584);
  static const brand = Color(0xFF344E41);
  static const star = Color(0xFF588157);
  static const closed = Color(0xFFB3261E);
  static const border = Color(0xFFE0E0E0);
  static const surface = Color(0xFFFEFEFE);

  static const gutter = 20.0;

  /// Search pill, recenter button and updating chip float on the map with a
  /// soft shadow instead of a border.
  static List<BoxShadow> floatShadow({double blur = 8, double y = 2}) => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.15),
      blurRadius: blur,
      offset: Offset(0, y),
    ),
  ];
}
