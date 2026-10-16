// PostHog events for the one-time "What's kept you from going?" survey,
// shown to people who saved a cafe to Want to Try but have not been
// (`lib/features/saver_survey/`). Sent through `logAppEvent`; snake_case
// object_verb like the rest. No free text in properties: the optional
// "Something else" text stays on the phone and only its length bucket is
// sent.

abstract final class SaverSurveyEvents {
  /// The sheet opened. Properties: `saves_count` (Want to Try cafes),
  /// `days_since_first_save` (whole days since the oldest Want to Try or
  /// Been save), `signed_in` (bool).
  static const shown = 'saver_survey_shown';

  /// Send was tapped. Properties: `reasons` (list of reason ids, 1 or 2:
  /// `no_time`, `too_far`, `unsure_open`, `waiting_for_friend`,
  /// `found_elsewhere`, `other`), `other_text_present` (bool),
  /// `other_text_length` (`none`, `1_20`, `21_60`, `61_120`).
  static const answered = 'saver_survey_answered';

  /// Skip, a swipe down, a tap on the scrim or Back.
  static const skipped = 'saver_survey_skipped';
}

/// The `other_text_length` bucket for a "Something else" answer of
/// [length] characters (after trimming).
String saverSurveyLengthBucket(int length) {
  if (length <= 0) return 'none';
  if (length <= 20) return '1_20';
  if (length <= 60) return '21_60';
  return '61_120';
}
