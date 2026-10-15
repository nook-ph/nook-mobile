import 'package:shared_preferences/shared_preferences.dart';

/// Which Home banners this phone has closed, by
/// [HomeBanner.dismissKey] (layout version + title). Kept to the latest
/// [_keep] so the list cannot grow without end.
class HomeBannerDismissStore {
  HomeBannerDismissStore({Future<SharedPreferences> Function()? prefs})
    : _prefs = prefs ?? SharedPreferences.getInstance;

  static const _key = 'homeBannerDismissed';
  static const _keep = 20;
  final Future<SharedPreferences> Function() _prefs;

  Future<Set<String>> read() async {
    try {
      return ((await _prefs()).getStringList(_key) ?? const []).toSet();
    } catch (_) {
      return {};
    }
  }

  Future<void> dismiss(String key) async {
    try {
      final prefs = await _prefs();
      final keys = [...?prefs.getStringList(_key)]
        ..remove(key)
        ..add(key);
      final kept = keys.length > _keep
          ? keys.sublist(keys.length - _keep)
          : keys;
      await prefs.setStringList(_key, kept);
    } catch (_) {
      // Not remembered: the banner shows again next launch.
    }
  }
}
