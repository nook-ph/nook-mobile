import 'package:flutter/widgets.dart';

/// Design tokens for the redesigned Lists surfaces (Figma "Lists, Been &
/// ranking — redesign").
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

  /// The grey fill of cards, skeleton blocks and empty thumbnails.
  static const tint = Color(0xFFEEEEEE);

  /// Destructive labels and the error stroke of a field.
  static const danger = Color(0xFFB3261E);

  /// The stroke of an unticked checkbox.
  static const checkbox = Color(0xFFC4C4C4);

  /// The Undo label on the dark toast.
  static const toastAction = Color(0xFFA3B18A);

  static const gutter = 20.0;
  static const radius = 12.0;

  /// `--tracking-headline: -0.02em`, resolved for a given size.
  static double tracking(double fontSize) => fontSize * -0.02;
}

/// A Lists text style at an exact Figma size, with the design's 1.5 line
/// height. Sizes are set here rather than through the app text theme, whose
/// body sizes differ from the redesign's.
TextStyle listsText(
  double size, {
  FontWeight weight = FontWeight.w400,
  Color color = ListsTokens.ink,
  double height = 1.5,
}) => TextStyle(
  fontFamily: 'Poppins',
  fontSize: size,
  fontWeight: weight,
  color: color,
  height: height,
);
