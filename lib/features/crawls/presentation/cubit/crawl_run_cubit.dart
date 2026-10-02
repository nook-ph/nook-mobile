import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nook/core/analytics/analytics_service.dart';
import 'package:nook/features/crawls/data/stamp_locator.dart';
import 'package:nook/features/crawls/domain/entities/crawl.dart';
import 'package:nook/features/crawls/domain/entities/crawl_exception.dart';
import 'package:nook/features/crawls/domain/entities/crawl_run.dart';
import 'package:nook/features/crawls/domain/use_cases/claim_crawl_stamp_usecase.dart';
import 'package:nook/features/crawls/domain/use_cases/get_crawl_run_usecase.dart';
import 'package:nook/features/crawls/domain/use_cases/leave_crawl_run_usecase.dart';

enum CrawlRunStatus { loading, loaded, error }

/// Where one stamp attempt is. `idle` between attempts.
enum StampPhase { idle, locating, claiming, stamped, failed }

class CrawlRunState extends Equatable {
  final CrawlRunStatus status;
  final CrawlRun? run;
  final Object? error;

  final StampPhase stampPhase;

  /// The stop the current (or last) attempt is for.
  final CrawlStop? stampStop;

  /// Why the last attempt failed. A [CrawlException] when the UI has specific
  /// copy for it; anything else goes through `AppErrorCopy`.
  final Object? stampError;

  /// True while the leave-run request is in flight.
  final bool isLeaving;

  const CrawlRunState({
    this.status = CrawlRunStatus.loading,
    this.run,
    this.error,
    this.stampPhase = StampPhase.idle,
    this.stampStop,
    this.stampError,
    this.isLeaving = false,
  });

  bool get isStamping =>
      stampPhase == StampPhase.locating || stampPhase == StampPhase.claiming;

  CrawlRunState copyWith({
    CrawlRunStatus? status,
    CrawlRun? run,
    Object? error,
    StampPhase? stampPhase,
    CrawlStop? stampStop,
    Object? stampError,
    bool? isLeaving,
  }) {
    return CrawlRunState(
      status: status ?? this.status,
      run: run ?? this.run,
      error: error,
      stampPhase: stampPhase ?? this.stampPhase,
      stampStop: stampStop ?? this.stampStop,
      stampError: stampError,
      isLeaving: isLeaving ?? this.isLeaving,
    );
  }

  @override
  List<Object?> get props => [
    status,
    run,
    error,
    stampPhase,
    stampStop,
    stampError,
    isLeaving,
  ];
}

class CrawlRunCubit extends Cubit<CrawlRunState> {
  CrawlRunCubit({
    required this.getCrawlRunUseCase,
    required this.claimCrawlStampUseCase,
    required this.leaveCrawlRunUseCase,
    required this.locator,
    required this.analytics,
    this.fakeStamps = false,
  }) : super(const CrawlRunState());

  final GetCrawlRunUseCase getCrawlRunUseCase;
  final ClaimCrawlStampUseCase claimCrawlStampUseCase;
  final LeaveCrawlRunUseCase leaveCrawlRunUseCase;
  final IStampLocator locator;
  final AnalyticsService analytics;

  /// Dev aid (`AppConstants.fakeStamps`): [stamp] marks the stop on this
  /// device only, without a fix or a server call.
  final bool fakeStamps;

  /// Stamps made up on this device. Kept apart from the run so a refetch,
  /// which knows nothing of them, does not wipe them.
  final List<CrawlStamp> _fakes = [];

  CrawlRun _withFakes(CrawlRun run) {
    if (_fakes.isEmpty) return run;
    final real = run.myStampedStopIds;
    return CrawlRun(
      id: run.id,
      inviteCode: run.inviteCode,
      plannedFor: run.plannedFor,
      crawl: run.crawl,
      members: run.members,
      stamps: [
        ...run.stamps,
        for (final fake in _fakes)
          if (!real.contains(fake.stopId)) fake,
      ],
    );
  }

  Future<void> load(String runId, {CrawlRun? initial}) async {
    if (initial != null) {
      emit(CrawlRunState(status: CrawlRunStatus.loaded, run: initial));
    } else {
      emit(const CrawlRunState());
    }
    await _fetch(runId);
  }

  /// Crew progress is not realtime in v1: refetch on resume and pull-down.
  Future<void> refresh() async {
    final run = state.run;
    if (run == null || state.isStamping) return;
    await _fetch(run.id);
  }

