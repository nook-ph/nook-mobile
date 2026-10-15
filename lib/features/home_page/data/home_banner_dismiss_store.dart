import 'package:shared_preferences/shared_preferences.dart';

/// Which Home banners this phone has closed, and which it has opened, by
/// [HomeBanner.dismissKey] (layout version + title). Each list keeps the
/// latest [_keep] so it cannot grow without end.
class HomeBannerDismissStore {
  HomeBannerDismissStore({Future<SharedPreferences> Function()? prefs})
    : _prefs = prefs ?? SharedPreferences.getInstance;

  static const _key = 'homeBannerDismissed';
  static const _tappedKey = 'homeBannerTapped';
  static const _keep = 20;
  final Future<SharedPreferences> Function() _prefs;

  /// Closed banners.
  Future<Set<String>> read() => _read(_key);

  /// Banners already opened once; Home shows them as a one-line strip.
  Future<Set<String>> tapped() => _read(_tappedKey);

  Future<void> dismiss(String key) => _add(_key, key);

  /// Undo of [dismiss].
  Future<void> undismiss(String key) => _remove(_key, key);

  Future<void> markTapped(String key) => _add(_tappedKey, key);

  Future<Set<String>> _read(String list) async {
    try {
      return ((await _prefs()).getStringList(list) ?? const []).toSet();
    } catch (_) {
      return {};
    }
  }

  Future<void> _add(String list, String key) async {
    try {
      final prefs = await _prefs();
      final keys = [...?prefs.getStringList(list)]
        ..remove(key)
        ..add(key);
      final kept = keys.length > _keep
          ? keys.sublist(keys.length - _keep)
          : keys;
      await prefs.setStringList(list, kept);
    } catch (_) {
      // Not remembered: the banner shows in full again next launch.
    }
  }

  Future<void> _remove(String list, String key) async {
    try {
      final prefs = await _prefs();
      final keys = [...?prefs.getStringList(list)]..remove(key);
      await prefs.setStringList(list, keys);
    } catch (_) {}
  }
}
