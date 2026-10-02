import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nook/core/analytics/analytics_service.dart';
import 'package:nook/features/crawls/domain/entities/crawl.dart';
import 'package:nook/features/crawls/domain/entities/crawl_run.dart';
import 'package:nook/features/crawls/domain/use_cases/archive_crawl_usecase.dart';
import 'package:nook/features/crawls/domain/use_cases/get_crawl_by_code_usecase.dart';
import 'package:nook/features/crawls/domain/use_cases/start_crawl_run_usecase.dart';

enum CrawlDetailStatus { loading, loaded, error }

class CrawlDetailState extends Equatable {
  final CrawlDetailStatus status;
  final Crawl? crawl;

  /// A start or archive is in flight.
  final bool busy;

  /// The in-flight action is a run starting (the button says so).
  final bool starting;

  /// Set once when a run starts; the page navigates and clears it.
  final CrawlRun? startedRun;
  final bool archived;
  final Object? error;

  const CrawlDetailState({
    this.status = CrawlDetailStatus.loading,
    this.crawl,
    this.busy = false,
    this.starting = false,
    this.startedRun,
    this.archived = false,
    this.error,
  });

  CrawlDetailState copyWith({
    CrawlDetailStatus? status,
    Crawl? crawl,
    bool? busy,
    bool? starting,
    CrawlRun? startedRun,
    bool clearStartedRun = false,
    bool? archived,
    Object? error,
  }) {
    return CrawlDetailState(
      status: status ?? this.status,
      crawl: crawl ?? this.crawl,
      busy: busy ?? this.busy,
      // Only ever true alongside `busy`, and only when asked for.
      starting: (busy ?? this.busy) && (starting ?? this.starting),
      startedRun: clearStartedRun ? null : (startedRun ?? this.startedRun),
      archived: archived ?? this.archived,
      error: error,
    );
  }

  @override
  List<Object?> get props => [
    status,
    crawl,
    busy,
    starting,
    startedRun,
    archived,
    error,
  ];
}

class CrawlDetailCubit extends Cubit<CrawlDetailState> {
  CrawlDetailCubit({
    required this.getCrawlByCodeUseCase,
    required this.startCrawlRunUseCase,
    required this.archiveCrawlUseCase,
    required this.analytics,
  }) : super(const CrawlDetailState());

  final GetCrawlByCodeUseCase getCrawlByCodeUseCase;
  final StartCrawlRunUseCase startCrawlRunUseCase;
  final ArchiveCrawlUseCase archiveCrawlUseCase;
  final AnalyticsService analytics;

  /// Shows [initial] at once when the caller already has the crawl (just
  /// created, or tapped from the Lists tab), then refreshes its counts.
  Future<void> load(String shareCode, {Crawl? initial}) async {
    if (initial != null) {
      emit(CrawlDetailState(status: CrawlDetailStatus.loaded, crawl: initial));
    } else {
      emit(const CrawlDetailState());
    }
    try {
      final crawl = await getCrawlByCodeUseCase(shareCode);
      if (isClosed) return;
      emit(state.copyWith(status: CrawlDetailStatus.loaded, crawl: crawl));
    } catch (e, st) {
      debugPrint('[CrawlDetail] load($shareCode) failed: $e\n$st');
      if (isClosed) return;
      // A failed refresh must not take a crawl that is already on screen away.
      if (state.crawl == null) {
        emit(state.copyWith(status: CrawlDetailStatus.error, error: e));
      }
    }
  }

  Future<void> startRun() async {
    final crawl = state.crawl;
    if (crawl == null || state.busy) return;
    emit(state.copyWith(busy: true, starting: true));
    try {
      final run = await startCrawlRunUseCase(crawl.id);
      analytics.logEvent(
        'crawl_run_started',
        properties: {
          'stop_count': crawl.stops.length,
          'is_creator': crawl.isCreator,
        },
      );
      if (isClosed) return;
      emit(state.copyWith(busy: false, startedRun: run));
    } catch (e, st) {
      debugPrint('[CrawlDetail] startRun failed: $e\n$st');
      if (isClosed) return;
      emit(state.copyWith(busy: false, error: e));
    }
  }

  void consumeStartedRun() => emit(state.copyWith(clearStartedRun: true));

  Future<void> archive() async {
    final crawl = state.crawl;
    if (crawl == null || state.busy) return;
    emit(state.copyWith(busy: true));
    try {
      await archiveCrawlUseCase(crawl.id);
      if (isClosed) return;
      // The page stays open on the archived crawl, so reflect it at once
      // instead of waiting for a refetch.
      emit(
        state.copyWith(
          busy: false,
          archived: true,
          crawl: _withStatus(crawl, 'archived'),
        ),
      );
    } catch (e, st) {
      debugPrint('[CrawlDetail] archive failed: $e\n$st');
      if (isClosed) return;
      emit(state.copyWith(busy: false, error: e));
    }
  }

  /// Puts an edited crawl (a new title) on screen without a refetch.
  void replaceCrawl(Crawl crawl) {
    if (state.status != CrawlDetailStatus.loaded) return;
    emit(state.copyWith(crawl: crawl));
  }

  static Crawl _withStatus(Crawl crawl, String status) => Crawl(
    id: crawl.id,
    title: crawl.title,
    description: crawl.description,
    shareCode: crawl.shareCode,
    isLinkVisible: crawl.isLinkVisible,
    status: status,
    isCreator: crawl.isCreator,
    creatorUsername: crawl.creatorUsername,
    creatorAvatarUrl: crawl.creatorAvatarUrl,
    stops: crawl.stops,
    runsStarted: crawl.runsStarted,
    completions: crawl.completions,
  );
}
