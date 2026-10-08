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
  });

  /// The owner's "Show my gallery on my profile" switch, which also shows
  /// the ranked count.
  final bool highlightsPublic;
  final VoidCallback onPreview;

  @override
  Widget build(BuildContext context) {
    final text = highlightsPublic
        ? "Only you see your ranking. Visitors see how many cafes you've "
              'ranked.'
        : 'Only you see your ranking.';
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
