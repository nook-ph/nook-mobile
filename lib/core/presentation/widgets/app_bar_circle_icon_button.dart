import 'package:flutter/material.dart';
import 'package:nook/core/utils/adaptive_tap.dart';

/// White circular control matching cafe details app bar back/save affordances.
///
/// The circle is [dimension] (40) but the touch area is [hitDimension] (48,
/// above the 44 floor): a tap just outside the circle still counts. Screen
/// readers get one button with [label] and a tap action.
class AppBarCircleIconButton extends StatelessWidget {
  const AppBarCircleIconButton({
    super.key,
    required this.icon,
    required this.iconSize,
    required this.onTap,
    required this.label,
    this.dimension = 40,
    this.hitDimension = 48,
    this.iconColor = Colors.black,
    this.selected,
  });

  final IconData icon;
  final double iconSize;

  /// Null: shown, but does nothing (e.g. while saving).
  final VoidCallback? onTap;

  /// What VoiceOver and TalkBack read, e.g. "Back".
  final String label;

  /// Diameter of the circle (app bar back/save use 40).
  final double dimension;

  /// The square that takes taps, centered on the circle. Never below 44.
  final double hitDimension;
  final Color iconColor;

  /// For a toggle (the save): whether it is on.
  final bool? selected;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(dimension / 2);
    final tap = onTap;
    final target = [
      hitDimension,
      dimension,
      44.0,
    ].reduce((a, b) => a > b ? a : b);

    return Semantics(
      button: true,
      enabled: tap != null,
      selected: selected,
      label: label,
      // The action has to be on this node: excluding the children drops
      // the tap handlers below with their semantics (review N1).
      onTap: tap,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: tap,
        child: SizedBox.square(
          dimension: target,
          child: Center(
            child: Container(
              width: dimension,
              height: dimension,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
              ),
              child: AdaptiveTap(
                onTap: tap,
                borderRadius: borderRadius,
                child: Center(
                  child: Icon(icon, color: iconColor, size: iconSize),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
