// PostHog events for saves made without an account (kept on the phone),
// their move to an account on sign-in, and the nudges around them. Sent
// through `logAppEvent`. snake_case, object_verb in the past tense, like the
// rest of the app's events. No free text in properties.

/// Guest saves, first saves and the prompts that follow them.
abstract final class SavesEvents {
  /// A guest marked a cafe Want to Try or Been, kept on this phone.
  /// Properties: `status` (`want_to_try` or `been`), `source` (`reminder`
  /// when from the visit reminder's "I went"; absent otherwise).
  static const guestSaveCreated = 'guest_save_created';

  /// Saves kept on this phone were moved to the account after sign-in (or
  /// some failed to). Properties: `count` (how many were added; ones the
  /// account already had are not counted), `moved` (now in the account,
  /// including those), `failed` (left on the phone for a retry).
  static const guestSavesMerged = 'guest_saves_merged';

  /// The first Want to Try / Been made on this phone, by anyone. Properties:
  /// `status` (`want_to_try` or `been`), `guest` (bool).
  static const firstSave = 'first_save';

  /// "Save to Want to try?" after returning from directions to a cafe that
  /// was not saved. Properties: `cafe_id`.
  static const directionsSaveNudgeShown = 'directions_save_nudge_shown';

  /// The nudge's Save was tapped. Properties: `cafe_id`.
  static const directionsSaveNudgeTapped = 'directions_save_nudge_tapped';

  /// A keep-your-saves sign-in offer was shown. Properties: `surface`
  /// (`saved_tab`, the card on a guest's Saved tab; `first_save_toast`, the
  /// old first-save toast, no longer sent).
  static const keepSavesPromptShown = 'keep_saves_prompt_shown';

  /// That prompt's Sign in was tapped. Properties: `surface`.
  static const keepSavesPromptTapped = 'keep_saves_prompt_tapped';

  /// The "1 been · 2 to try" pill was tapped to open Want to try.
  /// Properties: `surface` (`home`, `saved_tab`).
  static const placesProgressTapped = 'places_progress_tapped';

  /// A guest marked a Want to try cafe Been from its row on the Saved tab.
  static const beenFromRow = 'been_from_want_to_try_row';

  /// A guest's save was removed. Properties: `source` (`undo`, the save
  /// toast's Undo; `pill`, a tap on the current status; `top_save`, the cafe
  /// page's top-right bookmark).
  static const guestSaveRemoved = 'guest_save_removed';

  /// The merge toast's View was tapped. Properties: `count` (cafes moved).
  static const mergeToastViewTapped = 'merge_toast_view_tapped';

  /// The engagement-score ask (the keep-saves sign-in sheet) was shown.
  /// Properties: `trigger` (`after_save`, `saved_open`), `score` (the
  /// guest's score at the ask), `ask_number` (1 to 3).
  static const signUpAskShown = 'signup_ask_shown';

  /// That ask was dismissed. Properties: as shown, plus `score_after` (the
  /// score once the dismissal took its points off), `how` (`not_now`,
  /// `swipe_or_back`, `stay_on_phone`) and `saves_count`.
  static const signUpAskDismissed = 'signup_ask_dismissed';

  /// A sign-in was chosen from that ask; it may not have finished (see
  /// [signUpAskCompleted]). Properties: as shown, plus `provider` (`google`,
  /// `apple`, `email`).
  static const signUpAskAccepted = 'signup_ask_accepted';

  /// A session started from that ask: at once for Google or Apple, or
  /// within 30 minutes of choosing email. Properties: as accepted.
  static const signUpAskCompleted = 'signup_ask_completed';

  /// An ask was due at a value moment but held back, once per reason per
  /// session. Properties: `reason` (`session_budget`, `cooldown`,
  /// `max_asks`, `below_threshold`, `saves_not_doubled`, `stay_on_phone`),
  /// `trigger`.
  static const signUpAskSuppressed = 'signup_ask_suppressed';
}

/// Values of the `surface` property on the keep-saves prompt events.
abstract final class KeepSavesSurface {
  /// The one-time toast after a guest's first save. No longer sent: that
  /// line has no Sign in now, and the engagement score asks instead.
  static const firstSaveToast = 'first_save_toast';
  static const savedTab = 'saved_tab';

  /// The one-line row that replaces the Saved tab's card after two declined
  /// asks.
  static const savedRow = 'saved_row';

  /// After "I went" on the visit reminder.
  static const reminder = 'reminder';

  /// The sheet the engagement score asks with.
  static const engagementAsk = 'engagement_ask';
}

/// Values of the `source` property on a save or a ranking that did not come
/// from a plain tap on the cafe page.
abstract final class SavesSource {
  /// "I went" (or the body) on the visit reminder.
  static const reminder = 'reminder';

  /// The "Save to Want to try?" nudge after directions.
  static const directionsNudge = 'directions_nudge';

  /// A save toast's Undo.
  static const undo = 'undo';

  /// A tap on the Been / Want to try pill.
  static const pill = 'pill';

  /// The cafe page's top-right bookmark.
  static const topSave = 'top_save';
}
