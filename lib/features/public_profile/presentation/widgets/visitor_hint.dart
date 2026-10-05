import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:nook/core/utils/adaptive_tap.dart';
import 'package:nook/features/profile/presentation/widgets/profile_tokens.dart';

/// One plain line at the top of the owner's Ranked tab: their ranking is
/// theirs alone, and what visitors get instead, with Preview to see it
/// (TikTok's "Only you can see this" caption; Tinder's Preview;
/// docs/references/public-profile).
class VisitorHint extends StatelessWidget {
  const VisitorHint({
    super.key,
    required this.highlightsPublic,
    required this.onPreview,
    this.likedCount = 3,
  });

  /// The owner's "Show my top cafes and gallery" switch.
  final bool highlightsPublic;

  /// Cafes ranked "Liked it": the only ones the Top 3 is drawn from.
  final int likedCount;
  final VoidCallback onPreview;

  @override
  Widget build(BuildContext context) {
    final String text;
    if (!highlightsPublic) {
      text =
          'Only you see your ranking. Your top cafes are hidden from '
          'visitors.';
    } else if (likedCount == 0) {
      // The strip is drawn from "Liked it" only, so with none there is no
      // Top 3 to promise.
      text =
          'Only you see your ranking. Cafes you mark Liked it become the '
          'top 3 visitors see.';
    } else if (likedCount < 3) {
      text = 'Only you see your ranking. Visitors see your top $likedCount.';
    } else {
      text = 'Only you see your ranking. Visitors see your top 3.';
    }
    return Row(
      children: [
        const Icon(LucideIcons.lock, size: 16, color: ProfileTokens.muted),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: ProfileTokens.text(12, color: ProfileTokens.muted),
          ),
        ),
        const SizedBox(width: 4),
        Semantics(
          button: true,
          label: 'Preview what visitors see',
          excludeSemantics: true,
          child: AdaptiveTap(
            onTap: onPreview,
            borderRadius: BorderRadius.circular(8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Center(
                  widthFactor: 1,
                  child: Text(
                    'Preview',
                    style: ProfileTokens.text(
                      13,
                      weight: FontWeight.w500,
                      color: ProfileTokens.brand,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