  Future<void> _fetch(String runId) async {
    try {
      final run = _withFakes(await getCrawlRunUseCase(runId));
      emit(state.copyWith(status: CrawlRunStatus.loaded, run: run));
    } catch (e, st) {
      debugPrint('[CrawlRun] fetch($runId) failed: $e\n$st');
      if (state.run == null) {
        emit(state.copyWith(status: CrawlRunStatus.error, error: e));
      }
    }
  }

  /// Gets a fresh fix, then asks the server to count it. The server is the
  /// only judge — a client-side "you look close enough" never awards a stamp.
  Future<void> stamp(CrawlStop stop, {String? note}) async {
    final run = state.run;
    if (run == null || state.isStamping) return;

    final me = run.me;
    if (fakeStamps && me != null) {
      // Not tracked: a made-up stamp is not a stamp attempt.
      _fakes.add(
        CrawlStamp(
          stopId: stop.stopId,
          userId: me.userId,
          claimedAt: DateTime.now(),
        ),
      );
      emit(
        state.copyWith(
          run: _withFakes(run),
          stampPhase: StampPhase.stamped,
          stampStop: stop,
        ),
      );
      return;
    }

    emit(state.copyWith(stampPhase: StampPhase.locating, stampStop: stop));
    try {
      final fix = await locator.currentFix();
      emit(state.copyWith(stampPhase: StampPhase.claiming));

      final updated = await claimCrawlStampUseCase(
        runId: run.id,
        stopId: stop.stopId,
        lat: fix.lat,
        lng: fix.lng,
        accuracyMeters: fix.accuracyMeters,
        note: note,
      );

      _track('claimed', stop, updated);
      emit(state.copyWith(run: updated, stampPhase: StampPhase.stamped));
    } catch (e, st) {
      debugPrint('[CrawlRun] stamp(${stop.stopId}) failed: $e\n$st');
      _track(_resultOf(e), stop, run, error: e);
      emit(state.copyWith(stampPhase: StampPhase.failed, stampError: e));
    }
  }

  /// Called when the stamp sheet closes.
  void clearStamp() {
    if (state.isStamping) return;
    emit(state.copyWith(stampPhase: StampPhase.idle));
  }

  /// Leaves the run, which drops the caller's stamps for it. Returns whether
  /// it worked; the page pops on true and says so on false.
  Future<bool> leave() async {
    final run = state.run;
    if (run == null || state.isLeaving || state.isStamping) return false;

    emit(state.copyWith(isLeaving: true));
    try {
      await leaveCrawlRunUseCase(run.id);
      analytics.logEvent(
        'crawl_run_left',
        properties: {
          'stamps': run.myStampCount,
          'stop_count': run.crawl.stops.length,
          'crew_size': run.members.length,
        },
      );
      emit(state.copyWith(isLeaving: false));
      return true;
    } catch (e, st) {
      debugPrint('[CrawlRun] leave(${run.id}) failed: $e\n$st');
      emit(state.copyWith(isLeaving: false));
      return false;
    }
  }

  void trackInviteShared() {
    final run = state.run;
    if (run == null) return;
    analytics.logEvent(
      'crew_invite_shared',
      properties: {
        'crew_size': run.members.length,
        'stop_count': run.crawl.stops.length,
      },
    );
  }

  static String _resultOf(Object error) => switch (error) {
    StampTooFar() => 'too_far',
    StampTooSoon() => 'too_soon',
    StampLowAccuracy() => 'low_accuracy',
    StampLocationUnavailable() => 'no_location',
    _ => 'error',
  };

  void _track(String result, CrawlStop stop, CrawlRun run, {Object? error}) {
    analytics.logEvent(
      'stamp_attempted',
      properties: {
        'result': result,
        'stop_order': stop.order,
        'stop_count': run.crawl.stops.length,
        if (error is StampTooFar) 'distance_m': error.distanceMeters,
        if (error is StampLowAccuracy) 'accuracy_m': error.accuracyMeters,
      },
    );
    if (result != 'claimed') return;
    analytics.logEvent(
      'stamp_claimed',
      properties: {'stop_order': stop.order, 'crew_size': run.members.length},
    );
    if (run.isComplete) {
      analytics.logEvent(
        'crawl_completed',
        properties: {
          'stop_count': run.crawl.stops.length,
          'crew_size': run.members.length,
        },
      );
    }
  }
}
