import 'package:flutter/material.dart';
import 'package:nook/core/utils/adaptive_tap.dart';

/// Colours and type shared by the redesign's error / empty / confirm states
/// (Figma "Remaining states & system", section 1605:53649).
abstract final class StateStyles {
  static const ink = Color(0xFF0A0F0D);
  static const muted = Color(0xFF868584);
  static const brand = Color(0xFF344E41);
  static const surface = Color(0xFFFEFEFE);
  static const tint = Color(0xFFEEEEEE);
  static const border = Color(0xFFE0E0E0);
  static const danger = Color(0xFFB3261E);

  /// Poppins at the design's auto line height (1.5).
  static TextStyle text(double size, FontWeight weight, Color color) {
    return TextStyle(
      fontFamily: 'Poppins',
      height: 1.5,
      fontSize: size,
      fontWeight: weight,
      color: color,
    );
  }
}

/// The full-page states' action: a 44 high pill that hugs its Medium 14
/// label with 28 side padding. Brand fill with a white label, or white with
/// a 1px border and an ink label.
class StatePillButton extends StatelessWidget {
  const StatePillButton({
    super.key,
    required this.label,
    required this.filled,
    required this.onTap,
  });

  final String label;
  final bool filled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: AdaptiveTap(
        onTap: onTap,
        borderRadius: BorderRadius.circular(100),
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 28),
          decoration: BoxDecoration(
            color: filled ? StateStyles.brand : StateStyles.surface,
            borderRadius: BorderRadius.circular(100),
            border: filled ? null : Border.all(color: StateStyles.border),
          ),
          child: Center(
            widthFactor: 1,
            child: Text(
              label,
              maxLines: 1,
              style: StateStyles.text(
                14,
                FontWeight.w500,
                filled ? StateStyles.surface : StateStyles.ink,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
