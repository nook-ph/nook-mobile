import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nook/features/crawls/domain/entities/crawl_run.dart';
import 'package:nook/features/crawls/domain/use_cases/get_my_crawls_usecase.dart';

enum MyCrawlsStatus { initial, loading, loaded, error }

class MyCrawlsState extends Equatable {
  final MyCrawlsStatus status;
  final MyCrawls crawls;
  final Object? error;

  const MyCrawlsState({
    this.status = MyCrawlsStatus.initial,
    this.crawls = const MyCrawls(),
    this.error,
  });

  MyCrawlsState copyWith({
    MyCrawlsStatus? status,
    MyCrawls? crawls,
    Object? error,
  }) {
    return MyCrawlsState(
      status: status ?? this.status,
      crawls: crawls ?? this.crawls,
      error: error,
    );
  }

  @override
  List<Object?> get props => [status, crawls, error];
}

/// The Crawls section on the Lists tab: runs the user is in and crawls they
/// made. App-wide singleton so a stamp or a new crawl shows up on return.
class MyCrawlsCubit extends Cubit<MyCrawlsState> {
  MyCrawlsCubit({required this.getMyCrawlsUseCase})
    : super(const MyCrawlsState());

  final GetMyCrawlsUseCase getMyCrawlsUseCase;

  /// Keeps whatever is on screen while reloading, so returning from a run
  /// refreshes progress without a spinner flash.
  Future<void> load() async {
    if (state.status == MyCrawlsStatus.loading) return;
    if (state.status == MyCrawlsStatus.initial) {
      emit(state.copyWith(status: MyCrawlsStatus.loading));
    }
    try {
      final crawls = await getMyCrawlsUseCase();
      emit(MyCrawlsState(status: MyCrawlsStatus.loaded, crawls: crawls));
    } catch (e, st) {
      debugPrint('[MyCrawls] load failed: $e\n$st');
      emit(state.copyWith(status: MyCrawlsStatus.error, error: e));
    }
  }

  /// Drops cached crawls (e.g. on sign-out).
  void reset() => emit(const MyCrawlsState());
}
