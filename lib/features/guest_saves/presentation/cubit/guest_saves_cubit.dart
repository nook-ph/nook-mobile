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

  /// [_readFailed], for readers that must not show "no saves" either.
  bool get readFailed => _readFailed;

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
  /// [source] is a [SavesSource] value for the `guest_save_created` and
  /// `guest_save_removed` events.
  Future<GuestSaveOutcome?> set(
    CafeSnapshot cafe,
    CafeStatus status, {
    String? source,
  }) async {
    await load();
    // Writing now would replace saves that are there but could not be read.
    if (_readFailed) return null;
    final before = state;
    final previous = before.statusFor(cafe.id);
    final index = before.saves.indexWhere((s) => s.cafeId == cafe.id);
    final previousSave = index < 0 ? null : before.saves[index];
    if (previous == status) {
      return GuestSaveOutcome(
        previous: previous,
        firstSave: false,
        previousSave: previousSave,
        previousIndex: index,
      );
    }

    final rest = before.saves.where((s) => s.cafeId != cafe.id);
    final saves = status == CafeStatus.none
        ? rest.toList()
        : [
            // A changed save keeps its owner: it is still the one a merge
            // left on this phone.
            GuestSave(
              cafe: cafe,
              status: status,
              savedAt: _now(),
              owner: previousSave?.owner,
            ),
            ...rest,
          ];
    emit(before.copyWith(saves: saves));
    try {
      await _store.write(saves);
    } catch (e) {
      debugPrint('[GuestSaves] write failed: $e');
      if (!isClosed) emit(before);
      return null;
    }

    if (status == CafeStatus.none) {
      logAppEvent(
        SavesEvents.guestSaveRemoved,
        properties: {'source': ?source},
      );
      return GuestSaveOutcome(
        previous: previous,
        firstSave: false,
        previousSave: previousSave,
        previousIndex: index,
      );
    }
    logAppEvent(
      SavesEvents.guestSaveCreated,
      properties: {'status': status.wire, 'source': ?source},
    );
    final first = await recordFirstSave(_store, status, guest: true);
    return GuestSaveOutcome(
      previous: previous,
      firstSave: first,
      previousSave: previousSave,
      previousIndex: index,
    );
  }

  /// Undoes the [set] that returned [outcome] for [cafeId]: the save it
  /// replaced comes back as it was (status, saved time, place in the list),
  /// or a new save is taken off again. Restoring is not a new save, so it
  /// logs no `guest_save_created`; taking a new save off logs
  /// `guest_save_removed` with [SavesSource.undo]. False when the phone
  /// could not store it.
  Future<bool> undo(String cafeId, GuestSaveOutcome outcome) async {
    await load();
    if (_readFailed) return false;
    final before = state;
    final saves = [...before.saves.where((s) => s.cafeId != cafeId)];
    final restored = outcome.previousSave;
    if (restored != null) {
      saves.insert(outcome.previousIndex.clamp(0, saves.length), restored);
    }
    if (listEquals(saves, before.saves)) return true;
    emit(before.copyWith(saves: saves));
    try {
      await _store.write(saves);
    } catch (e) {
      debugPrint('[GuestSaves] undo write failed: $e');
      if (!isClosed) emit(before);
      return false;
    }
    if (restored == null) {
      logAppEvent(
        SavesEvents.guestSaveRemoved,
        properties: {'source': SavesSource.undo},
      );
    }
    return true;
  }

  /// Drops the saves in [moved] (they reached the account), and marks the
  /// saves in [left] as left by a merge into account [owner], so they move
  /// on their own only into that account. One write.
  ///
  /// Matched as they were read, not by cafe: a save changed or made again
  /// while a merge ran (after a sign-out, say) is a new save, and is
  /// neither dropped nor marked.
  Future<void> settle(
    Set<GuestSave> moved, {
    Set<GuestSave> left = const {},
    String? owner,
  }) async {
    if (moved.isEmpty && (left.isEmpty || owner == null)) return;
    await load();
    if (_readFailed) return;
    final saves = [
      for (final s in state.saves)
        if (!moved.contains(s))
          owner != null && left.contains(s) ? s.withOwner(owner) : s,
    ];
    if (listEquals(saves, state.saves)) return;
    emit(state.copyWith(saves: saves));
    try {
      await _store.write(saves);
    } catch (e) {
      // Left on disk: the next launch merges them again, which skips cafes
      // the account already has.
      debugPrint('[GuestSaves] settle write failed: $e');
    }
  }

  /// The account last asked whether to add saves another account left
  /// ([GuestSavesStore.mergeAskedFor]); null when unknown.
  Future<String?> mergeAskedFor() async {
    try {
      return await _store.mergeAskedFor();
    } catch (_) {
      return null;
    }
  }

  /// Records that [accountId] was asked; null clears it.
  Future<void> setMergeAskedFor(String? accountId) async {
    try {
      await _store.setMergeAskedFor(accountId);
    } catch (e) {
      debugPrint('[GuestSaves] merge ask marker write failed: $e');
    }
  }

  /// True once per phone: whether to show "Saved on this phone. Sign in any
  /// time to keep it."
  Future<bool> claimFirstSaveLine() async {
    try {
      return await _store.claimFirstSaveLine();
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
  const GuestSaveOutcome({
    required this.previous,
    required this.firstSave,
    this.previousSave,
    this.previousIndex = -1,
  });

  /// The status the cafe had before, for Undo.
  final CafeStatus previous;

  /// The save this one replaced or removed, as it was, for
  /// [GuestSavesCubit.undo]; null when the cafe had none.
  final GuestSave? previousSave;

  /// Where [previousSave] stood in the list (newest first).
  final int previousIndex;

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

  /// Saves a merge into another account than [accountId] left on this
  /// phone: they are not moved into [accountId] without asking.
  List<GuestSave> ownedByOthers(String accountId) => [
    for (final s in saves)
      if (s.owner != null && s.owner != accountId) s,
  ];

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
