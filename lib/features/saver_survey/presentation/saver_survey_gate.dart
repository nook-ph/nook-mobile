import 'package:flutter/foundation.dart';
import 'package:nook/core/preferences/session_prompts.dart';
import 'package:nook/features/saver_survey/data/save_dates_source.dart';
import 'package:nook/features/saver_survey/data/saver_survey_store.dart';
import 'package:nook/features/saver_survey/domain/saver_survey_rules.dart';

/// Decides, at most once per app run, whether Home opens the saver survey,
/// and claims the run's prompt slot and the once-ever flag when it does.
class SaverSurveyGate {
  SaverSurveyGate({
    required SaverSurveyStore store,
    required SaveDatesSource Function() saves,
    DateTime Function()? now,
    bool? force,
  }) : _store = store,
       _saves = saves,
       _now = now ?? DateTime.now,
       _force = force ?? forced;

  /// `--dart-define=NOOK_FORCE_SAVER_SURVEY=true` shows the survey on every
  /// launch, whatever the rules say. Debug builds only: in profile and
  /// release `kDebugMode` is a constant false and this is compiled out.
  static bool get forced =>
      kDebugMode && const bool.fromEnvironment('NOOK_FORCE_SAVER_SURVEY');

  final SaverSurveyStore _store;
  final SaveDatesSource Function() _saves;
  final DateTime Function() _now;
  final bool _force;

  Future<LaunchRecord>? _launch;
  bool _evaluated = false;

  /// Counts this launch toward "opened on different days". Call as early as
  /// Home appears; [evaluate] calls it too.
  Future<LaunchRecord> recordLaunch() => _launch ??= _store.recordLaunch();

  /// The decision for this run; null after the first call, so a Home that
  /// is rebuilt or revisited later in the run never asks mid-task. When it
  /// says show, the survey is already marked done and the run's prompt slot
  /// taken.
  Future<SaverSurveyDecision?> evaluate() async {
    if (_evaluated) return null;
    _evaluated = true;
    try {
      final launch = await recordLaunch();
      final SaverSurveyDecision decision;
      if (_force) {
        final saves = await _saves().read() ?? const SaveDates();
        final now = _now();
        decision = SaverSurveyDecision.yes(
          savesCount: saves.wantToTry.length,
          daysSinceFirstSave: saves.daysSinceFirst(now),
        );
      } else {
        // Cheap checks first: most runs stop here without reading saves.
        final done = await _store.isDone();
        final early = SaverSurveyRules.decide(
          signals: SaverSurveySignals(
            done: done,
            firstSession: launch.firstSession,
            openDays: launch.openDays,
            promptShownThisSession: SessionPrompts.anyShown,
            saves: const SaveDates(),
          ),
          now: _now(),
        );
        if (early.reason != 'no_old_save') return early;
        decision = SaverSurveyRules.decide(
          signals: SaverSurveySignals(
            done: done,
            firstSession: launch.firstSession,
            openDays: launch.openDays,
            promptShownThisSession: SessionPrompts.anyShown,
            saves: await _saves().read(),
          ),
          now: _now(),
        );
      }
      if (!decision.show) return decision;
      if (!SessionPrompts.claim() && !_force) {
        return SaverSurveyDecision.no('session_prompt');
      }
      await _store.markDone();
      return decision;
    } catch (e) {
      debugPrint('[SaverSurvey] evaluate failed: $e');
      return SaverSurveyDecision.no('error');
    }
  }
}
