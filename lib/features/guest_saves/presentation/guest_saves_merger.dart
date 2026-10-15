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

  /// The number of saves added to the account. Never throws.
  Future<int> merge() async {
    if (_running) return 0;
    _running = true;
    try {
      return await _merge();
    } catch (e, st) {
      debugPrint('[GuestSavesMerger] merge failed: $e\n$st');
      return 0;
    } finally {
      _running = false;
    }
  }

  Future<int> _merge() async {
    await saves.load();
    // Signed in: the guest overlay must not stand in for the account's own
    // statuses, or every save would look "already there".
    statuses.showLocal(const {});
    final pending = saves.state.saves;
    if (pending.isEmpty) return 0;

    final ids = [for (final s in pending) s.cafeId];
    await statuses.loadFor(ids);

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
    if (merged > 0) {
      logAppEvent(SavesEvents.guestSavesMerged, properties: {'count': merged});
    }
    return merged;
  }
}
