import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:nook/core/analytics/analytics_service.dart';
import 'package:nook/core/cafe/domain/entities/cafe_ranking.dart';
import 'package:nook/core/cafe/domain/entities/cafe_status.dart';
import 'package:nook/core/cafe/presentation/cafe_ranking_cubit.dart';
import 'package:nook/core/cafe/presentation/cafe_status_cubit.dart';
import 'package:nook/core/presentation/widgets/cafe_status_control.dart';
import 'package:nook/core/utils/adaptive_tap.dart';
import 'package:nook/core/utils/toast_helper.dart';
import 'package:nook/features/cafe_details/domain/use_cases/get_cafe_details_usecase.dart';
import 'package:nook/features/cafe_details/presentation/utils/launch_cafe_directions.dart';
import 'package:nook/features/cafe_details/presentation/widgets/cafe_note_sheet.dart';
import 'package:nook/features/cafe_details/presentation/widgets/cafe_ranking_flow.dart';
import 'package:nook/features/lists/bloc/lists_bloc.dart';
import 'package:nook/features/lists/bloc/lists_event.dart';
import 'package:nook/features/lists/presentation/utils/open_been_list.dart';
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
    // The ranking flow needs opponents; make sure they're in before the user
    // can possibly tap Been. Idempotent and cheap (one user's own rows).
    final ranking = context.read<CafeRankingCubit>();
    if (!ranking.state.loaded) unawaited(ranking.load());
  }

  Future<void> _onStatusTap(CafeStatus tapped) async {
    if (Supabase.instance.client.auth.currentSession == null) {
      context.push('/login');
      return;
    }

    final cubit = context.read<CafeStatusCubit>();
    final rankingCubit = context.read<CafeRankingCubit>();
    final listsBloc = context.read<ListsBloc>();
    final current = cubit.state.statusFor(_cafeId);
    final next = current == tapped ? CafeStatus.none : tapped;
    // Captured before the write: leaving Been deletes the ranking server-side,
    // so this is the only copy Undo can restore from.
    final rankingBefore = rankingCubit.state.rankingFor(_cafeId);

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

    // Leaving Been drops the ranking server-side (trigger); refresh the local
    // cache so a stale score doesn't linger on this session's surfaces.
    if (current == CafeStatus.been && next != CafeStatus.been) {
      unawaited(rankingCubit.load());
    }

    // Logging stays one tap — ranking is offered after the write, never
    // before, and skipping it falls back to exactly the old toast.
    if (next == CafeStatus.been) {
      final details = widget.cafe.cafeDetails;
      final outcome = await showCafeRankingFlow(
        context,
        cubit: rankingCubit,
        cafeId: _cafeId,
        cafeName: details.name,
        cafeImageUrl: details.featuredImageUrl?.trim().isNotEmpty == true
            ? details.featuredImageUrl!.trim()
            : (details.photos.isNotEmpty ? details.photos.first : null),
      );
      if (!mounted) return;

      switch (outcome) {
        case RankingFlowOutcome.completed:
          break; // The score reveal was the feedback.
        case RankingFlowOutcome.completedAddNote:
          await showCafeNoteSheet(
            context,
            cafeId: _cafeId,
            cafeName: details.name,
          );
        case RankingFlowOutcome.completedViewList:
          await openBeenList(context);
        case RankingFlowOutcome.failed:
          showPrimaryToast(
            context,
            "Couldn't save your ranking — your Been is safe.",
            bottomOffset: _toastOffset,
          );
        case RankingFlowOutcome.skipped || null:
          showPrimaryToastWithAction(
            context,
            'Added to Been',
            actionLabel: 'Add a note',
            onAction: () => showCafeNoteSheet(
              context,
              cafeId: _cafeId,
              cafeName: details.name,
            ),
            bottomOffset: _toastOffset,
          );
      }
      return;
    }

    // Unsetting is one tap and instant, as it always was — but it silently
    // destroyed a score built out of four comparisons. The spec called for an
    // undo toast here (§3.1); this is it, and it says what was lost.
    if (next == CafeStatus.none) {
      final wasBeen = current == CafeStatus.been;
      showPrimaryToastWithAction(
        context,
        wasBeen
            ? (rankingBefore == null
                  ? 'Removed from Been'
                  : 'Removed from Been — rank deleted.')
            : 'Removed from Want to Try',
        actionLabel: 'Undo',
        onAction: () => _undoUnset(current, rankingBefore),
        bottomOffset: _toastOffset,
      );
      return;
    }

    showPrimaryToast(context, switch (next) {
      CafeStatus.been => 'Added to Been',
      CafeStatus.wantToTry => 'Added to Want to Try',
      CafeStatus.none => '',
    }, bottomOffset: _toastOffset);
  }

  /// Restores the mark, and the ranking that went with it.
  Future<void> _undoUnset(CafeStatus previous, CafeRanking? ranking) async {
    final cubit = context.read<CafeStatusCubit>();
    final rankingCubit = context.read<CafeRankingCubit>();
    final listsBloc = context.read<ListsBloc>();

    final ok = await cubit.set(_cafeId, previous);
    if (!mounted) return;
    if (!ok) {
      showPrimaryToast(
        context,
        "Couldn't undo. Please try again.",
        bottomOffset: _toastOffset,
      );
      return;
    }

    listsBloc.add(LoadUserLists());

    if (previous == CafeStatus.been && ranking != null) {
      await rankingCubit.restore(
        cafeId: _cafeId,
        bucket: ranking.bucket,
        position: ranking.position,
      );
    }
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
          // 16, not 22: three controls with full labels need every point of
          // width to stay on one line at the common 360–412dp widths.
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: BlocBuilder<CafeStatusCubit, CafeStatusState>(
            buildWhen: (previous, current) =>
                previous.statusFor(_cafeId) != current.statusFor(_cafeId) ||
                previous.isPending(_cafeId) != current.isPending(_cafeId),
            builder: (context, state) {
              return BlocBuilder<CafeRankingCubit, CafeRankingState>(
                builder: (context, rankingState) {
                  final ranking = rankingState.rankingFor(_cafeId);
                  final overall = rankingState.overallRankOf(_cafeId);

                  CafeStatusControl controls({bool compact = false}) =>
                      CafeStatusControl(
                        status: state.statusFor(_cafeId),
                        isBusy: state.isPending(_cafeId),
                        compact: compact,
                        score: ranking?.displayScore,
                        rankLabel: ranking == null || overall == null
                            ? null
                            : '#$overall of ${rankingState.rankedCount}',
                        onTapBeen: () => _onStatusTap(CafeStatus.been),
                        onTapWantToTry: () =>
                            _onStatusTap(CafeStatus.wantToTry),
                      );

                  // Two layouts, not one that clips. At normal type the bar is
                  // a row with Directions taking the remaining width; once the
                  // user scales text up, the pills wrap and Directions drops to
                  // a full-width run of its own. Nothing truncates and every
                  // target stays ≥48pt either way.
                  final scale = MediaQuery.textScalerOf(context).scale(15) / 15;
                  if (scale > 1.3) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        controls(),
                        const SizedBox(height: 8),
                        _DirectionsButton(cafe: widget.cafe),
                      ],
                    );
                  }

                  return LayoutBuilder(
                    builder: (context, constraints) {
                      // Directions expands, so the row always reaches the edge
                      // and never leaves a gap. What that costs is the CTA's
                      // own label when the row runs short — so the status
                      // labels are made to yield first: below the width where
                      // both full labels plus a natural-width Directions fit
                      // (~90 + 135 + 6 gaps + ~130), Want to Try shortens to
                      // "Try". The conversion event keeps its label at every
                      // width; the toggles give way instead.
                      final compact = constraints.maxWidth < 380;
                      return Row(
                        children: [
                          controls(compact: compact),
                          const SizedBox(width: 6),
                          // Directions never moves slot and never changes fill
                          // — it is the funnel's conversion event.
                          Expanded(child: _DirectionsButton(cafe: widget.cafe)),
                        ],
                      );
                    },
                  );
                },
              );
            },
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
        constraints: const BoxConstraints(minHeight: 48),
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
