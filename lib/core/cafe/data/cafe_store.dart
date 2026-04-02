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

  void bust(String id) {
    _bundles.remove(id);
    _writtenAt.remove(id);
  }

  void bustAll() {
    _bundles.clear();
    _writtenAt.clear();
  }

  bool isStale(String id) {
    final writtenAt = _writtenAt[id];
    if (writtenAt == null) return true;
    return DateTime.now().difference(writtenAt) > _ttl;
  }
}
