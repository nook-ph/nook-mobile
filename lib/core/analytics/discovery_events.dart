// PostHog events for the bottom nav and the discovery screens (Home, Map,
// Cafe Details), sent through `logAppEvent`. Named object_verb in the past
// tense, like the rest of the app's events. No free text in properties.

/// Bottom navigation events.
abstract final class NavEvents {
  /// A bottom-nav tab was tapped. Properties: `tab` and `from_tab` (screen
  /// names), `result` (`switched`, `reselected` or `sign_in_required`).
  static const tabTapped = 'nav_tab_tapped';
}

/// Map tab events.
abstract final class MapEvents {
  /// The recenter (locate) button. Properties: `location_permission` (the
  /// geolocator permission before the tap: `denied`, `deniedForever`,
  /// `whileInUse`, `always`, `unableToDetermine` or `unknown`),
  /// `location_service_enabled`, `result` (`tracking`, `granted_tracking`,
  /// `prompt_denied`, `services_off`, `services_off_settings`,
  /// `denied_forever`, `denied_forever_settings`, `error`), `had_place`
  /// (a chosen place was in force) and `was_following` (the map was already
  /// following the user, so the tap changed nothing on screen).
  static const recenterTapped = 'map_recenter_tapped';

  /// A cafe pin on the map. Properties: `cafe_id`.
  static const pinTapped = 'map_pin_tapped';

  /// The list button beside the search pill. Properties: `open` (the list
  /// is open after the tap).
  static const listToggled = 'map_list_toggled';

  /// The search pill, which chooses the place distances are measured from.
  static const originTapped = 'map_origin_tapped';
}

/// Home tab events.
abstract final class HomeEvents {
  /// The search pill at the top of Home.
  static const searchTapped = 'home_search_tapped';

  /// A shelf's "See all". Properties: `sort` (the shelf: `nearby`,
  /// `newest`, `trending`, `top_rated`).
  static const seeAllTapped = 'home_see_all_tapped';

  /// A cafe card in a shelf (Home's rows, and "If you like this…" on Cafe
  /// Details; `$screen_name` tells them apart). Properties: `cafe_id`,
  /// `section` (the shelf's sort, else its title), `position` (0-based).
  static const cafeCardTapped = 'cafe_card_tapped';
}

/// Cafe Details events (beyond the owner-reporting funnel in
/// `AnalyticsService`).
abstract final class CafeDetailsEvents {
  /// The bookmark in the header. Properties: `cafe_id`, `result`
  /// (`guest`, `busy`, `saved`, `failed`, `opened_lists`).
  static const saveTapped = 'cafe_save_tapped';

  /// Share in the header before the cafe has loaded, which shares nothing.
  /// Properties: `cafe_id`.
  static const shareNotReady = 'cafe_share_not_ready';

  /// A social link in Location & Contacts. Properties: `cafe_id`,
  /// `platform` (`instagram`, `facebook`, `tiktok`, ...).
  static const socialTapped = 'cafe_social_tapped';
}
