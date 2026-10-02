import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:nook/core/cafe/domain/entities/cafe_status.dart';
import 'package:nook/core/cafe/presentation/cafe_status_cubit.dart';
import 'package:nook/core/extensions/extensions.dart';

/// "✓ Been" / "🔖 Want to try" overlay for a cafe card's photo (spec:
/// docs/BEEN_WANT_TO_TRY.md §3.2).
///
/// Status only — the score and the note stay on the cafe page. Without this
/// the feature was invisible everywhere except the one details screen, so a
/// user browsing had no way to see they had already been somewhere.
///
/// Renders nothing when the cafe is unmarked, which is the common case, so it
/// is safe to drop into any card. Statuses come from one batched
/// `get_cafe_statuses` per screen via [CafeStatusCubit] — never per card.
class CafeStatusBadge extends StatelessWidget {
  const CafeStatusBadge({super.key, required this.cafeId});

  final String cafeId;

  static const _brand = Color(0xFF344E41);
  static const _ink = Color(0xFF0A0F0D);
  static const _fill = Color(0xFFFEFEFE);

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CafeStatusCubit, CafeStatusState>(
      buildWhen: (previous, current) =>
          previous.statusFor(cafeId) != current.statusFor(cafeId),
      builder: (context, state) {
        final status = state.statusFor(cafeId);
        if (status == CafeStatus.none) return const SizedBox.shrink();

        final isBeen = status == CafeStatus.been;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: _fill,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isBeen ? LucideIcons.check : LucideIcons.bookmark,
                size: 12,
                color: _brand,
              ),
              const SizedBox(width: 4),
              Text(
                isBeen ? 'Been' : 'Want to try',
                style: context.textTheme.bodySmallMed.copyWith(
                  color: _ink,
                  fontSize: 10,
                  height: 1.5,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
