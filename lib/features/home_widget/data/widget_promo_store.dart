import 'package:nook/features/home_widget/domain/widget_promo_rules.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The "Add widget" card's history on this phone (not per account: the
/// home screen belongs to the phone).
class WidgetPromoStore {
  static const _shownCount = 'widget_promo_shown_count';
  static const _lastShown = 'widget_promo_last_shown_ms';
  static const _noNotifications = 'widget_promo_no_notifications_shown';
  static const _added = 'widget_promo_added';
  static const _installed = 'widget_installed_count_seen';

  Future<WidgetPromoHistory> read() async {
    final prefs = await SharedPreferences.getInstance();
    final last = prefs.getInt(_lastShown);
    return WidgetPromoHistory(
      shownCount: prefs.getInt(_shownCount) ?? 0,
      lastShownAt: last == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(last, isUtc: true),
      noNotificationsShown: prefs.getBool(_noNotifications) ?? false,
      added: prefs.getBool(_added) ?? false,
    );
  }

  Future<void> write(WidgetPromoHistory history) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_shownCount, history.shownCount);
    final last = history.lastShownAt;
    if (last != null) {
      await prefs.setInt(_lastShown, last.millisecondsSinceEpoch);
    }
    await prefs.setBool(_noNotifications, history.noNotificationsShown);
    await prefs.setBool(_added, history.added);
  }

  Future<void> markAdded() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_added, true);
  }

  /// The widget count the app last saw, for logging changes.
  Future<int?> lastInstalledCount() async =>
      (await SharedPreferences.getInstance()).getInt(_installed);

  Future<void> setInstalledCount(int count) async =>
      (await SharedPreferences.getInstance()).setInt(_installed, count);
}
