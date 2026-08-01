import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

/// Star + score + review count for a cafe card.
///
/// **Renders nothing when the cafe has no reviews.** Every card used to print
/// `cafe.rating.toStringAsFixed(1)` unconditionally, so an unreviewed cafe
/// advertised itself as "0.0 ★" — a filled star beside a zero, which reads as
/// *rated badly* rather than *not yet rated*. The details page already says
/// "No reviews yet", so the app contradicted itself, and the cafes it
/// misrepresented are the ones being courted for owner partnerships.
///
/// Hiding rather than substituting copy also gives the name back the width the
/// rating was occupying, which is where it was truncating ("Peak Coffee Ro…").
class CafeRatingLabel extends StatelessWidget {
  const CafeRatingLabel({
    super.key,
    required this.rating,
    required this.reviewCount,
    required this.starSize,
    required this.ratingStyle,
    required this.countStyle,
    this.starColor,
    this.showCount = true,
  });

  final double rating;
  final int reviewCount;
  final double starSize;
  final TextStyle? ratingStyle;
  final TextStyle? countStyle;
  final Color? starColor;

  /// Some cards show "4.8 (12)", others just "4.8 ★".
  final bool showCount;

  @override
  Widget build(BuildContext context) {
    if (reviewCount <= 0) return const SizedBox.shrink();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(PhosphorIconsFill.star, size: starSize, color: starColor),
        const SizedBox(width: 4),
        Text(rating.toStringAsFixed(1), style: ratingStyle),
        if (showCount) ...[
          const SizedBox(width: 4),
          Text('($reviewCount)', style: countStyle),
        ],
      ],
    );
  }
}
