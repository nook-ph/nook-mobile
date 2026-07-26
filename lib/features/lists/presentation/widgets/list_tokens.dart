import 'package:flutter/widgets.dart';

/// Design tokens for the redesigned Lists surfaces, from the Claude Design
/// project "Lists & Been Ranking".
///
/// Scoped to this feature rather than themed app-wide because the rest of the
/// app has not adopted the corrected palette yet — notably [muted], which
/// replaces the `#848586` these screens used to ship and which failed WCAG AA
/// at 3.5:1. See `docs/design_system.md` → Known deviations #1.
class ListsTokens {
  const ListsTokens._();

  static const brand = Color(0xFF344E41);
  static const brandHover = Color(0xFF2F4833);
  static const score = Color(0xFF3A5A40);

  /// Non-text only — fails contrast as a foreground.
  static const accent = Color(0xFF588157);
  static const ink = Color(0xFF0A0F0D);
  static const muted = Color(0xFF767574);
  static const border = Color(0xFFE0E0E0);
  static const surface = Color(0xFFFEFEFE);
  static const sage = Color(0xFFDAD7CD);

  static const gutter = 22.0;
  static const radius = 12.0;

  /// `--tracking-headline: -0.02em`, resolved for a given size.
  static double tracking(double fontSize) => fontSize * -0.02;
}
