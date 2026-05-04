import 'package:flutter/material.dart';

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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: dimension,
        height: dimension,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
        ),
        child: Center(
          child: Icon(icon, color: Colors.black, size: iconSize),
        ),
      ),
    );
  }
}
