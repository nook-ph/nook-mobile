import 'package:flutter/foundation.dart';
import 'package:nook/core/cafe/domain/entities/cafe_bundle.dart';

class CafeStore {
  static const Duration _ttl = Duration(minutes: 5);

  final Map<String, CafeBundle> _bundles = <String, CafeBundle>{};
  final Map<String, DateTime> _writtenAt = <String, DateTime>{};

  CafeBundle? get(String id) {
    if (isStale(id)) return null;
    return _bundles[id];
  }

  void set(String id, CafeBundle bundle) {
    _bundles[id] = bundle;
    _writtenAt[id] = DateTime.now();
  }

  /// Swaps a live entry's bundle without renewing its TTL. No-op when the
  /// entry is missing or already stale.
  void replace(String id, CafeBundle bundle) {
    if (isStale(id)) return;
    _bundles[id] = bundle;
  }

  void bust(String id) {
    _bundles.remove(id);
    _writtenAt.remove(id);
  }

  void bustAll() {
    _bundles.clear();
    _writtenAt.clear();
  }

  @visibleForTesting
  DateTime? writtenAt(String id) => _writtenAt[id];

  bool isStale(String id) {
    final writtenAt = _writtenAt[id];
    if (writtenAt == null) return true;
    return DateTime.now().difference(writtenAt) > _ttl;
  }
}
