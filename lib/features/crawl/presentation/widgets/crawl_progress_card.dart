import 'package:flutter/material.dart';
import 'package:nook/utils/theme/custom_themes/color_scheme.dart';
import 'package:nook/utils/theme/custom_themes/text_theme.dart';

class CrawlProgressCard extends StatelessWidget {
  final int claimedStops;
  final int totalStops;
  final String currentTierName;

  const CrawlProgressCard({
    super.key,
    required this.claimedStops,
    required this.totalStops,
    required this.currentTierName,
  });

  /// Returns a safe progress factor clamped between 0.0 and 1.0
  double get _progressFactor {
    if (totalStops <= 0) return 0.0;
    return (claimedStops / totalStops).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final displayPercentage = (_progressFactor * 100).round();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.offWhite,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Your progress',
                style: textTheme.bodyLargeMed.copyWith(color: colors.black),
              ),
              // Fix: Only render the pill if there is an actual tier name string
              if (currentTierName.trim().isNotEmpty)
                _TierPill(tierName: currentTierName),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '$claimedStops of $totalStops stops claimed • $displayPercentage%',
            style: textTheme.bodySmall?.copyWith(color: colors.gray),
          ),
          const SizedBox(height: 12),
          // Fix: Passing factor instead of raw percentage to the optimized progress bar
          _ProgressBar(progress: _progressFactor),
        ],
      ),
    );
  }
}

class _TierPill extends StatelessWidget {
  final String tierName;

  const _TierPill({required this.tierName});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: colors.primary100,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        tierName,
        style: textTheme.bodySmall?.copyWith(
          color: colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  final double progress; // Expects a value from 0.0 to 1.0

  const _ProgressBar({required this.progress});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    // Fix: Replaced layout-breaking FractionallySizedBox with a robust native indicator
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: LinearProgressIndicator(
        value: progress,
        minHeight: 8,
        backgroundColor: colors.border,
        valueColor: AlwaysStoppedAnimation<Color>(colors.success),
      ),
    );
  }
}
