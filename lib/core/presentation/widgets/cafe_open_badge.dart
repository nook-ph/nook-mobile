import 'package:flutter/material.dart';
import 'package:nook/core/cafe/domain/cafe_open_status.dart';
import 'package:nook/utils/theme/custom_themes/color_scheme.dart';
import 'package:nook/utils/theme/custom_themes/text_theme.dart';

/// Compact "Open / Closes in Nm / Closed" indicator for cafe cards.
///
/// Takes a resolved [CafeOpenStatus] rather than raw hours so the caller can
/// skip the badge *and* its surrounding gap when the state is
/// [CafeOpenState.unknown] — hours that are missing, malformed or a placeholder
/// must render nothing at all. A blank line is honest; "Closed" on a cafe that
/// is actually open is the one outcome worse than showing nothing.
///
/// The status is resolved by the caller at build time and does not tick on its
/// own. Map cards are short-lived and rebuild as the viewport and sheet change,
/// so a per-card timer would cost more than the staleness it removes; the
/// detail page is where an exact answer belongs.
class CafeOpenBadge extends StatelessWidget {
  const CafeOpenBadge({super.key, required this.status});

  final CafeOpenStatus status;

  @override
  Widget build(BuildContext context) {
    if (status.state == CafeOpenState.unknown) {
      return const SizedBox.shrink();
    }

    final colors = Theme.of(context).colorScheme;
    final (color, label) = switch (status.state) {
      CafeOpenState.open => (colors.success, 'Open'),
      CafeOpenState.closingSoon => (
        colors.warning,
        _closingSoonLabel(status.minutesUntilClose),
      ),
      CafeOpenState.closed => (colors.gray, 'Closed'),
      CafeOpenState.unknown => (colors.gray, ''),
    };

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(
            context,
          ).textTheme.bodySmallMed.copyWith(color: color, height: 1.1),
        ),
      ],
    );
  }

  /// The threshold is 45 minutes, so an hour label can never appear and plain
  /// minutes are enough.
  static String _closingSoonLabel(int? minutesUntilClose) {
    final minutes = minutesUntilClose ?? 0;
    if (minutes <= 1) return 'Closing now';
    return 'Closes in ${minutes}m';
  }
}
