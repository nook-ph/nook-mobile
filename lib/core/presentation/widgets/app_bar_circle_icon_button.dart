import 'package:flutter/material.dart';
import 'package:nook/core/utils/adaptive_tap.dart';

/// White circular control matching cafe details app bar back/save affordances.
class AppBarCircleIconButton extends StatelessWidget {
  const AppBarCircleIconButton({
    super.key,
    required this.icon,
    required this.iconSize,
    required this.onTap,
    this.dimension = 40,
  });

  final IconData icon;
  final double iconSize;
  final VoidCallback onTap;

  /// Diameter of the circle (app bar back/save use 40).
  final double dimension;

  @override
  Widget build(BuildContext context) {
    // Define the radius once to keep things consistent
    final borderRadius = BorderRadius.circular(dimension / 2);

    return Container(
      width: dimension,
      height: dimension,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
      ),
      // Use AdaptiveTap instead of GestureDetector for platform-aware feedback
      child: AdaptiveTap(
        onTap: onTap,
        borderRadius: borderRadius,
        child: Center(
          child: Icon(icon, color: Colors.black, size: iconSize),
        ),
      ),
    );
  }
}
