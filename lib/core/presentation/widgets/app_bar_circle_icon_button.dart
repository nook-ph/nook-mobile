import 'package:flutter/material.dart';
import 'package:nook/core/utils/adaptive_tap.dart';

/// White circular control matching cafe details app bar back/save affordances.
/// The circle is drawn at [dimension]; the tap target is at least 44.
class AppBarCircleIconButton extends StatelessWidget {
  const AppBarCircleIconButton({
    super.key,
    required this.icon,
    required this.iconSize,
    required this.onTap,
    required this.label,
    this.dimension = 40,
  });

  final IconData icon;
  final double iconSize;
  final VoidCallback onTap;

  /// What VoiceOver and TalkBack read, e.g. "Back".
  final String label;

  /// Diameter of the circle (app bar back/save use 40).
  final double dimension;

  @override
  Widget build(BuildContext context) {
    // Define the radius once to keep things consistent
    final borderRadius = BorderRadius.circular(dimension / 2);

    final target = dimension < 44 ? 44.0 : dimension;
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      // Use AdaptiveTap instead of GestureDetector for platform-aware feedback
      child: AdaptiveTap(
        onTap: onTap,
        borderRadius: BorderRadius.circular(target / 2),
        child: SizedBox.square(
          dimension: target,
          child: Center(
            child: Container(
              width: dimension,
              height: dimension,
              decoration: BoxDecoration(
                borderRadius: borderRadius,
                color: Colors.white,
              ),
              child: Icon(icon, color: Colors.black, size: iconSize),
            ),
          ),
        ),
      ),
    );
  }
}
