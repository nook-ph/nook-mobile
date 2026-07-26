import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nook/core/cafe/domain/entities/cafe_status.dart';
import 'package:nook/core/cafe/domain/use_cases/get_cafe_statuses_usecase.dart';
import 'package:nook/core/cafe/domain/use_cases/set_cafe_status_usecase.dart';

/// App-wide Been / Want to Try statuses keyed by cafe id, so a status set on
/// the details page is instantly reflected on any other surface.
/// Registered as a singleton (like ListsBloc).
class CafeStatusCubit extends Cubit<CafeStatusState> {
  CafeStatusCubit({
    required this.getCafeStatusesUseCase,
    required this.setCafeStatusUseCase,
  }) : super(const CafeStatusState());

  final GetCafeStatusesUseCase getCafeStatusesUseCase;
  final SetCafeStatusUseCase setCafeStatusUseCase;

  /// Fetches current statuses for [cafeIds] and merges them into the cache.
  /// Cafes absent from the response are reset to [CafeStatus.none].
  Future<void> loadFor(List<String> cafeIds) async {
    if (cafeIds.isEmpty) return;
    try {
      final fetched = await getCafeStatusesUseCase(cafeIds);
      final statuses = Map<String, CafeStatus>.from(state.statuses);
      for (final id in cafeIds) {
        final status = fetched[id] ?? CafeStatus.none;
        if (status == CafeStatus.none) {
          statuses.remove(id);
        } else {
          statuses[id] = status;
        }
      }
      emit(state.copyWith(statuses: statuses));
    } catch (e, st) {
      // Badges silently stay unknown; the write path surfaces its own errors.
      debugPrint('[CafeStatus] loadFor failed: $e\n$st');
    }
  }

  /// Optimistically sets [status] for [cafeId]; rolls back on failure.
  /// Returns true on success so callers can toast / refresh lists.
  Future<bool> set(String cafeId, CafeStatus status) async {
    if (state.pending.contains(cafeId)) return false;

    final previous = state.statusFor(cafeId);
    if (previous == status) return true;

    _emitStatus(cafeId, status, pending: true);
    try {
      await setCafeStatusUseCase(cafeId, status);
      _emitStatus(cafeId, status, pending: false);
      return true;
    } catch (e, st) {
      debugPrint('[CafeStatus] set($cafeId, ${status.wire}) failed: $e\n$st');
      _emitStatus(cafeId, previous, pending: false);
      return false;
    }
  }

  /// Drops all cached statuses (e.g. on sign-out).
  void reset() => emit(const CafeStatusState());

  void _emitStatus(String cafeId, CafeStatus status, {required bool pending}) {
    final statuses = Map<String, CafeStatus>.from(state.statuses);
    if (status == CafeStatus.none) {
      statuses.remove(cafeId);
    } else {
      statuses[cafeId] = status;
    }
    final pendingIds = Set<String>.from(state.pending);
    if (pending) {
      pendingIds.add(cafeId);
    } else {
      pendingIds.remove(cafeId);
    }
    emit(state.copyWith(statuses: statuses, pending: pendingIds));
  }
}

class CafeStatusState extends Equatable {
  const CafeStatusState({this.statuses = const {}, this.pending = const {}});

  /// Cafes with a status; absent means none (or not yet loaded).
  final Map<String, CafeStatus> statuses;

  /// Cafe ids with an in-flight write.
  final Set<String> pending;

  CafeStatus statusFor(String cafeId) => statuses[cafeId] ?? CafeStatus.none;

  bool isPending(String cafeId) => pending.contains(cafeId);

  CafeStatusState copyWith({
    Map<String, CafeStatus>? statuses,
    Set<String>? pending,
  }) {
    return CafeStatusState(
      statuses: statuses ?? this.statuses,
      pending: pending ?? this.pending,
    );
  }

  @override
  List<Object?> get props => [statuses, pending];
}
