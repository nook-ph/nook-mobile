import 'package:flutter/foundation.dart';
import 'package:nook/core/analytics/log_app_event.dart';
import 'package:nook/core/analytics/saves_events.dart';
import 'package:nook/core/cafe/domain/entities/cafe_status.dart';
import 'package:nook/core/cafe/presentation/cafe_status_cubit.dart';
import 'package:nook/features/guest_saves/presentation/cubit/guest_saves_cubit.dart';

/// Moves a guest's on-phone saves to the account they just signed in to,
/// through the same [CafeStatusCubit.set] (`set_cafe_status`) the Been / Want
/// to Try pills use.
///
/// Idempotent and safe to repeat: a cafe the account already has any status
/// for is left as the account has it (the account wins), and only saves that
/// reached the account, or were already there, are dropped from the phone.
/// Whatever failed stays on the phone for the next launch.
class GuestSavesMerger {
  GuestSavesMerger({required this.saves, required this.statuses});

  final GuestSavesCubit saves;
  final CafeStatusCubit statuses;

  bool _running = false;

  /// A merge into the signed-in account has been tried with saves on the
  /// phone. Whatever is left belongs to that account's owner from then on.
  bool _attempted = false;

  /// On an explicit sign-out (or account deletion): drops saves left over
  /// from a merge that did not finish, so they are neither shown as the next
  /// guest's nor merged into whichever account signs in next on this phone.
  /// Saves no merge was tried for (a guest who backed out of sign-in before
  /// reaching an account) are kept.
  Future<void> discardLeftovers() async {
    if (!_attempted) return;
    _attempted = false;
    try {
      await saves.load();
      final left = {for (final s in saves.state.saves) s.cafeId};
      await saves.removeAll(left);
    } catch (e, st) {
      debugPrint('[GuestSavesMerger] discard failed: $e\n$st');
    }
  }

  /// What reached the account. Never throws: a merge that broke part way
  /// reports everything it did not finish as failed.
  Future<GuestMergeResult> merge() async {
    if (_running) return GuestMergeResult.none;
    _running = true;
    var tried = 0;
    try {
      return await _merge(onTried: (count) => tried = count);
    } catch (e, st) {
      debugPrint('[GuestSavesMerger] merge failed: $e\n$st');
      return GuestMergeResult(added: 0, moved: 0, failed: tried);
    } finally {
      _running = false;
    }
  }

  Future<GuestMergeResult> _merge({required void Function(int) onTried}) async {
    await saves.load();
    // Signed in: the guest overlay must not stand in for the account's own
    // statuses, or every save would look "already there".
    statuses.showLocal(const {});
    final pending = saves.state.saves;
    if (pending.isEmpty) return GuestMergeResult.none;
    _attempted = true;
    onTried(pending.length);

    final ids = [for (final s in pending) s.cafeId];
    // Only this read counts: cafes "known" from reads made before sign-in
    // (as a guest, which the server answers with nothing) are not the
    // account's statuses, and writing over a Been deletes its rank and note.
    if (!await statuses.loadFor(ids)) {
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
      if (statuses.state.statusFor(id) != CafeStatus.none) {
        done.add(id);
        continue;
      }
      if (await statuses.set(id, save.status)) {
        merged++;
        done.add(id);
      }
    }

    await saves.removeAll(done);
    final failed = pending.length - done.length;
    if (merged > 0 || failed > 0) {
      logAppEvent(
        SavesEvents.guestSavesMerged,
        properties: {'count': merged, 'moved': done.length, 'failed': failed},
      );
    }
    return GuestMergeResult(added: merged, moved: done.length, failed: failed);
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

  bool get isEmpty => total == 0;
}
