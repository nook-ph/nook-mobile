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
/// shortens to "Try" rather than disappearing, which is what the previous
/// build did once a fourth control no longer fit. Both pills always announce
/// their full name regardless of what the visible label says.
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
          // Compressed, not stripped, once the Been pill carries a score: four
          // controls' jobs in three slots. It was icon-only, which left a bare
          // bookmark glyph sitting a thumb away from the save-to-list bookmark
          // in the header — same icon, different job. A one-word label keeps
          // the row on one line and says which one this is.
          compactLabel: _isRanked && isBeen ? 'Try' : null,
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
    this.compactLabel,
  });

  final VoidCallback? onTap;
  final bool isSelected;
  final PhosphorIconData Function(PhosphorIconsStyle) icon;
  final String label;
  final String? score;
  final String? rankLabel;

  /// Short stand-in shown instead of [label] when the bar is tight. [label]
  /// still goes to screen readers, so the spoken name never abbreviates.
  final String? compactLabel;

  static const _selectedBg = Color(0xFF3A5A40);
  static const _border = Color(0xFFE0E0E0);
  static const _ink = Color(0xFF0A0F0D);

  /// Spoken name, always the full one. Built explicitly because the visible
  /// text is excluded below: it abbreviates ("Try") or replaces the name with
  /// a number ("9.3 · #2 of 8"), neither of which identifies the control.
  String get _semanticLabel {
    if (score == null) return label;
    return rankLabel == null ? '$label, $score' : '$label, $score, $rankLabel';
  }

  @override
  Widget build(BuildContext context) {
    final foreground = isSelected ? Colors.white : _ink;

    // MergeSemantics + ExcludeSemantics on the text, not a bare Semantics
    // wrapper: a plain `Semantics(label:)` around a subtree that has its own
    // gesture node left the button node's label empty — the compressed pill
    // announced itself as nothing at all.
    return MergeSemantics(
      child: Semantics(
        button: true,
        selected: isSelected,
        label: _semanticLabel,
        child: AdaptiveTap(
          onTap: onTap ?? () {},
          borderRadius: BorderRadius.circular(999),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            // Min height, never fixed: at 200% text scale the pills grow and the
            // row wraps instead of clipping.
            constraints: const BoxConstraints(minHeight: 48),
            padding: EdgeInsets.symmetric(
              horizontal: compactLabel != null ? 12 : 14,
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
                const SizedBox(width: 6),
                // The visible text is decoration for the label above, so it is
                // kept out of the semantics tree rather than merged into it.
                ExcludeSemantics(
                  child: score == null
                      ? Text(
                          compactLabel ?? label,
                          style: context.textTheme.bodyLargeMed.copyWith(
                            color: foreground,
                          ),
                        )
                      // "5.5 · #8 of 9" — the score chip and the Been pill were
                      // always the same object, so they are one control now.
                      : Text.rich(
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
                                  style: context.textTheme.bodySmallMed
                                      .copyWith(
                                        color: foreground.withValues(
                                          alpha: 0.85,
                                        ),
                                      ),
                                ),
                            ],
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
