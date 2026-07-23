import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:nook/core/analytics/analytics_service.dart';
import 'package:nook/core/cafe/domain/entities/cafe_status.dart';
import 'package:nook/core/cafe/presentation/cafe_status_cubit.dart';
import 'package:nook/core/presentation/widgets/cafe_status_control.dart';
import 'package:nook/core/utils/adaptive_tap.dart';
import 'package:nook/core/utils/toast_helper.dart';
import 'package:nook/features/cafe_details/domain/use_cases/get_cafe_details_usecase.dart';
import 'package:nook/features/cafe_details/presentation/utils/launch_cafe_directions.dart';
import 'package:nook/features/cafe_details/presentation/widgets/cafe_note_sheet.dart';
import 'package:nook/features/lists/bloc/lists_bloc.dart';
import 'package:nook/features/lists/bloc/lists_event.dart';
import 'package:nook/injection_container.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Sticky bottom bar on cafe details: Been / Want to Try status pills
/// (secondary) + Get Directions (primary CTA). Directions is the funnel's
/// conversion event — pinning it keeps it one tap away at any scroll depth.
class CafeActionsBar extends StatefulWidget {
  const CafeActionsBar({super.key, required this.cafe});

  final CafeDetailsResult cafe;

  @override
  State<CafeActionsBar> createState() => _CafeActionsBarState();
}

class _CafeActionsBarState extends State<CafeActionsBar> {
  String get _cafeId => widget.cafe.cafeDetails.id;

  /// Keeps toasts clear of the sticky bar they report on.
  ///
  /// Measured from the bar's own render box rather than estimated: the old
  /// `68 + padding.bottom` guess overshot the real height, which — stacked on
  /// the helper's 16 and toastification's built-in 12 — left the toast
  /// floating ~45pt above the bar. This getter is only read from tap
  /// handlers, so the bar is always laid out by the time it runs; the
  /// estimate remains as a fallback for safety.
  double get _toastOffset {
    final box = context.findRenderObject();
    if (box is RenderBox && box.hasSize) return box.size.height;
    return 68 + MediaQuery.of(context).padding.bottom;
  }

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  @override
  void didUpdateWidget(covariant CafeActionsBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.cafe.cafeDetails.id != _cafeId) _loadStatus();
  }

  void _loadStatus() {
    // get_cafe_statuses is authenticated-only; guests just see empty pills.
    if (Supabase.instance.client.auth.currentSession == null) return;
    context.read<CafeStatusCubit>().loadFor([_cafeId]);
  }

  Future<void> _onStatusTap(CafeStatus tapped) async {
    if (Supabase.instance.client.auth.currentSession == null) {
      context.push('/login');
      return;
    }

    final cubit = context.read<CafeStatusCubit>();
    final listsBloc = context.read<ListsBloc>();
    final current = cubit.state.statusFor(_cafeId);
    final next = current == tapped ? CafeStatus.none : tapped;

    if (next != CafeStatus.none) {
      // The "stamp" moment — make it feel good.
      HapticFeedback.lightImpact();
    }

    final ok = await cubit.set(_cafeId, next);
    if (!mounted) return;
    if (!ok) {
      showPrimaryToast(
        context,
        "Couldn't update. Please try again.",
        bottomOffset: _toastOffset,
      );
      return;
    }

    // Refresh Saved-tab counts (system lists live in the same lists infra).
    listsBloc.add(LoadUserLists());

    sl<AnalyticsService>().track(_cafeId, switch (next) {
      CafeStatus.been => 'mark_been',
      CafeStatus.wantToTry => 'mark_want_to_try',
      CafeStatus.none => 'unmark_status',
    });

    // Logging stays one tap — the note is offered after the write, never before.
    if (next == CafeStatus.been) {
      showPrimaryToastWithAction(
        context,
        'Added to Been',
        actionLabel: 'Add a note',
        onAction: () => showCafeNoteSheet(
          context,
          cafeId: _cafeId,
          cafeName: widget.cafe.cafeDetails.name,
        ),
        bottomOffset: _toastOffset,
      );
      return;
    }

    showPrimaryToast(context, switch (next) {
      CafeStatus.been => 'Added to Been',
      CafeStatus.wantToTry => 'Added to Want to Try',
      CafeStatus.none =>
        current == CafeStatus.been
            ? 'Removed from Been'
            : 'Removed from Want to Try',
    }, bottomOffset: _toastOffset);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE0E0E0))),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(
            children: [
              BlocBuilder<CafeStatusCubit, CafeStatusState>(
                buildWhen: (previous, current) =>
                    previous.statusFor(_cafeId) != current.statusFor(_cafeId) ||
                    previous.isPending(_cafeId) != current.isPending(_cafeId),
                builder: (context, state) {
                  return CafeStatusControl(
                    status: state.statusFor(_cafeId),
                    isBusy: state.isPending(_cafeId),
                    onTapBeen: () => _onStatusTap(CafeStatus.been),
                    onTapWantToTry: () => _onStatusTap(CafeStatus.wantToTry),
                    onLongPressBeen: () => showCafeNoteSheet(
                      context,
                      cafeId: _cafeId,
                      cafeName: widget.cafe.cafeDetails.name,
                    ),
                  );
                },
              ),
              const SizedBox(width: 8),
              Expanded(child: _DirectionsButton(cafe: widget.cafe)),
            ],
          ),
        ),
      ),
    );
  }
}

class _DirectionsButton extends StatelessWidget {
  const _DirectionsButton({required this.cafe});

  final CafeDetailsResult cafe;

  static const _brandGreen = Color(0xFF3A5A40);

  @override
  Widget build(BuildContext context) {
    return AdaptiveTap(
      onTap: () => launchCafeDirections(context, cafe),
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: _brandGreen,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              PhosphorIcons.navigationArrow(PhosphorIconsStyle.fill),
              size: 16,
              color: Colors.white,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                'Directions',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
