/// One answer to "What's kept you from going?". [id] is what analytics gets
/// (stable, snake_case); [label] is what the user reads and can change freely.
class SaverSurveyReason {
  const SaverSurveyReason(this.id, this.label);

  final String id;
  final String label;
}

/// The question, its answers and its limits. Edit [reasons] to change the
/// answers: order here is the order on screen. "Saving it for later" leads,
/// so having no obstacle is a first-class answer; "Something else" is last
/// and is a plain row (analytics carry no free text, so nothing is typed).
abstract final class SaverSurveyCopy {
  static const title = "What's kept you from going?";
  static const sendLabel = 'Send';
  static const skipLabel = 'Skip';
  static const thanks = 'Thanks, that helps.';

  static const savingForLater = SaverSurveyReason(
    'saving_for_later',
    'Saving it for later',
  );
  static const noTime = SaverSurveyReason('no_time', "Haven't had time");
  static const tooFar = SaverSurveyReason('too_far', 'Too far from me');
  static const unsureOpen = SaverSurveyReason(
    'unsure_open',
    "Not sure it's open",
  );
  static const waitingForFriend = SaverSurveyReason(
    'waiting_for_friend',
    'Waiting for a friend',
  );
  static const foundElsewhere = SaverSurveyReason(
    'found_elsewhere',
    'Found somewhere else',
  );
  static const other = SaverSurveyReason('other', 'Something else');

  static const reasons = <SaverSurveyReason>[
    savingForLater,
    noTime,
    tooFar,
    unsureOpen,
    waitingForFriend,
    foundElsewhere,
    other,
  ];

  /// How many answers can be picked at once. A pick past it replaces the
  /// oldest one.
  static const maxPicks = 2;

  /// The line under the title. Names the cafe and how long ago it was saved
  /// ([cafeName] null: "a cafe"); no guilt, and "No rush" makes not going a
  /// fine answer.
  /// What [message] starts with, before the cafe's name.
  static const savedPrefix = 'You saved ';

  static String message({String? cafeName, required int days}) {
    final name = (cafeName == null || cafeName.trim().isEmpty)
        ? 'a cafe'
        : cafeName.trim();
    return '$savedPrefix$name ${ago(days)}. '
        "No rush — if something's in the way, pick up to two.";
  }

  /// "today", "yesterday", "9 days ago".
  static String ago(int days) => switch (days) {
    <= 0 => 'today',
    1 => 'yesterday',
    _ => '$days days ago',
  };
}
