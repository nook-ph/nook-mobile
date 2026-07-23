import 'package:flutter/material.dart';
import 'package:nook/core/extensions/extensions.dart';

/// The user's personal score for a cafe, as a compact green pill ("8.5").
/// Shared by the ranked Been list rows and the cafe details actions bar.
/// Tapping re-opens the ranking flow — that is the re-rank affordance.
class CafeScoreChip extends StatelessWidget {
  const CafeScoreChip({super.key, required this.score, this.onTap});

  /// Pre-formatted one-decimal score (e.g. "8.5").
  final String score;
  final VoidCallback? onTap;

  static const _green = Color(0xFF3A5A40);

  @override
  Widget build(BuildContext context) {
    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _green.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        score,
        style: context.textTheme.bodyMediumMed.copyWith(
          color: _green,
          fontWeight: FontWeight.w600,
        ),
      ),
    );

    if (onTap == null) return chip;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: chip,
    );
  }
}
