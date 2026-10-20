import 'package:nook/features/guest_saves/domain/cafe_snapshot.dart';

/// Who gets the saver survey. Pure, so the rules can be tested without a
/// phone, a session or a clock.
///
/// Shown once ever, at app open on Home, to someone who:
/// - has at least one Want to Try cafe saved [minSaveAge] or longer ago,
/// - has marked nothing Been in the last [beenWindow],
/// - has opened the app on at least [minOpenDays] different days,
/// - is not in their first session, and
/// - has not been shown another prompt this session.
///
/// The session check comes after the save checks, so "an old save, crowded
/// out by another prompt" can be told apart from "no old save at all".
abstract final class SaverSurveyRules {
  static const minSaveAge = Duration(days: 5);
  static const beenWindow = Duration(days: 14);
  static const minOpenDays = 2;

  /// The reasons [decide] says no that still mean "this saver was eligible":
  /// they had an old save, or might have. Only these are reported as
  /// `saver_survey_not_shown`; the rest are everyone else's every launch.
  static const reportedNoReasons = {
    'saves_unknown',
    'recent_been',
    'session_prompt',
    'not_on_home',
    'error',
  };

  static SaverSurveyDecision decide({
    required SaverSurveySignals signals,
    required DateTime now,
  }) {
    if (signals.done) return SaverSurveyDecision.no('done');
    if (signals.firstSession) return SaverSurveyDecision.no('first_session');
    if (signals.openDays < minOpenDays) {
      return SaverSurveyDecision.no('open_days');
    }
    final saves = signals.saves;
    if (saves == null) return SaverSurveyDecision.no('saves_unknown');
    final oldest = saves.oldestWantToTry(now, minAge: minSaveAge);
    if (oldest == null) return SaverSurveyDecision.no('no_old_save');
    final recentBeen = saves.been.any((at) => now.difference(at) < beenWindow);
    if (recentBeen) return SaverSurveyDecision.no('recent_been');
    if (signals.promptShownThisSession) {
      return SaverSurveyDecision.no('session_prompt');
    }
    return SaverSurveyDecision.yes(saves: saves, oldest: oldest, now: now);
  }
}

/// One Want to Try save: when, and the cafe when it is known on the phone.
class WantToTrySave {
  const WantToTrySave(this.savedAt, [this.cafe]);

  final DateTime savedAt;

  /// Name, hours and coordinates; null when only the date could be read.
  final CafeSnapshot? cafe;
}

/// When the user's Want to Try and Been cafes were saved.
class SaveDates {
  const SaveDates({this.wantToTry = const [], this.been = const []});

  final List<WantToTrySave> wantToTry;
  final List<DateTime> been;

  /// Whole days since the oldest save of either kind; 0 with none.
  int daysSinceFirst(DateTime now) {
    final all = [for (final s in wantToTry) s.savedAt, ...been];
    if (all.isEmpty) return 0;
    final first = all.reduce((a, b) => a.isBefore(b) ? a : b);
    final days = now.difference(first).inDays;
    return days < 0 ? 0 : days;
  }

  /// The Want to Try the survey asks about: the oldest one at least [minAge]
  /// old (not dated in the future). Among those, one whose cafe is known wins
  /// over an older one that is only a date, so the question can name it.
  /// Null when none is old enough.
  WantToTrySave? oldestWantToTry(
    DateTime now, {
    Duration minAge = Duration.zero,
  }) {
    final old = [
      for (final s in wantToTry)
        if (!now.difference(s.savedAt).isNegative &&
            now.difference(s.savedAt) >= minAge)
          s,
    ]..sort((a, b) => a.savedAt.compareTo(b.savedAt));
    if (old.isEmpty) return null;
    return old.firstWhere((s) => s.cafe != null, orElse: () => old.first);
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
    this.cafe,
    this.staleDays = 0,
    this.wantToTry = const [],
  });

  /// Show, asking about [oldest] (see [SaveDates.oldestWantToTry]).
  factory SaverSurveyDecision.yes({
    required SaveDates saves,
    required WantToTrySave? oldest,
    required DateTime now,
  }) {
    final days = oldest == null ? 0 : now.difference(oldest.savedAt).inDays;
    return SaverSurveyDecision._(
      show: true,
      savesCount: saves.wantToTry.length,
      daysSinceFirstSave: saves.daysSinceFirst(now),
      cafe: oldest?.cafe,
      staleDays: days < 0 ? 0 : days,
      wantToTry: [
        for (final s in saves.wantToTry)
          if (s.cafe != null) s.cafe!,
      ],
    );
  }

  factory SaverSurveyDecision.no(String reason) =>
      SaverSurveyDecision._(show: false, reason: reason);

  final bool show;

  /// Why not; null when [show].
  final String? reason;

  /// Want to Try cafes saved.
  final int savesCount;
  final int daysSinceFirstSave;

  /// The cafe the question names; null when only its date is known.
  final CafeSnapshot? cafe;

  /// Whole days since [cafe] (the oldest old Want to Try) was saved.
  final int staleDays;

  /// Every Want to Try cafe known on the phone, for "the closest of your
  /// saves".
  final List<CafeSnapshot> wantToTry;
}
