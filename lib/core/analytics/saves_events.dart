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

  /// "Saved on this phone. Sign in to keep it everywhere." Properties:
  /// `surface` (`first_save_toast`, the one-time toast after a guest's first
  /// save; `saved_tab`, the card on a guest's Saved tab).
  static const keepSavesPromptShown = 'keep_saves_prompt_shown';

  /// That prompt's Sign in was tapped. Properties: `surface`.
  static const keepSavesPromptTapped = 'keep_saves_prompt_tapped';
}

/// Values of the `surface` property on the keep-saves prompt events.
abstract final class KeepSavesSurface {
  static const firstSaveToast = 'first_save_toast';
  static const savedTab = 'saved_tab';

  /// After "I went" on the visit reminder.
  static const reminder = 'reminder';
}

/// Values of the `source` property on a save or a ranking that did not come
/// from a plain tap on the cafe page.
abstract final class SavesSource {
  /// "I went" (or the body) on the visit reminder.
  static const reminder = 'reminder';
}
