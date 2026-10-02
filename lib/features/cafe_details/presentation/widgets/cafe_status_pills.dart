import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nook/core/analytics/analytics_service.dart';
import 'package:nook/core/cafe/domain/entities/cafe_ranking.dart';
import 'package:nook/core/cafe/domain/entities/cafe_status.dart';
import 'package:nook/core/cafe/domain/use_cases/get_cafe_note_usecase.dart';
import 'package:nook/core/cafe/domain/use_cases/set_cafe_note_usecase.dart';
import 'package:nook/core/cafe/presentation/cafe_ranking_cubit.dart';
import 'package:nook/core/cafe/presentation/cafe_status_cubit.dart';
import 'package:nook/core/presentation/widgets/cafe_status_control.dart';
import 'package:nook/core/presentation/widgets/confirm_sheet.dart';
import 'package:nook/core/utils/toast_helper.dart';
import 'package:nook/features/cafe_details/domain/use_cases/get_cafe_details_usecase.dart';
import 'package:nook/features/cafe_details/presentation/widgets/cafe_details_common.dart';
import 'package:nook/features/cafe_details/presentation/widgets/cafe_guest_sign_in_sheet.dart';
import 'package:nook/features/cafe_details/presentation/widgets/cafe_note_sheet.dart';
import 'package:nook/features/cafe_details/presentation/widgets/cafe_ranking_flow.dart';
import 'package:nook/features/lists/bloc/lists_bloc.dart';
import 'package:nook/features/lists/bloc/lists_event.dart';
import 'package:nook/features/lists/presentation/utils/open_been_list.dart';
import 'package:nook/injection_container.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Been / Want to Try, as two equal pills directly under the cafe's name.
///
/// These used to share the pinned bar with Directions. They are the user's
/// own list actions, so they now sit with the cafe's identity, and the bar
/// keeps the one action that takes you there.
class CafeStatusPills extends StatefulWidget {
  const CafeStatusPills({
    super.key,
    required this.cafe,
    required this.toastOffset,
  });

  final CafeDetailsResult cafe;

  /// Height of the pinned bar, read at tap time, so toasts land above it
  /// and never cover Directions.
  final double Function() toastOffset;

  @override
  State<CafeStatusPills> createState() => _CafeStatusPillsState();
}

class _CafeStatusPillsState extends State<CafeStatusPills> {
  String get _cafeId => widget.cafe.cafeDetails.id;

  double get _toastOffset => widget.toastOffset();

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  @override
  void didUpdateWidget(covariant CafeStatusPills oldWidget) {
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
      dismissToasts();
      await CafeGuestSignInSheet.show(
        context,
        action: tapped == CafeStatus.been
            ? CafeGuestAction.been
            : CafeGuestAction.wantToTry,
        cafeName: widget.cafe.cafeDetails.name,
      );
      return;
    }

    final cubit = context.read<CafeStatusCubit>();
    final rankingCubit = context.read<CafeRankingCubit>();
    final listsBloc = context.read<ListsBloc>();
    final cafeName = widget.cafe.cafeDetails.name;

    // The first read may have failed, leaving a Been cafe looking unmarked.
    // Acting on that guess would turn "Want to Try" into deleting its rank
    // and note, so ask again and stop if the answer still isn't in.
    if (!cubit.state.isKnown(_cafeId)) {
      await cubit.loadFor([_cafeId]);
      if (!mounted) return;
      if (!cubit.state.isKnown(_cafeId)) {
        showPrimaryToast(
          context,
          "Couldn't update. Please try again.",
          bottomOffset: _toastOffset,
        );
        return;
      }
    }

    final current = cubit.state.statusFor(_cafeId);
    final next = current == tapped ? CafeStatus.none : tapped;
    // Captured before the write: leaving Been deletes the ranking and the
    // note server-side, so these are the only copies Undo can restore from.
    final rankingBefore = rankingCubit.state.rankingFor(_cafeId);
    String? noteBefore;
    if (current == CafeStatus.been) {
      try {
        noteBefore = (await sl<GetCafeNoteUseCase>()(_cafeId))?.trim();
      } catch (_) {
        // Unreadable: Undo restores what it can.
      }
      if (!mounted) return;
    }
    final hasNote = noteBefore != null && noteBefore.isNotEmpty;

