import 'package:flutter/material.dart';
import 'package:nook/core/cafe/domain/entities/cafe_status.dart';
import 'package:nook/core/utils/adaptive_tap.dart';
import 'package:nook/core/extensions/extensions.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

/// Been / Want to Try pills for the cafe details action bar (spec:
/// docs/BEEN_WANT_TO_TRY.md §3.1), rebuilt from the Claude Design project
/// "Been & Want to Try".
///
/// Dumb widget: owns no state — the parent decides what a tap means (select /
/// unset / login guard) and drives [status] / [isBusy].
///
/// The bar keeps three slots in every state. When the cafe is ranked, the
/// score merges into the Been pill ("✓ 5.5 · #8 of 9") and Want to Try
/// compresses to its icon rather than disappearing, which is what the previous
/// build did once a fourth control no longer fit.
class CafeStatusControl extends StatelessWidget {
  const CafeStatusControl({
    super.key,
    required this.status,
    required this.onTapBeen,
    required this.onTapWantToTry,
    this.isBusy = false,
    this.score,
    this.rankLabel,
  });

  final CafeStatus status;
  final VoidCallback onTapBeen;
  final VoidCallback onTapWantToTry;
  final bool isBusy;

  /// Pre-formatted one-decimal score ("5.5"), when the cafe is ranked.
  final String? score;

  /// "#8 of 9". Shown with [score] and never without it — a bare number reads
  /// as a review of the cafe (docs/RANKING_DESIGN.md §3.3).
  final String? rankLabel;

  bool get _isRanked => score != null;

  @override
  Widget build(BuildContext context) {
    final isBeen = status == CafeStatus.been;

    return Wrap(
      spacing: 6,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _Pill(
          onTap: isBusy ? null : onTapBeen,
          isSelected: isBeen,
          icon: PhosphorIcons.check,
          label: 'Been',
          score: _isRanked && isBeen ? score : null,
          rankLabel: _isRanked && isBeen ? rankLabel : null,
        ),
        _Pill(
          onTap: isBusy ? null : onTapWantToTry,
          isSelected: status == CafeStatus.wantToTry,
          icon: PhosphorIcons.bookmarkSimple,
          label: 'Want to Try',
          // Icon-only once the Been pill carries a score: four controls' jobs
          // in three slots. It stays tappable and stays 48pt.
          iconOnly: _isRanked && isBeen,
        ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.onTap,
    required this.isSelected,
    required this.icon,
    required this.label,
    this.score,
    this.rankLabel,
    this.iconOnly = false,
  });

  final VoidCallback? onTap;
  final bool isSelected;
  final PhosphorIconData Function(PhosphorIconsStyle) icon;
  final String label;
  final String? score;
  final String? rankLabel;
  final bool iconOnly;

  static const _selectedBg = Color(0xFF3A5A40);
  static const _border = Color(0xFFE0E0E0);
  static const _ink = Color(0xFF0A0F0D);

  @override
  Widget build(BuildContext context) {
    final foreground = isSelected ? Colors.white : _ink;

    return Semantics(
      button: true,
      selected: isSelected,
      label: iconOnly ? label : null,
      child: AdaptiveTap(
        onTap: onTap ?? () {},
        borderRadius: BorderRadius.circular(999),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          // Min height, never fixed: at 200% text scale the pills grow and the
          // row wraps instead of clipping.
          constraints: BoxConstraints(
            minHeight: 48,
            minWidth: iconOnly ? 48 : 0,
          ),
          padding: EdgeInsets.symmetric(
            horizontal: iconOnly ? 12 : 16,
            vertical: 10,
          ),
          decoration: BoxDecoration(
            color: isSelected ? _selectedBg : Colors.white,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: isSelected ? _selectedBg : _border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon(
                  isSelected
                      ? PhosphorIconsStyle.fill
                      : PhosphorIconsStyle.regular,
                ),
                size: 16,
                color: foreground,
              ),
              if (!iconOnly) ...[
                const SizedBox(width: 6),
                if (score == null)
                  Text(
                    label,
                    style: context.textTheme.bodyLargeMed.copyWith(
                      color: foreground,
                    ),
                  )
                else
                  // "5.5 · #8 of 9" — the score chip and the Been pill were
                  // always the same object, so they are one control now.
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: score,
                          style: context.textTheme.bodyLargeMed.copyWith(
                            color: foreground,
                          ),
                        ),
                        if (rankLabel != null)
                          TextSpan(
                            text: ' · $rankLabel',
                            style: context.textTheme.bodySmallMed.copyWith(
                              color: foreground.withValues(alpha: 0.85),
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
