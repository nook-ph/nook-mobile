import 'package:flutter/material.dart';
import 'package:nook/core/cafe/domain/entities/cafe_status.dart';
import 'package:nook/core/utils/adaptive_tap.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

/// Two-pill Been / Want to Try control (spec: docs/BEEN_WANT_TO_TRY.md §3.1).
/// Dumb widget: owns no state — parent decides what a tap means
/// (select / unset / login guard) and drives [status] / [isBusy].
class CafeStatusControl extends StatelessWidget {
  const CafeStatusControl({
    super.key,
    required this.status,
    required this.onTapBeen,
    required this.onTapWantToTry,
    this.onLongPressBeen,
    this.isBusy = false,
  });

  final CafeStatus status;
  final VoidCallback onTapBeen;
  final VoidCallback onTapWantToTry;

  /// Opens the private note when the cafe is already logged as Been.
  final VoidCallback? onLongPressBeen;
  final bool isBusy;

  static const _selectedBg = Color(0xFF3A5A40);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _StatusPill(
          label: 'Been',
          icon: PhosphorIcons.check,
          isSelected: status == CafeStatus.been,
          onTap: isBusy ? null : onTapBeen,
          onLongPress: status == CafeStatus.been ? onLongPressBeen : null,
        ),
        const SizedBox(width: 8),
        _StatusPill(
          label: 'Want to Try',
          icon: PhosphorIcons.bookmarkSimple,
          isSelected: status == CafeStatus.wantToTry,
          onTap: isBusy ? null : onTapWantToTry,
        ),
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
    this.onLongPress,
  });

  final String label;
  final PhosphorIconData Function(PhosphorIconsStyle) icon;
  final bool isSelected;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final foreground = isSelected ? Colors.white : const Color(0xFF3B3B3B);

    return AdaptiveTap(
      onTap: onTap ?? () {},
      onLongPress: onLongPress,
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? CafeStatusControl._selectedBg : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: isSelected
                ? CafeStatusControl._selectedBg
                : const Color(0xFFE0E0E0),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
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
            Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
                color: foreground,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
