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

  double get _percentage =>
      totalStops > 0 ? (claimedStops / totalStops) * 100 : 0;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

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
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                'Your progress',
                style: textTheme.bodyLargeMed.copyWith(color: colors.black),
              ),
              _TierPill(tierName: currentTierName),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '$claimedStops of $totalStops stops claimed \u00B7 ${_percentage.round()}%',
            style: textTheme.bodySmall?.copyWith(color: colors.gray),
          ),
          const SizedBox(height: 12),
          _ProgressBar(percentage: _percentage),
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

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: colors.primary100,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        tierName,
        style: TextStyle(
          color: colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  final double percentage;

  const _ProgressBar({required this.percentage});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: Container(
        height: 8,
        color: colors.border,
        child: FractionallySizedBox(
          alignment: Alignment.centerLeft,
          widthFactor: percentage / 100,
          child: Container(color: colors.success),
        ),
      ),
    );
  }
}
