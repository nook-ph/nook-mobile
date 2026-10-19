import 'package:flutter/foundation.dart';
import 'package:nook/core/analytics/log_app_event.dart';
import 'package:nook/core/analytics/saves_events.dart';
import 'package:nook/core/cafe/domain/entities/cafe_status.dart';
import 'package:nook/core/cafe/presentation/cafe_status_cubit.dart';
import 'package:nook/features/guest_saves/domain/cafe_snapshot.dart';
import 'package:nook/features/guest_saves/presentation/cubit/guest_saves_cubit.dart';

/// Moves a guest's on-phone saves to the account they just signed in to,
/// through the same [CafeStatusCubit.set] (`set_cafe_status`) the Been / Want
/// to Try pills use.
///
/// Idempotent and safe to repeat: a cafe the account already has a status
/// for is left as the account has it (the account wins; only a phone Been
/// moves an account Want to try on to Been), and only saves that
/// reached the account, or were already there, are dropped from the phone.
/// Whatever failed stays on the phone, marked with the account it was meant
/// for ([GuestSave.owner]): it moves on its own only into that account
/// again, and stays a guest save after a sign-out.
class GuestSavesMerger {
  GuestSavesMerger({required this.saves, required this.statuses});

  final GuestSavesCubit saves;
  final CafeStatusCubit statuses;

  bool _running = false;

  /// What reached account [accountId]. Moves the saves made while signed
  /// out and those a failed merge into [accountId] left; with
  /// [includeOthers], also those another account left (the person said
  /// "Add them"). Never throws: a merge that broke part way reports
  /// everything it did not finish as failed.
  Future<GuestMergeResult> merge({
    required String accountId,
    bool includeOthers = false,
  }) async {
    if (_running) return GuestMergeResult.none;
    _running = true;
    var tried = 0;
    try {
      return await _merge(
        accountId,
        includeOthers: includeOthers,
        onTried: (count) => tried = count,
      );
    } catch (e, st) {
      debugPrint('[GuestSavesMerger] merge failed: $e\n$st');
      return GuestMergeResult(added: 0, moved: 0, failed: tried);
    } finally {
      _running = false;
    }
  }

  /// The saves another account than [accountId] left on this phone,
  /// newest first: the ones [merge] moves only with `includeOthers`.
  Future<List<GuestSave>> othersFor(String accountId) async {
    await saves.load();
    return saves.state.ownedByOthers(accountId);
  }

  Future<GuestMergeResult> _merge(
    String accountId, {
    required bool includeOthers,
    required void Function(int) onTried,
  }) async {
    await saves.load();
    // Signed in: the guest overlay must not stand in for the account's own
    // statuses, or every save would look "already there".
    statuses.showLocal(const {});
    final pending = [
      for (final s in saves.state.saves)
        if (includeOthers || s.owner == null || s.owner == accountId) s,
    ];
    if (pending.isEmpty) return GuestMergeResult.none;
    onTried(pending.length);
    final ids = [for (final s in pending) s.cafeId];

    // Only this read counts: cafes "known" from reads made before sign-in
    // (as a guest, which the server answers with nothing) are not the
    // account's statuses, and writing over a Been deletes its rank and note.
    if (!await statuses.loadFor(ids)) {
      await saves.removeAll(const {}, leftFor: ids.toSet(), owner: accountId);
      logAppEvent(
        SavesEvents.guestSavesMerged,
        properties: {'count': 0, 'moved': 0, 'failed': pending.length},
      );
      return GuestMergeResult(added: 0, moved: 0, failed: pending.length);
    }

    var merged = 0;
    final done = <String>{};
    // Oldest first, so the account's lists keep the order they were saved in.
    for (final save in pending.reversed) {
      final id = save.cafeId;
      // The read failed: nothing is known, so nothing is written.
      if (!statuses.state.isKnown(id)) continue;
      final account = statuses.state.statusFor(id);
      // The account wins, except that a visit logged on the phone moves an
      // account's Want to try on to Been: Want to try has no rank or note
      // to lose, and dropping the Been would lose the visit.
      final upgrade =
          account == CafeStatus.wantToTry && save.status == CafeStatus.been;
      if (account != CafeStatus.none && !upgrade) {
        done.add(id);
        continue;
      }
      if (await statuses.set(id, save.status)) {
        merged++;
        done.add(id);
      }
    }

    await saves.removeAll(
      done,
      leftFor: ids.toSet().difference(done),
      owner: accountId,
    );
    final failed = pending.length - done.length;
    if (merged > 0 || failed > 0) {
      logAppEvent(
        SavesEvents.guestSavesMerged,
        properties: {'count': merged, 'moved': done.length, 'failed': failed},
      );
    }
    return GuestMergeResult(added: merged, moved: done.length, failed: failed);
  }

  /// On account deletion: drops the saves a merge into [accountId] left on
  /// this phone. The account and its data are gone; saves made while signed
  /// out, or left by another account, stay.
  Future<void> dropOwnedBy(String accountId) async {
    try {
      await saves.load();
      final owned = {
        for (final s in saves.state.saves)
          if (s.owner == accountId) s.cafeId,
      };
      await saves.removeAll(owned);
    } catch (e, st) {
      debugPrint('[GuestSavesMerger] drop failed: $e\n$st');
    }
  }
}

/// The outcome of one [GuestSavesMerger.merge].
class GuestMergeResult {
  const GuestMergeResult({
    required this.added,
    required this.moved,
    required this.failed,
  });

  /// Nothing was on the phone to move.
  static const none = GuestMergeResult(added: 0, moved: 0, failed: 0);

  /// Saves written to the account (it had no status for them).
  final int added;

  /// Saves now in the account and gone from the phone: [added], plus the
  /// ones the account already had (the account's status wins).
  final int moved;

  /// Saves that could not be read or written; they stay on the phone.
  final int failed;

  int get total => moved + failed;

  /// This result and [other] as one toast's worth.
  GuestMergeResult operator +(GuestMergeResult other) => GuestMergeResult(
    added: added + other.added,
    moved: moved + other.moved,
    failed: failed + other.failed,
  );

  bool get isEmpty => total == 0;
}
