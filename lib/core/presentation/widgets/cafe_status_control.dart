import 'package:flutter/material.dart';
import 'package:nook/core/cafe/domain/entities/cafe_status.dart';
import 'package:nook/core/utils/adaptive_tap.dart';
import 'package:nook/core/extensions/extensions.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

/// Been / Want to Try for the cafe details action bar (spec:
/// docs/BEEN_WANT_TO_TRY.md §3.1), rebuilt from the Claude Design project
/// "Been & Want to Try".
///
/// Dumb widget: owns no state — the parent decides what a tap means (select /
/// unset / login guard) and drives [status] / [isBusy].
///
/// **One segmented control, not two pills.** `CafeStatus` is an enum: a cafe is
/// Been *or* Want to Try, never both. Two free-standing pills read as two
/// independent toggles and left the row to be packed by hand, which parked an
/// arbitrary gap wherever the labels happened to end. A single filled track
/// expands to fill the row, so leftover width lands inside a real surface
/// instead of sitting as a hole next to the primary action.
///
/// When the cafe is ranked the score merges into the Been segment
/// ("✓ 5.5 · #8 of 9") and Want to Try shortens to "Try". Both segments always
/// announce their full name regardless of what the visible label says.
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

  static const _track = Color(0xFFF1F0EC);
  static const _trackBorder = Color(0xFFE0E0E0);

  bool get _isRanked => score != null;

  @override
  Widget build(BuildContext context) {
    final isBeen = status == CafeStatus.been;
    final showsScore = _isRanked && isBeen;

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: _track,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _trackBorder),
      ),
      child: Row(
        children: [
          // Weighted, not halved, and the weighting flips with the state:
          // unranked, "Want to Try" is the longer label and equal halves
          // clipped it to "Want to …"; ranked, the scored label
          // ("9.0 · #2 of 7") is the long one and "Try" needs almost nothing.
          Expanded(
            flex: showsScore ? 3 : 2,
            child: _Segment(
              onTap: isBusy ? null : onTapBeen,
              isSelected: isBeen,
              icon: PhosphorIcons.check,
              label: 'Been',
              score: showsScore ? score : null,
              rankLabel: showsScore ? rankLabel : null,
            ),
          ),
          Expanded(
            flex: showsScore ? 2 : 3,
            child: _Segment(
              onTap: isBusy ? null : onTapWantToTry,
              isSelected: status == CafeStatus.wantToTry,
              icon: PhosphorIcons.bookmarkSimple,
              label: 'Want to Try',
              compactLabel: showsScore ? 'Try' : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
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

  /// Short stand-in shown instead of [label] when the track is tight. [label]
  /// still goes to screen readers, so the spoken name never abbreviates.
  final String? compactLabel;

  static const _selectedBg = Color(0xFF3A5A40);
  static const _ink = Color(0xFF0A0F0D);

  /// Spoken name, always the full one. Built explicitly because the visible
  /// text is excluded below: it abbreviates ("Try") or replaces the name with
  /// a number ("9.3 · #2 of 7"), neither of which identifies the control.
  String get _semanticLabel {
    if (score == null) return label;
    return rankLabel == null ? '$label, $score' : '$label, $score, $rankLabel';
  }

  @override
  Widget build(BuildContext context) {
    final foreground = isSelected ? Colors.white : _ink;

    // MergeSemantics + ExcludeSemantics on the text, not a bare Semantics
    // wrapper: a plain `Semantics(label:)` around a subtree that has its own
    // gesture node left the button node's label empty — the compressed segment
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
            // Min height, never fixed: at 200% text scale the segments grow
            // and the bar reflows instead of clipping.
            constraints: const BoxConstraints(minHeight: 44),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: BoxDecoration(
              // Only the selected segment gets a surface — the track behind
              // carries the unselected one.
              color: isSelected ? _selectedBg : Colors.transparent,
              borderRadius: BorderRadius.circular(999),
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
                Flexible(
                  child: ExcludeSemantics(
                    child: score == null
                        ? Text(
                            compactLabel ?? label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.textTheme.bodyLargeMed.copyWith(
                              color: foreground,
                            ),
                          )
                        // "5.5 · #8 of 9" — the score chip and the Been pill
                        // were always the same object, so they are one control.
                        : Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(
                                  text: score,
                                  style: context.textTheme.bodyLargeMed
                                      .copyWith(color: foreground),
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
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
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
