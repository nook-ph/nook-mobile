import 'package:shared_preferences/shared_preferences.dart';

/// Tracks whether the first-time location permission prompt has been shown
/// on the map page. Once set, the auto-prompt will not run again — the user
/// can still trigger it manually via the "my location" FAB.
class LocationPromptStore {
  static const _key = 'hasRequestedLocationOnMap';

  Future<bool> hasRequested() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_key) ?? false;
  }

  Future<void> markRequested() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, true);
  }
}
