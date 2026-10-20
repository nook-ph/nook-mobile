// PostHog events for the one-time "What's kept you from going?" survey,
// shown to people who saved a cafe to Want to Try but have not been
// (`lib/features/saver_survey/`). Sent through `logAppEvent`; snake_case
// object_verb like the rest. No free text in any property: there is no text
// field, and cafe names and ids are never sent.

abstract final class SaverSurveyEvents {
  /// The sheet opened. Properties: `saves_count` (Want to Try cafes),
  /// `days_since_first_save` (whole days since the oldest Want to Try or
  /// Been save), `oldest_stale_days` (whole days since the Want to Try the
  /// question names was saved), `signed_in` (bool).
  static const shown = 'saver_survey_shown';

  /// Send was tapped; logged before any follow-up. Properties: `reasons`
  /// (list of reason ids, 1 or 2: `saving_for_later`, `no_time`, `too_far`,
  /// `unsure_open`, `waiting_for_friend`, `found_elsewhere`, `other`).
  static const answered = 'saver_survey_answered';

  /// Skip, a swipe down, a tap on the scrim or Back, before Send.
  static const skipped = 'saver_survey_skipped';

  /// After Send, the sheet swapped to a follow-up card. Properties: `kind`
  /// (`open_state`, `nearest`, `location_ask`, `share`, `later`).
  static const followUpShown = 'saver_survey_follow_up_shown';

  /// How the follow-up card was left. Properties: `kind` (as above),
  /// `action` (`see_cafe`, `share`, `use_location`, `done`, or `close` for
  /// the close button, a swipe, the scrim or Back).
  static const followUpTapped = 'saver_survey_follow_up_tapped';

  /// A saver who was or may have been eligible was not shown the survey this
  /// run; at most once per run. Properties: `reason` (`saves_unknown`,
  /// `recent_been`, `session_prompt`, `not_on_home`, `error`).
  static const notShown = 'saver_survey_not_shown';
}

/// `saver_survey_follow_up_tapped` actions.
abstract final class SaverSurveyActions {
  static const seeCafe = 'see_cafe';
  static const share = 'share';
  static const useLocation = 'use_location';
  static const done = 'done';
  static const close = 'close';
}
