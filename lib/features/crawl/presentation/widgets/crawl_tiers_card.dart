import 'package:flutter/material.dart';
import 'package:nook/features/crawl/domain/entities/crawl_tier.dart';
import 'package:nook/features/crawl/presentation/widgets/crawl_tier_chip.dart';
import 'package:nook/utils/theme/custom_themes/color_scheme.dart';
import 'package:nook/utils/theme/custom_themes/text_theme.dart';

class CrawlTiersCard extends StatelessWidget {
  final List<CrawlTier> tiers;

  const CrawlTiersCard({super.key, required this.tiers});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      // Removed horizontal padding from the outer container
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header remains padded to match the rest of the screen
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Milestones',
                  style: textTheme.bodyLargeMed.copyWith(color: colors.black),
                ),
                Text(
                  '${tiers.where((t) => t.isComplete).length}/${tiers.length}',
                  style: textTheme.bodySmall?.copyWith(color: colors.gray),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // The horizontal scroll view
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            // Added padding here for a clean, edge-to-edge scroll effect
            padding: const EdgeInsets.symmetric(horizontal: 0),
            child: Row(
              children: [
                for (int i = 0; i < tiers.length; i++) ...[
                  if (i > 0) const SizedBox(width: 12),
                  CrawlTierChip(tier: tiers[i]), 
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}