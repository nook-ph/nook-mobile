import 'package:flutter/material.dart';

/// Colours and type of the profile redesign (Figma "Profile & settings —
/// redesign"): profile, your reviews, edit profile, settings, blocked users.
class ProfileTokens {
  const ProfileTokens._();

  static const ink = Color(0xFF0A0F0D);
  static const muted = Color(0xFF868584);
  static const brand = Color(0xFF344E41);

  /// Non-text only: the rating star.
  static const star = Color(0xFF588157);
  static const starEmpty = Color(0xFFC4C4C4);
  static const success = Color(0xFF0F893E);
  static const danger = Color(0xFFB3261E);
  static const border = Color(0xFFE0E0E0);
  static const surface = Color(0xFFFEFEFE);
  static const tint = Color(0xFFEEEEEE);

  /// The avatar's fill behind an initial.
  static const avatar = Color(0xFFDAD7CD);

  /// The header's buttons (Edit profile, Share profile, +). A lighter step
  /// of [avatar]; the app had no grey-button fill.
  static const fill = Color(0xFFF1F0EC);

  static const gutter = 20.0;

  /// Poppins at [size] with Figma's auto line height (1.5).
  static TextStyle text(
    double size, {
    FontWeight weight = FontWeight.w400,
    Color color = ink,
  }) {
    return TextStyle(
      fontFamily: 'Poppins',
      height: 1.5,
      fontSize: size,
      fontWeight: weight,
      color: color,
    );
  }
}

/// 1pt #e0e0e0 rule.
class ProfileDivider extends StatelessWidget {
  const ProfileDivider({super.key});

  @override
  Widget build(BuildContext context) => const ColoredBox(
    color: ProfileTokens.border,
    child: SizedBox(height: 1, width: double.infinity),
  );
}
