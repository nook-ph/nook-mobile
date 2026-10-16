import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nook/core/cafe/domain/entities/cafe_status.dart';
import 'package:nook/core/cafe/domain/use_cases/get_cafe_statuses_usecase.dart';
import 'package:nook/core/cafe/domain/use_cases/set_cafe_status_usecase.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// App-wide Been / Want to Try statuses keyed by cafe id, so a status set on
/// the details page is instantly reflected on any other surface.
/// Registered as a singleton (like ListsBloc).
class CafeStatusCubit extends Cubit<CafeStatusState> {
  CafeStatusCubit({
    required this.getCafeStatusesUseCase,
    required this.setCafeStatusUseCase,
    bool Function()? hasSession,
  }) : _hasSession = hasSession ?? _supabaseSession,
       super(const CafeStatusState());

  final GetCafeStatusesUseCase getCafeStatusesUseCase;
  final SetCafeStatusUseCase setCafeStatusUseCase;
  final bool Function() _hasSession;

  static bool _supabaseSession() {
    try {
      return Supabase.instance.client.auth.currentSession != null;
    } catch (_) {
      // No Supabase (unit tests): behave as signed in.
      return true;
    }
  }

  /// Fetches current statuses for [cafeIds] and merges them into the cache.
  /// Cafes absent from the response are reset to [CafeStatus.none].
  /// Returns whether the read succeeded: a failed one leaves the cache as
  /// it was, including cafes [CafeStatusState.isKnown] from earlier reads.
  ///
  /// Without a session nothing is read: the server answers a signed-out
  /// read with no rows, and caching that as "known: none" would outlive
  /// the sign-in, so a later write could go over the account's real status
  /// (leaving Been deletes its rank and note).
  Future<bool> loadFor(List<String> cafeIds) async {
    if (cafeIds.isEmpty) return true;
    if (!_hasSession()) return false;
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
      emit(
        state.copyWith(statuses: statuses, known: {...state.known, ...cafeIds}),
      );
      return true;
    } catch (e, st) {
      // Badges silently stay unknown; the write path surfaces its own errors.
      debugPrint('[CafeStatus] loadFor failed: $e\n$st');
      return false;
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
      _emitStatus(cafeId, status, pending: false, confirmed: true);
      return true;
    } catch (e, st) {
      debugPrint('[CafeStatus] set($cafeId, ${status.wire}) failed: $e\n$st');
      _emitStatus(cafeId, previous, pending: false);
      return false;
    }
  }

  /// Drops all cached statuses (e.g. on sign-out).
  void reset() => emit(const CafeStatusState());

  /// Statuses a guest keeps on this phone (see `GuestSavesCubit`), shown
  /// wherever a server status would be. Replaces the previous set; an empty
  /// map clears it. They never count as [CafeStatusState.isKnown] and are
  /// never written to the server from here.
  void showLocal(Map<String, CafeStatus> statuses) {
    if (mapEquals(statuses, state.local)) return;
    emit(state.copyWith(local: Map.unmodifiable(statuses)));
  }

  void _emitStatus(
    String cafeId,
    CafeStatus status, {
    required bool pending,
    bool confirmed = false,
  }) {
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
    emit(
      state.copyWith(
        statuses: statuses,
        pending: pendingIds,
        known: confirmed ? {...state.known, cafeId} : null,
      ),
    );
  }
}

class CafeStatusState extends Equatable {
  const CafeStatusState({
    this.statuses = const {},
    this.pending = const {},
    this.known = const {},
    this.local = const {},
  });

  /// Cafes with a status; absent means none (or not yet loaded).
  final Map<String, CafeStatus> statuses;

  /// Cafe ids with an in-flight write.
  final Set<String> pending;

  /// Cafe ids whose status the server has confirmed, by a read or a write.
  /// Tells "none" apart from "the read failed", which [statuses] cannot.
  final Set<String> known;

  /// A guest's on-phone statuses, read when the server has none for a cafe
  /// (a guest has no server statuses at all).
  final Map<String, CafeStatus> local;

  CafeStatus statusFor(String cafeId) =>
      statuses[cafeId] ?? local[cafeId] ?? CafeStatus.none;

  /// The account's own status, ignoring the guest overlay in [local]. For
  /// surfaces whose actions need an account (ranking, the private note,
  /// adding a cup): a guest's on-phone Been must not offer them.
  CafeStatus serverStatusFor(String cafeId) =>
      statuses[cafeId] ?? CafeStatus.none;

  bool isPending(String cafeId) => pending.contains(cafeId);

  /// Whether [statusFor] is the server's answer rather than a default. A
  /// write that depends on the current status (leaving Been deletes the rank
  /// and note) must not go ahead on a guess.
  bool isKnown(String cafeId) => known.contains(cafeId);

  CafeStatusState copyWith({
    Map<String, CafeStatus>? statuses,
    Set<String>? pending,
    Set<String>? known,
    Map<String, CafeStatus>? local,
  }) {
    return CafeStatusState(
      statuses: statuses ?? this.statuses,
      pending: pending ?? this.pending,
      known: known ?? this.known,
      local: local ?? this.local,
    );
  }

  @override
  List<Object?> get props => [statuses, pending, known, local];
}
