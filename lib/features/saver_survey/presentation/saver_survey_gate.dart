import 'package:flutter/foundation.dart';
import 'package:nook/core/preferences/session_prompts.dart';
import 'package:nook/features/saver_survey/data/save_dates_source.dart';
import 'package:nook/features/saver_survey/data/saver_survey_store.dart';
import 'package:nook/features/saver_survey/domain/saver_survey_rules.dart';

/// Decides, at most once per app run, whether Home opens the saver survey.
/// Deciding has no side effects; [commit] claims the run's prompt slot and
/// the once-ever flag, and the host calls it only as the sheet opens, so a
/// survey that ends up not shown (the user moved on) is not spent.
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
  bool _reported = false;
  Future<void>? _doneWrite;

  /// Counts this launch toward "opened on different days". Call as early as
  /// Home appears; [evaluate] calls it too.
  Future<LaunchRecord> recordLaunch() => _launch ??= _store.recordLaunch();

  /// The decision for this run; null after the first call, so a Home that
  /// is rebuilt or revisited later in the run never asks mid-task. Changes
  /// nothing: see [commit].
  Future<SaverSurveyDecision?> evaluate() async {
    if (_evaluated) return null;
    _evaluated = true;
    try {
      final launch = await recordLaunch();
      if (_force) {
        final now = _now();
        final saves = await _saves().read() ?? const SaveDates();
        return SaverSurveyDecision.yes(
          saves: saves,
          oldest: saves.oldestWantToTry(now),
          now: now,
        );
      }
      // Cheap checks first: most runs stop here without reading saves.
      final done = await _store.isDone();
      SaverSurveySignals signals(SaveDates? saves) => SaverSurveySignals(
        done: done,
        firstSession: launch.firstSession,
        openDays: launch.openDays,
        promptShownThisSession: SessionPrompts.anyShown,
        saves: saves,
      );
      final early = SaverSurveyRules.decide(
        signals: signals(const SaveDates()),
        now: _now(),
      );
      if (early.reason != 'no_old_save') return early;
      return SaverSurveyRules.decide(
        signals: signals(await _saves().read()),
        now: _now(),
      );
    } catch (e) {
      debugPrint('[SaverSurvey] evaluate failed: $e');
      return SaverSurveyDecision.no('error');
    }
  }

  /// Claims the run's prompt slot and marks the survey done. Call right
  /// before the sheet opens. False when another prompt took the slot since
  /// [evaluate]: then do not show it (and it is not spent). The done flag is
  /// written as the sheet opens, so a crash or a swipe away still counts.
  bool commit() {
    if (!SessionPrompts.claim() && !_force) return false;
    _doneWrite = _store.markDone().catchError((Object e) {
      debugPrint('[SaverSurvey] markDone failed: $e');
    });
    return true;
  }

  /// Completes once [commit]'s done flag is written.
  @visibleForTesting
  Future<void> get doneWritten => _doneWrite ?? Future.value();

  /// True the first time only: `saver_survey_not_shown` goes once per run.
  bool claimNotShownReport() {
    if (_reported) return false;
    _reported = true;
    return true;
  }
}
