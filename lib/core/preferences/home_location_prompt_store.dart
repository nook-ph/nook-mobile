import 'package:shared_preferences/shared_preferences.dart';

/// What decides whether Home offers "See cafes near you": how many launches
/// have shown Home, whether a cafe has been opened, and whether the offer
/// was turned down. The system prompt itself is tracked by
/// `LocationPromptStore`, shared with Map and Search.
class HomeLocationPromptStore {
  static const _visitsKey = 'homeVisitCount';
  static const _cafeViewedKey = 'homeLocationPromptCafeViewed';
  static const _dismissedKey = 'homeLocationPromptDismissed';

  bool _countedThisLaunch = false;

  /// Counts this launch as a Home visit, once per instance (the app keeps
  /// one for its lifetime), and returns the total.
  Future<int> recordHomeVisit() async {
    final prefs = await SharedPreferences.getInstance();
    final visits = prefs.getInt(_visitsKey) ?? 0;
    if (_countedThisLaunch) return visits;
    _countedThisLaunch = true;
    await prefs.setInt(_visitsKey, visits + 1);
    return visits + 1;
  }

  Future<bool> hasViewedCafe() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_cafeViewedKey) ?? false;
  }

  Future<void> markCafeViewed() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_cafeViewedKey, true);
  }

  Future<bool> isDismissed() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_dismissedKey) ?? false;
  }

  Future<void> markDismissed() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_dismissedKey, true);
  }
}
