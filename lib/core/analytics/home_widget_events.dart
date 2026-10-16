// PostHog events for the home-screen widget "Your saved cafes" and the
// one-time card on the Saved tab that offers it. Sent through `logAppEvent`;
// snake_case object_verb, no free text in properties.

abstract final class HomeWidgetEvents {
  /// The rules decided to offer the "Add widget" card this session (it may
  /// still sit below the fold; see [promoViewed]). Properties: `reason`
  /// (`saves`: three or more Want to try; `no_notifications`: a real
  /// decline of notifications), `show` (1 or 2: the card is shown at most
  /// twice, 14+ days apart; the number this show would be).
  static const promoShown = 'widget_promo_shown';

  /// At least half the card was on screen for a second: this is what spends
  /// one of the two shows. Properties: `reason`, `show`, and `decline_kind`
  /// (`system_denied` / `sdk_disabled`) when reason is `no_notifications`.
  static const promoViewed = 'widget_promo_viewed';

  /// "Add widget" was tapped and the launcher was asked to place it.
  /// Properties: `reason`. The launcher's answer is [pinResult].
  static const promoAdded = 'widget_promo_added';

  /// What the launcher did after "Add widget", read from the widget count
  /// on the next resume. Properties: `result` (`added`, `cancelled`,
  /// `unknown`), `reason`.
  static const pinResult = 'widget_pin_result';

  /// "Not now" was tapped. Properties: `reason`.
  static const promoDismissed = 'widget_promo_dismissed';

  /// The widget opened the app. Properties: `target` (`cafe`, a cafe's
  /// row; `header`, the title, which opens Saved; `empty`, the empty
  /// state's "Find a cafe"; `stale`, the "Open Nook to update" state).
  static const tapped = 'widget_tapped';

  /// How many copies of the widget are on the home screen changed since the
  /// app last looked (on start and on resume). Properties: `count`,
  /// `previous`, and, when the count rose, `source` (`promo` if "Add
  /// widget" was tapped in the last 10 minutes, else `launcher`; inferred).
  static const countChanged = 'widget_installed_count_changed';
}

/// Values of the `reason` property on the promo events.
abstract final class WidgetPromoReasons {
  static const saves = 'saves';
  static const noNotifications = 'no_notifications';
}
