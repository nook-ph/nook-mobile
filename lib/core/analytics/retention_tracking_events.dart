// PostHog events for the retention review: where guests meet the sign-in
// wall, what happens at the location prompt, which Home rails are seen and
// used, where a screen ends up empty, and who asks for Nook in their city.
// Sent through `logAppEvent`; snake_case object_verb, no free text except the
// city a user types into the waitlist sheet.

/// The guest sign-in sheets (`GuestSignInSheet`, `CafeGuestSignInSheet`).
abstract final class SignInPromptEvents {
  /// The sheet opened. Properties: `trigger` (the action or tab that needed
  /// an account: `saved_tab`, `profile_tab`, `save_place`, `been`,
  /// `want_to_try`, `save_to_list`, `write_review`, `report_review`,
  /// `helpful_review`).
  static const shown = 'signin_prompt_shown';

  /// The sheet closed without "Sign in or create account": "Not now", a
  /// swipe down or a tap on the scrim. Properties: `trigger`.
  static const dismissed = 'signin_prompt_dismissed';
}

/// The location permission flow.
abstract final class LocationPromptEvents {
  /// Nook asked for location: its own pre-prompt sheet, the system prompt,
  /// or a dialog sending the user to Settings. Properties: `surface` (`map`
  /// for the first-visit prompt on the Map tab, `map_fab` for the recenter
  /// button, `home`).
  static const shown = 'location_prompt_shown';

  /// How a prompt ended. Properties: `surface`, `result` (`granted`,
  /// `while_in_use`, `denied`, `denied_forever`, `unavailable`), and
  /// `system_prompt` (false when the user turned down Nook's own pre-prompt
  /// and the system was never asked).
  static const result = 'location_permission_result';
}

/// Home's shelves ("rails").
abstract final class HomeRailEvents {
  /// A rail came into view, once per rail per Home `$screen`. Properties:
  /// `rail` (the shelf's sort where it has one, else its title in
  /// snake_case: `nearby`, `house_picks`, `specialty_coffee_near_you`,
  /// `local_beans`, `newest`, `laptop_friendly`, `trending`, `top_rated`).
  static const impression = 'home_rail_impression';

  /// A card in a rail. Properties: `rail`, `position` (0-based), `cafe_id`.
  static const cardTapped = 'home_rail_card_tapped';

  // Both rail events also carry `layout_version` (the published Home layout
  // row id) when an admin layout is in force, and custom shelves report
  // `rail` as `custom:<id>`.
}

/// The admin banner at the top of Home (nook-supabase `HOME_LAYOUT.md`).
/// Properties on all three: `layout_version`, `link_type` (`nook`, `https`,
/// `none`).
abstract final class HomeBannerEvents {
  /// The banner was on screen (after a frame, with Home showing), once per
  /// banner per app run. `style` is `card` or `strip`.
  static const shown = 'home_banner_shown';

  /// The banner (or its button) was tapped and its link opened.
  static const tapped = 'home_banner_tapped';

  /// The close button; it stays hidden for that banner version unless the
  /// toast's Undo follows ([restored]).
  static const dismissed = 'home_banner_dismissed';

  /// Undo on the "Announcement hidden" toast brought the banner back.
  static const restored = 'home_banner_restored';
}

/// The page behind `nook://shelf/<id>` (banner landing, custom shelf
/// "See all").
abstract final class HomeShelfEvents {
  /// The page loaded: `shelf`, `from_banner`, `found`, `cafes`.
  static const opened = 'home_shelf_opened';
}

/// Screens that end up with nothing to show.
abstract final class EmptyStateEvents {
  /// Properties: `screen` (`map`, `search`, `list_detail`), `reason`
  /// (`no_cafes_in_area`, `filtered`, `no_match`, `outside_cebu`,
  /// `empty_list`, `empty_want_to_try`, `empty_been`, `load_error_<type>`).
  static const shown = 'empty_state_shown';
}

/// Demand outside Nook's coverage.
abstract final class CityWaitlistEvents {
  /// A user outside Cebu asked for Nook in their city. Properties: `city`
  /// (as typed, trimmed, at most 60 characters), `surface` (`map`, `search`).
  static const requested = 'city_waitlist_requested';
}

/// Person properties this stream sets.
abstract final class RetentionPersonProperties {
  /// Set once on the first app open: the `src` query parameter of the link
  /// that opened the app, else `organic`.
  static const installSource = 'install_source';
}
