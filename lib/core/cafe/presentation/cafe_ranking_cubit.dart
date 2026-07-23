import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nook/core/cafe/domain/entities/cafe_ranking.dart';
import 'package:nook/core/cafe/domain/ranking_session.dart';
import 'package:nook/core/cafe/domain/use_cases/get_cafe_rankings_usecase.dart';
import 'package:nook/core/cafe/domain/use_cases/log_cafe_comparison_usecase.dart';
import 'package:nook/core/cafe/domain/use_cases/remove_cafe_ranking_usecase.dart';
import 'package:nook/core/cafe/domain/use_cases/set_cafe_ranking_usecase.dart';

/// App-wide personal cafe ranking, so a score set on the details page shows up
/// on the Been list without a refetch. Registered as a singleton, like
/// [CafeStatusCubit].
///
/// The comparison flow lives here as an explicit session ([startSession] →
/// [answerComparison] / [skipComparisons] → [commitSession]) rather than as
/// widget state, so backing out of the sheet can't strand a half-placed cafe.
class CafeRankingCubit extends Cubit<CafeRankingState> {
  CafeRankingCubit({
    required this.getCafeRankingsUseCase,
    required this.setCafeRankingUseCase,
    required this.removeCafeRankingUseCase,
    required this.logCafeComparisonUseCase,
  }) : super(const CafeRankingState());

  final GetCafeRankingsUseCase getCafeRankingsUseCase;
  final SetCafeRankingUseCase setCafeRankingUseCase;
  final RemoveCafeRankingUseCase removeCafeRankingUseCase;
  final LogCafeComparisonUseCase logCafeComparisonUseCase;

  /// Loads the whole ranking. Cheap — it is one user's own cafes — so callers
  /// can just call it on sign-in and after a Been list change.
  Future<void> load() async {
    try {
      final rankings = await getCafeRankingsUseCase();
      emit(state.copyWith(rankings: rankings, loaded: true));
    } catch (e, st) {
      // Scores silently stay hidden; the write path surfaces its own errors.
      debugPrint('[CafeRanking] load failed: $e\n$st');
    }
  }

  /// Opens a comparison session for [cafeId] in [bucket].
  ///
  /// Opponents are that bucket's cafes in rank order, minus the cafe being
  /// ranked — leaving it in would let a re-rank be compared against itself.
  /// The session is pure; nothing is written until [commitSession].
  RankingSession startSession(String cafeId, RankBucket bucket) {
    final opponents = state.rankings
        .where((r) => r.bucket == bucket && r.cafeId != cafeId)
        .map((r) => r.cafeId)
        .toList();

    final session = RankingSession(
      cafeId: cafeId,
      bucket: bucket,
      opponents: opponents,
    );
    emit(state.copyWith(session: session));
    return session;
  }

  /// Records one head-to-head answer and logs it for analytics.
  void answerComparison({required bool preferredTarget}) {
    final session = state.session;
    if (session == null || session.isComplete) return;

    final opponent = session.currentOpponent;
    session.answer(preferredTarget: preferredTarget);

    if (opponent != null) {
      // Fire and forget: the log is analytics, never a gate on the flow.
      unawaited(
        logCafeComparisonUseCase(
          winnerCafeId: preferredTarget ? session.cafeId : opponent,
          loserCafeId: preferredTarget ? opponent : session.cafeId,
        ),
      );
    }
    // RankingSession is mutable, so emit a fresh state object to notify.
    emit(state.copyWith(sessionRevision: state.sessionRevision + 1));
  }

  /// "Too close to call" — stop asking, keep the current best estimate.
  void skipComparisons() {
    state.session?.skip();
    emit(state.copyWith(sessionRevision: state.sessionRevision + 1));
  }

