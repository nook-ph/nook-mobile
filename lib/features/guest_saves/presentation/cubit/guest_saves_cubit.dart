import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nook/core/analytics/log_app_event.dart';
import 'package:nook/core/analytics/saves_events.dart';
import 'package:nook/core/cafe/domain/entities/cafe_status.dart';
import 'package:nook/features/guest_saves/data/guest_saves_store.dart';
import 'package:nook/features/guest_saves/domain/cafe_snapshot.dart';

/// A guest's Want to Try / Been, kept on this phone so browsing without an
/// account still leaves something behind. App-wide (like `CafeStatusCubit`);
/// `GuestSavesSync` mirrors it into the status badges and moves it to the
/// account on sign-in.
class GuestSavesCubit extends Cubit<GuestSavesState> {
  GuestSavesCubit({required GuestSavesStore store, DateTime Function()? now})
    : _store = store,
      _now = now ?? DateTime.now,
      super(const GuestSavesState());

  final GuestSavesStore _store;
  final DateTime Function() _now;
  Future<void>? _loading;

  /// Whether the last read of the phone's storage failed. The saves are then
  /// unknown rather than empty, so nothing is written over them.
  bool _readFailed = false;

  /// Reads the saves once; later calls wait for the same read. A failed read
  /// is not kept: the next call tries again.
  Future<void> load() => _loading ??= _load();

  Future<void> _load() async {
    final List<GuestSave> saves;
    try {
      saves = await _store.read();
    } catch (e) {
      debugPrint('[GuestSaves] load failed: $e');
      _readFailed = true;
      _loading = null;
      if (!isClosed) emit(state.copyWith(loaded: true));
      return;
    }
    _readFailed = false;
    if (isClosed) return;
    emit(GuestSavesState(saves: saves, loaded: true));
  }

  /// Sets [cafe]'s on-phone status; [CafeStatus.none] removes it. Null when
  /// the phone could not store it (the state is then left as it was).
  Future<GuestSaveOutcome?> set(CafeSnapshot cafe, CafeStatus status) async {
    await load();
    // Writing now would replace saves that are there but could not be read.
    if (_readFailed) return null;
    final before = state;
    final previous = before.statusFor(cafe.id);
    if (previous == status) {
      return GuestSaveOutcome(previous: previous, firstSave: false);
    }

    final rest = before.saves.where((s) => s.cafeId != cafe.id);
    final saves = status == CafeStatus.none
        ? rest.toList()
        : [GuestSave(cafe: cafe, status: status, savedAt: _now()), ...rest];
    emit(before.copyWith(saves: saves));
    try {
      await _store.write(saves);
    } catch (e) {
      debugPrint('[GuestSaves] write failed: $e');
      if (!isClosed) emit(before);
      return null;
    }

    if (status == CafeStatus.none) {
      return GuestSaveOutcome(previous: previous, firstSave: false);
    }
    logAppEvent(
      SavesEvents.guestSaveCreated,
      properties: {'status': status.wire},
    );
    final first = await recordFirstSave(_store, status, guest: true);
    return GuestSaveOutcome(previous: previous, firstSave: first);
  }

  /// Drops the saves for [cafeIds] (they reached the account).
  Future<void> removeAll(Set<String> cafeIds) async {
    if (cafeIds.isEmpty) return;
    await load();
    if (_readFailed) return;
    final saves = state.saves
        .where((s) => !cafeIds.contains(s.cafeId))
        .toList();
    if (saves.length == state.saves.length) return;
    emit(state.copyWith(saves: saves));
    try {
      await _store.write(saves);
    } catch (e) {
      // Left on disk: the next launch merges them again, which skips cafes
      // the account already has.
      debugPrint('[GuestSaves] removeAll write failed: $e');
    }
  }

  /// True once per phone: whether to show "Saved on this phone. Sign in to
  /// keep it everywhere."
  Future<bool> claimKeepSavesPrompt() async {
    try {
      return await _store.claimKeepSavesPrompt();
    } catch (_) {
      return false;
    }
  }
}

/// Logs `first_save` the first time anyone saves a cafe on this phone.
/// Returns whether this was that first time.
Future<bool> recordFirstSave(
  GuestSavesStore store,
  CafeStatus status, {
  required bool guest,
}) async {
  if (status == CafeStatus.none) return false;
  bool first;
  try {
    first = await store.claimFirstSave();
  } catch (_) {
    return false;
  }
  if (first) {
    logAppEvent(
      SavesEvents.firstSave,
      properties: {'status': status.wire, 'guest': guest},
    );
  }
  return first;
}

class GuestSaveOutcome {
  const GuestSaveOutcome({required this.previous, required this.firstSave});

  /// The status the cafe had before, for Undo.
  final CafeStatus previous;

  /// The first save ever made on this phone.
  final bool firstSave;
}

class GuestSavesState extends Equatable {
  const GuestSavesState({this.saves = const [], this.loaded = false});

  /// Newest first.
  final List<GuestSave> saves;

  /// The saves have been read from the phone.
  final bool loaded;

  bool get isEmpty => saves.isEmpty;

  CafeStatus statusFor(String cafeId) {
    for (final s in saves) {
      if (s.cafeId == cafeId) return s.status;
    }
    return CafeStatus.none;
  }

  List<GuestSave> withStatus(CafeStatus status) =>
      saves.where((s) => s.status == status).toList();

  Map<String, CafeStatus> get statusMap => {
    for (final s in saves) s.cafeId: s.status,
  };

  GuestSavesState copyWith({List<GuestSave>? saves, bool? loaded}) =>
      GuestSavesState(
        saves: saves ?? this.saves,
        loaded: loaded ?? this.loaded,
      );

  @override
  List<Object?> get props => [saves, loaded];
}
