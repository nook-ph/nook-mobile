/// One answer to "What's kept you from going?". [id] is what analytics gets
/// (stable, snake_case); [label] is what the user reads and can change freely.
class SaverSurveyReason {
  const SaverSurveyReason(this.id, this.label);

  final String id;
  final String label;
}

/// The question, its answers and its limits. Edit [reasons] to change the
/// answers: order here is the order on screen. Keep [other] last; it opens
/// the short text field.
abstract final class SaverSurveyCopy {
  static const title = "What's kept you from going?";
  static const message =
      "You saved a cafe a while back but haven't been yet. Pick up to two.";
  static const sendLabel = 'Send';
  static const skipLabel = 'Skip';
  static const otherHint = 'Tell us more (optional)';
  static const thanks = 'Thanks, that helps.';

  static const other = SaverSurveyReason('other', 'Something else');

  static const reasons = <SaverSurveyReason>[
    SaverSurveyReason('no_time', "Haven't had time"),
    SaverSurveyReason('too_far', 'Too far from me'),
    SaverSurveyReason('unsure_open', 'Not sure it\'s open'),
    SaverSurveyReason('waiting_for_friend', 'Waiting for a friend'),
    SaverSurveyReason('found_elsewhere', 'Found somewhere else'),
    other,
  ];

  /// How many answers can be picked at once.
  static const maxPicks = 2;

  /// The "Something else" field's limit, in characters.
  static const maxOtherLength = 120;
}