  /// Persists the session's landing position. Returns the committed ranking,
  /// or null on failure.
  ///
  /// On failure the cafe simply stays unranked: its Been mark was already
  /// saved server-side before ranking began, so there is nothing to roll back
  /// and nothing the user loses beyond the score. Callers surface a toast and
  /// close the sheet rather than trapping the user in a retry loop.
  Future<CafeRanking?> commitSession() async {
    final session = state.session;
    if (session == null) return null;
    if (state.pending.contains(session.cafeId)) return null;

    emit(state.copyWith(pending: {...state.pending, session.cafeId}));
    try {
      final rankings = await setCafeRankingUseCase(
        cafeId: session.cafeId,
        bucket: session.bucket,
        position: session.resolvedPosition,
      );
      // The server returns the whole refreshed ranking, so positions and
      // scores can never drift from what the database actually holds.
      emit(
        state.copyWith(
          rankings: rankings,
          loaded: true,
          pending: {...state.pending}..remove(session.cafeId),
          clearSession: true,
        ),
      );
      return state.rankingFor(session.cafeId);
    } catch (e, st) {
      debugPrint('[CafeRanking] commit for ${session.cafeId} failed: $e\n$st');
      emit(
        state.copyWith(
          pending: {...state.pending}..remove(session.cafeId),
          clearSession: true,
        ),
      );
      return null;
    }
  }

  /// Abandons the session without writing (sheet dismissed, back pressed).
  void cancelSession() => emit(state.copyWith(clearSession: true));

  /// Unranks a cafe, leaving its Been entry alone. Optimistic.
  Future<bool> remove(String cafeId) async {
    final previous = state.rankings;
    emit(
      state.copyWith(
        rankings: previous.where((r) => r.cafeId != cafeId).toList(),
      ),
    );
    try {
      await removeCafeRankingUseCase(cafeId);
      // Positions of the surviving cafes shift server-side, so re-read rather
      // than trying to renumber locally and getting the scores wrong.
      await load();
      return true;
    } catch (e, st) {
      debugPrint('[CafeRanking] remove($cafeId) failed: $e\n$st');
      emit(state.copyWith(rankings: previous));
      return false;
    }
  }

  /// Drops everything (sign-out) — rankings are per-user.
  void reset() => emit(const CafeRankingState());
}

class CafeRankingState extends Equatable {
  const CafeRankingState({
    this.rankings = const [],
    this.pending = const {},
    this.session,
    this.loaded = false,
    this.sessionRevision = 0,
  });

  /// Best first, liked → fine → disliked.
  final List<CafeRanking> rankings;

  /// Cafe ids with an in-flight write.
  final Set<String> pending;

  /// The open comparison session, if any.
  final RankingSession? session;

  /// True once a load has succeeded — lets the UI tell "no cafes ranked"
  /// apart from "not fetched yet".
  final bool loaded;

  /// Bumped on each session mutation. [RankingSession] is mutable by design
  /// (it is a cursor), so without this an Equatable state would compare equal
  /// after an answer and the UI would not rebuild.
  final int sessionRevision;

  CafeRanking? rankingFor(String cafeId) {
    for (final r in rankings) {
      if (r.cafeId == cafeId) return r;
    }
    return null;
  }

  bool isPending(String cafeId) => pending.contains(cafeId);

  /// Overall rank across all buckets, 1-based — the "#3 of 12" on the score
  /// reveal. Null when the cafe isn't ranked.
  int? overallRankOf(String cafeId) {
    final index = rankings.indexWhere((r) => r.cafeId == cafeId);
    return index < 0 ? null : index + 1;
  }

  int get rankedCount => rankings.length;

  CafeRankingState copyWith({
    List<CafeRanking>? rankings,
    Set<String>? pending,
    RankingSession? session,
    bool clearSession = false,
    bool? loaded,
    int? sessionRevision,
  }) {
    return CafeRankingState(
      rankings: rankings ?? this.rankings,
      pending: pending ?? this.pending,
      session: clearSession ? null : (session ?? this.session),
      loaded: loaded ?? this.loaded,
      sessionRevision: sessionRevision ?? this.sessionRevision,
    );
  }

  @override
  List<Object?> get props => [
    rankings,
    pending,
    session,
    loaded,
    sessionRevision,
  ];
}
