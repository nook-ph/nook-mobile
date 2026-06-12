import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:gap/gap.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:nook/utils/theme/custom_themes/color_scheme.dart';

class StampAwardedOverlay extends StatelessWidget {
  final int stopOrder;
  final String? cafeName;
  final VoidCallback? onClose;
  final VoidCallback? onShare;

  const StampAwardedOverlay({
    super.key,
    required this.stopOrder,
    this.cafeName,
    this.onClose,
    this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      color: colors.success,
      child: Stack(
        children: [
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(LucideIcons.stamp, size: 80, color: Colors.white)
                    .animate()
                    .scale(
                      begin: const Offset(0, 0),
                      end: const Offset(1, 1),
                      duration: 500.ms,
                      curve: Curves.elasticOut,
                    )
                    .fadeIn(duration: 300.ms),
                const Gap(16),
                Text(
                  'Stop $stopOrder claimed!',
                  style: textTheme.titleSmall?.copyWith(
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.only(left: 12, top: 8),
                child: IconButton(
                  icon: const Icon(LucideIcons.x, color: Colors.white, size: 22),
                  onPressed: onClose ?? () {},
                ),
              ),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 32),
                child: OutlinedButton.icon(
                  icon: const Icon(LucideIcons.share2, color: Colors.white, size: 18),
                  label: const Text(
                    'Share',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.white),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: onShare ?? () {},
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
