import 'package:flutter/material.dart';
import 'package:nook/features/crawl/domain/entities/crawl_tier.dart';
import 'package:nook/utils/theme/custom_themes/color_scheme.dart';
import 'package:nook/utils/theme/custom_themes/text_theme.dart';

class CrawlTierChip extends StatelessWidget {
  final CrawlTier tier;

  const CrawlTierChip({super.key, required this.tier});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final progress = switch (tier.state) {
      TierState.completed => 1.0,
      TierState.active when tier.totalRequired > 0 =>
        (tier.totalClaimed / tier.totalRequired).clamp(0.0, 1.0),
      _ => 0.0,
    };

    final (
      Color trackColor,
      Color fillColor,
      Color iconColor,
      IconData icon,
      String progressText,
      Color progressTextColor,
    ) = switch (tier.state) {
      TierState.completed => (
        colors.success.withValues(alpha: 0.2),
        colors.success,
        colors.success,
        Icons.check_circle,
        '${tier.totalClaimed}/${tier.totalRequired}',
        colors.success,
      ),
      TierState.active => (
        colors.primary20,
        colors.primary60,
        colors.primary100,
        Icons.location_on,
        '${tier.totalClaimed}/${tier.totalRequired}',
        colors.gray,
      ),
      TierState.locked => (
        colors.gray.withValues(alpha: 0.25),
        colors.gray.withValues(alpha: 0.25),
        colors.gray,
        Icons.lock_outline,
        '0/${tier.totalRequired}',
        colors.gray,
      ),
    };

    final Color nameColor = switch (tier.state) {
      TierState.completed || TierState.active => colors.black,
      TierState.locked => colors.gray,
    };

    return Container(
      width: 230,
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
      decoration: BoxDecoration(
        color: switch (tier.state) {
          TierState.completed => colors.success.withValues(alpha: 0.06),
          TierState.active => colors.primary20.withValues(alpha: 0.3),
          TierState.locked => colors.offWhite,
        },
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: switch (tier.state) {
            TierState.completed => colors.success.withValues(alpha: 0.3),
            TierState.active => colors.primary100.withValues(alpha: 0.15),
            TierState.locked => colors.gray.withValues(alpha: 0.15),
          },
        ),
        boxShadow: switch (tier.state) {
          TierState.completed => [
            BoxShadow(
              color: colors.success.withValues(alpha: 0.15),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
          TierState.active => [
            BoxShadow(
              color: colors.primary100.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
          TierState.locked => [],
        },
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FittedBox(
            child: SizedBox(
              width: 56,
              height: 56,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(
                    value: 1,
                    strokeWidth: 3,
                    color: trackColor,
                  ),
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: progress),
                    duration: const Duration(milliseconds: 800),
                    curve: Curves.easeInOutCubic,
                    builder: (context, value, child) {
                      return CircularProgressIndicator(
                        value: value,
                        strokeWidth: 3,
                        strokeCap: StrokeCap.round,
                        color: fillColor,
                      );
                    },
                  ),
                  Icon(icon, size: 24, color: iconColor),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            tier.name,
            style: textTheme.bodySmallSemi.copyWith(color: nameColor),
            textAlign: TextAlign.center,
            maxLines: 1,
            // Ellipsis prevents long names from breaking the fixed width
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            progressText,
            style: textTheme.bodyExtraSmall.copyWith(
              color: progressTextColor,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
