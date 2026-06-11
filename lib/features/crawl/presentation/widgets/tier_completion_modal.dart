import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:gap/gap.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:nook/core/cache/custom_cache_manager.dart';
import 'package:nook/features/crawl/domain/entities/stamp_claim_result.dart';
import 'package:nook/utils/theme/custom_themes/color_scheme.dart';
import 'package:nook/utils/theme/custom_themes/text_theme.dart';

class TierCompletionModal extends StatelessWidget {
  final TierCompletionResult tier;
  final VoidCallback onShare;
  final VoidCallback onContinue;

  const TierCompletionModal({
    super.key,
    required this.tier,
    required this.onShare,
    required this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: colors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const Gap(24),
          if (tier.badgeImageUrl != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: CachedNetworkImage(
                imageUrl: tier.badgeImageUrl!,
                cacheManager: CustomCacheManager.instance,
                width: 120,
                height: 120,
                fit: BoxFit.contain,
                errorWidget: (_, _, _) => _buildBadgePlaceholder(colors),
                placeholder: (_, _) => _buildBadgePlaceholder(colors),
              ),
            )
                .animate()
                .scale(
                  begin: const Offset(0, 0),
                  end: const Offset(1, 1),
                  duration: 500.ms,
                  curve: Curves.elasticOut,
                )
                .fadeIn(duration: 300.ms),
          if (tier.badgeImageUrl == null) _buildBadgePlaceholder(colors),
          const Gap(20),
          Text(
            'Tier Completed!',
            style: textTheme.bodyLarge?.copyWith(
              color: colors.gray,
              fontWeight: FontWeight.w500,
            ),
          ),
          const Gap(8),
          Text(
            tier.tierName,
            style: textTheme.titleLargeSemi.copyWith(
              color: colors.primary100,
            ),
          ),
          if (tier.completionCopy != null) ...[
            const Gap(12),
            Text(
              tier.completionCopy!,
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(color: colors.gray),
            ),
          ],
          const Gap(32),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onShare,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colors.primary100,
                    side: BorderSide(color: colors.primary100),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(LucideIcons.share2, size: 18),
                      const Gap(8),
                      const Text(
                        'Share',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Gap(12),
              Expanded(
                child: ElevatedButton(
                  onPressed: onContinue,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.primary100,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Continue',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBadgePlaceholder(ColorScheme colors) {
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        color: colors.primary20,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Icon(
        LucideIcons.trophy,
        size: 48,
        color: colors.primary40,
      ),
    );
  }
}
