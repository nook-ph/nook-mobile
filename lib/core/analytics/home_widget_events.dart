// PostHog events for the home-screen widget "Your saved cafes" and the
// one-time card on the Saved tab that offers it. Sent through `logAppEvent`;
// snake_case object_verb, no free text in properties.

abstract final class HomeWidgetEvents {
  /// The "Add widget" card came into view on the Saved tab. Properties:
  /// `reason` (`saves`: three or more Want to try; `no_notifications`:
  /// notifications are off for Nook), `show` (1 or 2: the card is shown at
  /// most twice, 14+ days apart).
  static const promoShown = 'widget_promo_shown';

  /// "Add widget" was tapped and the launcher was asked to place it.
  /// Properties: `reason`. Whether the person confirmed the launcher's
  /// dialog shows up later as [countChanged].
  static const promoAdded = 'widget_promo_added';

  /// "Not now" was tapped. Properties: `reason`.
  static const promoDismissed = 'widget_promo_dismissed';

  /// The widget opened the app. Properties: `target` (`cafe`, a cafe's
  /// row; `header`, the title, which opens Saved; `empty`, the empty
  /// state's "Find a cafe"; `stale`, the "Open Nook to update" state).
  static const tapped = 'widget_tapped';

  /// How many copies of the widget are on the home screen changed since the
  /// app last looked (on start and on resume). Properties: `count`,
  /// `previous`.
  static const countChanged = 'widget_installed_count_changed';
}

/// Values of the `reason` property on the promo events.
abstract final class WidgetPromoReasons {
  static const saves = 'saves';
  static const noNotifications = 'no_notifications';
}