    // Been to Want to Try offers no Undo, so what it deletes is confirmed
    // first, the way every other destructive action in the app is.
    if (current == CafeStatus.been &&
        next == CafeStatus.wantToTry &&
        (rankingBefore != null || hasNote)) {
      dismissToasts();
      final confirmed = await showConfirmSheet(
        context,
        title: 'Move to Want to Try?',
        message: switch ((rankingBefore != null, hasNote)) {
          (true, true) => 'Your rank and note for $cafeName will be deleted.',
          (true, false) => 'Your rank for $cafeName will be deleted.',
          _ => 'Your note for $cafeName will be deleted.',
        },
        confirmLabel: 'Move',
      );
      if (!confirmed || !mounted) return;
    }

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
      // A toast about the previous tap must not sit on top of the sheet.
      dismissToasts();
      final outcome = await showCafeRankingFlow(
        context,
        cubit: rankingCubit,
        cafeId: _cafeId,
        cafeName: details.name,
        cafeImageUrl: details.featuredImageUrl?.trim().isNotEmpty == true
            ? details.featuredImageUrl!.trim()
            : (details.photos.isNotEmpty ? details.photos.first : null),
        cafeLocation: details.locationLabel,
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
            bottomOffset: _toastOffset,
          );
        case RankingFlowOutcome.completedViewList:
          await openBeenList(context);
        case RankingFlowOutcome.failed:
          showRankingFailedToast(context, bottomOffset: _toastOffset);
        case RankingFlowOutcome.skipped || null:
          showPrimaryToastWithAction(
            context,
            'Added to Been',
            actionLabel: 'Add a note',
            // The toast can outlive the page; there is then nothing to open
            // the sheet over.
            onAction: () {
              if (!mounted) return;
              showCafeNoteSheet(
                context,
                cafeId: _cafeId,
                cafeName: details.name,
                bottomOffset: _toastOffset,
              );
            },
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
      final cafeId = _cafeId;
      showPrimaryToastWithAction(
        context,
        wasBeen
            ? switch ((rankingBefore != null, hasNote)) {
                (true, true) => 'Removed from Been — rank and note deleted.',
                (true, false) => 'Removed from Been — rank deleted.',
                (false, true) => 'Removed from Been — note deleted.',
                _ => 'Removed from Been',
              }
            : 'Removed from Want to Try',
        actionLabel: 'Undo',
        // The cubits are app-wide and captured here, so Undo still restores
        // everything when the toast is tapped after leaving the page.
        onAction: () => _undoUnset(
          cafeId: cafeId,
          previous: current,
          ranking: rankingBefore,
          note: hasNote ? noteBefore : null,
          cubit: cubit,
          rankingCubit: rankingCubit,
          listsBloc: listsBloc,
        ),
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

  /// Restores the mark, and the ranking and note that went with it. Takes
  /// everything it needs as arguments: it may run after this page is gone.
  Future<void> _undoUnset({
    required String cafeId,
    required CafeStatus previous,
    required CafeRanking? ranking,
    required String? note,
    required CafeStatusCubit cubit,
    required CafeRankingCubit rankingCubit,
    required ListsBloc listsBloc,
  }) async {
    final ok = await cubit.set(cafeId, previous);
    if (!ok) {
      if (!mounted) return;
      showPrimaryToast(
        context,
        "Couldn't undo. Please try again.",
        bottomOffset: _toastOffset,
      );
      return;
    }

    listsBloc.add(LoadUserLists());

    if (previous != CafeStatus.been) return;
    if (ranking != null) {
      await rankingCubit.restore(
        cafeId: cafeId,
        bucket: ranking.bucket,
        position: ranking.position,
      );
    }
    if (note != null) {
      try {
        await sl<SetCafeNoteUseCase>()(cafeId, note);
        cafeNoteChanges.value++;
      } catch (e) {
        debugPrint('[CafeStatusPills] note restore failed: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: CafeDetailsTokens.gutter),
      child: BlocBuilder<CafeStatusCubit, CafeStatusState>(
        buildWhen: (previous, current) =>
            previous.statusFor(_cafeId) != current.statusFor(_cafeId) ||
            previous.isPending(_cafeId) != current.isPending(_cafeId),
        builder: (context, state) {
          return LayoutBuilder(
            builder: (context, constraints) {
              // Two halves of a narrow or large-text screen cannot hold
              // "Want to Try" in full; the label shortens before it clips.
              final scale = MediaQuery.textScalerOf(context).scale(15) / 15;
              final compact = constraints.maxWidth / scale < 300;
              return BlocSelector<CafeRankingCubit, CafeRankingState, String?>(
                selector: (ranking) =>
                    ranking.rankingFor(_cafeId)?.displayScore,
                builder: (context, score) => CafeStatusControl(
                  fill: true,
                  compact: compact,
                  status: state.statusFor(_cafeId),
                  isBusy: state.isPending(_cafeId),
                  score: score,
                  onTapBeen: () => _onStatusTap(CafeStatus.been),
                  onTapWantToTry: () => _onStatusTap(CafeStatus.wantToTry),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
