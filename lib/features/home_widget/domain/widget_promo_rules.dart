import 'package:equatable/equatable.dart';

/// Why the "Add widget" card is offered, which decides its words.
enum WidgetPromoReason {
  /// Three or more Want to try: "See your saved cafes on your home screen".
  saves,

  /// Notifications are off for Nook: "Prefer no notifications? Add the
  /// widget". Offered once.
  noNotifications,
}

/// What this phone remembers about the card.
class WidgetPromoHistory extends Equatable {
  const WidgetPromoHistory({
    this.shownCount = 0,
    this.lastShownAt,
    this.noNotificationsShown = false,
    this.added = false,
  });

  final int shownCount;
  final DateTime? lastShownAt;
  final bool noNotificationsShown;

  /// "Add widget" was tapped once; the card is not offered again.
  final bool added;

  @override
  List<Object?> get props => [
    shownCount,
    lastShownAt,
    noNotificationsShown,
    added,
  ];
}

/// When the card may show. Pure, so the cap is tested without a phone.
abstract final class WidgetPromoRules {
  /// Shown at most this many times on a phone, whatever the reason.
  static const maxShows = 2;

  /// And never again within this long of the last time.
  static const minGap = Duration(days: 14);

  /// Want to try cafes before the card is worth showing.
  static const minWantToTry = 3;

  /// The reason to show the card now, or null not to.
  ///
  /// [notificationsOff] null means unknown (not off). The widget must be
  /// placeable ([canPin]) and not on the home screen already
  /// ([installedCount] 0; null means unknown and does not block).
  static WidgetPromoReason? decide({
    required WidgetPromoHistory history,
    required int wantToTryCount,
    required bool? notificationsOff,
    required bool canPin,
    required int? installedCount,
    required DateTime now,
  }) {
    if (!canPin || history.added) return null;
    if ((installedCount ?? 0) > 0) return null;
    if (history.shownCount >= maxShows) return null;
    final last = history.lastShownAt;
    if (last != null && now.difference(last) < minGap) return null;
    // An empty widget is no reason to add one.
    if (wantToTryCount < 1) return null;
    if (notificationsOff == true && !history.noNotificationsShown) {
      return WidgetPromoReason.noNotifications;
    }
    if (wantToTryCount >= minWantToTry) return WidgetPromoReason.saves;
    return null;
  }

  /// [history] after the card was shown for [reason] at [now].
  static WidgetPromoHistory afterShown(
    WidgetPromoHistory history,
    WidgetPromoReason reason,
    DateTime now,
  ) => WidgetPromoHistory(
    shownCount: history.shownCount + 1,
    lastShownAt: now,
    noNotificationsShown:
        history.noNotificationsShown ||
        reason == WidgetPromoReason.noNotifications,
    added: history.added,
  );
}
