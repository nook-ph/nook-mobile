import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nook/features/guest_saves/data/guest_saves_store.dart';
import 'package:nook/features/guest_saves/domain/cafe_snapshot.dart';

/// The cafe pages last opened on this phone, newest first, for Home's "Your
/// places" row. App-wide, for guests and signed-in users alike.
class RecentlyViewedCubit extends Cubit<List<RecentlyViewedCafe>> {
  RecentlyViewedCubit({
    required RecentlyViewedStore store,
    DateTime Function()? now,
  }) : _store = store,
       _now = now ?? DateTime.now,
       super(const []);

  final RecentlyViewedStore _store;
  final DateTime Function() _now;
  Future<void>? _loading;

  Future<void> load() => _loading ??= _load();

  Future<void> _load() async {
    final entries = await _store.read();
    if (isClosed) return;
    // A view recorded while the read was in flight stays first.
    final ids = state.map((e) => e.cafe.id).toSet();
    emit(
      [
        ...state,
        ...entries.where((e) => !ids.contains(e.cafe.id)),
      ].take(RecentlyViewedStore.maxEntries).toList(),
    );
  }

  /// Moves [cafe] to the front, refreshing what is kept about it.
  Future<void> record(CafeSnapshot cafe) async {
    if (cafe.id.isEmpty) return;
    await load();
    if (isClosed) return;
    final next = [
      RecentlyViewedCafe(cafe: cafe, viewedAt: _now()),
      ...state.where((e) => e.cafe.id != cafe.id),
    ].take(RecentlyViewedStore.maxEntries).toList();
    emit(next);
    try {
      await _store.write(next);
    } catch (e) {
      debugPrint('[RecentlyViewed] write failed: $e');
    }
  }

  /// Sign-out: what one person looked at is not shown to the next.
  Future<void> clear() async {
    emit(const []);
    try {
      await _store.write(const []);
    } catch (e) {
      debugPrint('[RecentlyViewed] clear failed: $e');
    }
  }
}
