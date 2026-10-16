/// Who gets the saver survey. Pure, so the rules can be tested without a
/// phone, a session or a clock.
///
/// Shown once ever, at app open on Home, to someone who:
/// - has at least one Want to Try cafe saved [minSaveAge] or longer ago,
/// - has marked nothing Been in the last [beenWindow],
/// - has opened the app on at least [minOpenDays] different days,
/// - is not in their first session, and
/// - has not been shown another prompt this session.
abstract final class SaverSurveyRules {
  static const minSaveAge = Duration(days: 5);
  static const beenWindow = Duration(days: 14);
  static const minOpenDays = 2;

  static SaverSurveyDecision decide({
    required SaverSurveySignals signals,
    required DateTime now,
  }) {
    if (signals.done) return SaverSurveyDecision.no('done');
    if (signals.firstSession) return SaverSurveyDecision.no('first_session');
    if (signals.openDays < minOpenDays) {
      return SaverSurveyDecision.no('open_days');
    }
    if (signals.promptShownThisSession) {
      return SaverSurveyDecision.no('session_prompt');
    }
    final saves = signals.saves;
    if (saves == null) return SaverSurveyDecision.no('saves_unknown');
    final old = saves.wantToTry.where(
      (at) =>
          !now.difference(at).isNegative && now.difference(at) >= minSaveAge,
    );
    if (old.isEmpty) return SaverSurveyDecision.no('no_old_save');
    final recentBeen = saves.been.any((at) => now.difference(at) < beenWindow);
    if (recentBeen) return SaverSurveyDecision.no('recent_been');
    return SaverSurveyDecision.yes(
      savesCount: saves.wantToTry.length,
      daysSinceFirstSave: saves.daysSinceFirst(now),
    );
  }
}

/// When the user's Want to Try and Been cafes were saved.
class SaveDates {
  const SaveDates({this.wantToTry = const [], this.been = const []});

  final List<DateTime> wantToTry;
  final List<DateTime> been;

  /// Whole days since the oldest save of either kind; 0 with none.
  int daysSinceFirst(DateTime now) {
    final all = [...wantToTry, ...been];
    if (all.isEmpty) return 0;
    final first = all.reduce((a, b) => a.isBefore(b) ? a : b);
    final days = now.difference(first).inDays;
    return days < 0 ? 0 : days;
  }
}

/// Everything [SaverSurveyRules.decide] looks at.
class SaverSurveySignals {
  const SaverSurveySignals({
    required this.done,
    required this.firstSession,
    required this.openDays,
    required this.promptShownThisSession,
    required this.saves,
  });

  /// Shown before (answered or skipped).
  final bool done;

  /// This launch is the first one Nook has recorded on this phone.
  final bool firstSession;

  /// Different calendar days the app was opened on, this one included.
  final int openDays;

  final bool promptShownThisSession;

  /// Null when the saves could not be read: then nothing is shown.
  final SaveDates? saves;
}

class SaverSurveyDecision {
  const SaverSurveyDecision._({
    required this.show,
    this.reason,
    this.savesCount = 0,
    this.daysSinceFirstSave = 0,
  });

  factory SaverSurveyDecision.yes({
    required int savesCount,
    required int daysSinceFirstSave,
  }) => SaverSurveyDecision._(
    show: true,
    savesCount: savesCount,
    daysSinceFirstSave: daysSinceFirstSave,
  );

  factory SaverSurveyDecision.no(String reason) =>
      SaverSurveyDecision._(show: false, reason: reason);

  final bool show;

  /// Why not, for debugging; null when [show].
  final String? reason;

  /// Want to Try cafes saved.
  final int savesCount;
  final int daysSinceFirstSave;
}
