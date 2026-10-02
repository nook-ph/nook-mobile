import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nook/core/analytics/analytics_service.dart';
import 'package:nook/features/crawls/domain/entities/crawl.dart';
import 'package:nook/features/crawls/domain/entities/crawl_exception.dart';
import 'package:nook/features/crawls/domain/entities/crawl_run.dart';
import 'package:nook/features/crawls/domain/use_cases/get_crawl_by_code_usecase.dart';
import 'package:nook/features/crawls/domain/use_cases/get_crawl_run_preview_usecase.dart';
import 'package:nook/features/crawls/domain/use_cases/join_crawl_run_usecase.dart';

enum CrewInviteStatus { loading, loaded, error }

class CrewInviteState extends Equatable {
  final CrewInviteStatus status;
  final CrawlRunPreview? preview;

  /// The crawl behind the invite, for its stop list. Null when the crawl is
  /// private to its crew: the preview alone still carries title and counts.
  final Crawl? crawl;

  /// Why the preview could not load, or why the last join failed.
  final Object? error;
  final bool joining;

  /// The server refused the join because the crew filled up.
  final bool crewFull;

  /// Set once when a join succeeds; the page consumes it to navigate.
  final CrawlRun? joinedRun;

  const CrewInviteState({
    this.status = CrewInviteStatus.loading,
    this.preview,
    this.crawl,
    this.error,
    this.joining = false,
    this.crewFull = false,
    this.joinedRun,
  });

  bool get isFull => crewFull || (preview?.isFull ?? false);

  CrewInviteState copyWith({
    CrewInviteStatus? status,
    CrawlRunPreview? preview,
    Crawl? crawl,
    Object? error,
    bool? joining,
    bool? crewFull,
    CrawlRun? joinedRun,
    bool clearJoinedRun = false,
  }) {
    return CrewInviteState(
      status: status ?? this.status,
      preview: preview ?? this.preview,
      crawl: crawl ?? this.crawl,
      error: error,
      joining: joining ?? this.joining,
      crewFull: crewFull ?? this.crewFull,
      joinedRun: clearJoinedRun ? null : (joinedRun ?? this.joinedRun),
    );
  }

  @override
  List<Object?> get props => [
    status,
    preview,
    crawl,
    error,
    joining,
    crewFull,
    joinedRun,
  ];
}

/// A crew invite, from landing on it to being in the run.
class CrewInviteCubit extends Cubit<CrewInviteState> {
  CrewInviteCubit({
    required this.getCrawlRunPreviewUseCase,
    required this.getCrawlByCodeUseCase,
    required this.joinCrawlRunUseCase,
    required this.analytics,
  }) : super(const CrewInviteState());

  final GetCrawlRunPreviewUseCase getCrawlRunPreviewUseCase;
  final GetCrawlByCodeUseCase getCrawlByCodeUseCase;
  final JoinCrawlRunUseCase joinCrawlRunUseCase;
  final AnalyticsService analytics;

  Future<void> load(String inviteCode) async {
    emit(const CrewInviteState());
    try {
      final preview = await getCrawlRunPreviewUseCase(inviteCode);
      if (isClosed) return;
      emit(state.copyWith(status: CrewInviteStatus.loaded, preview: preview));
      await _loadStops(preview.shareCode);
    } catch (e, st) {
      debugPrint('[CrewInvite] load($inviteCode) failed: $e\n$st');
      if (isClosed) return;
      emit(state.copyWith(status: CrewInviteStatus.error, error: e));
    }
  }

  /// The stop list is a nicety: a private crawl is unreadable until the
  /// caller has joined, and the invite still works without it.
  Future<void> _loadStops(String shareCode) async {
    try {
      final crawl = await getCrawlByCodeUseCase(shareCode);
      if (isClosed) return;
      emit(state.copyWith(crawl: crawl));
    } catch (e) {
      debugPrint('[CrewInvite] stops($shareCode) unavailable: $e');
    }
  }

  Future<void> join(String inviteCode) async {
    final preview = state.preview;
    if (preview == null || state.joining) return;
    emit(state.copyWith(joining: true));
    try {
      final run = await joinCrawlRunUseCase(inviteCode);
      analytics.logEvent(
        'crew_joined',
        properties: {
          'stop_count': run.crawl.stops.length,
          'crew_size': run.members.length,
        },
      );
      if (isClosed) return;
      emit(state.copyWith(joining: false, joinedRun: run));
    } on CrewFull {
      if (isClosed) return;
      emit(state.copyWith(joining: false, crewFull: true));
    } on CrawlNotFound catch (e) {
      if (isClosed) return;
      // The run went away between the preview and the tap.
      emit(
        state.copyWith(
          joining: false,
          status: CrewInviteStatus.error,
          error: e,
        ),
      );
    } catch (e, st) {
      debugPrint('[CrewInvite] join($inviteCode) failed: $e\n$st');
      if (isClosed) return;
      emit(state.copyWith(joining: false, error: e));
    }
  }

  void consumeJoinedRun() => emit(state.copyWith(clearJoinedRun: true));
}
