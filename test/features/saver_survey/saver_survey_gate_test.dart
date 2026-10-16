import 'package:flutter_test/flutter_test.dart';
import 'package:nook/core/preferences/session_prompts.dart';
import 'package:nook/features/saver_survey/data/save_dates_source.dart';
import 'package:nook/features/saver_survey/data/saver_survey_store.dart';
import 'package:nook/features/saver_survey/domain/saver_survey_rules.dart';
import 'package:nook/features/saver_survey/presentation/saver_survey_gate.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Saves implements SaveDatesSource {
  _Saves(this.dates);
  final SaveDates? dates;
  int reads = 0;

  @override
  Future<SaveDates?> read() async {
    reads++;
    return dates;
  }
}

void main() {
  var clock = DateTime(2026, 10, 10, 9);
  DateTime now() => clock;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    SessionPrompts.resetForTest();
    clock = DateTime(2026, 10, 10, 9);
  });

  /// One app run: a fresh store and gate, as after a cold start.
  SaverSurveyGate launch(_Saves saves, {bool force = false}) => SaverSurveyGate(
    store: SaverSurveyStore(now: now),
    saves: () => saves,
    now: now,
    force: force,
  );

  final oldSave = _Saves(SaveDates(wantToTry: [DateTime(2026, 10, 1)]));

  group('SaverSurveyStore.recordLaunch', () {
    test('first launch is the first session; same day adds no day', () async {
      final first = await SaverSurveyStore(now: now).recordLaunch();
      expect(first.firstSession, isTrue);
      expect(first.openDays, 1);

      final again = await SaverSurveyStore(now: now).recordLaunch();
      expect(again.firstSession, isFalse);
      expect(again.openDays, 1);

      clock = clock.add(const Duration(days: 1));
      final nextDay = await SaverSurveyStore(now: now).recordLaunch();
      expect(nextDay.openDays, 2);
    });

    test('counts once per instance', () async {
      final store = SaverSurveyStore(now: now);
      await store.recordLaunch();
      clock = clock.add(const Duration(days: 1));
      expect((await store.recordLaunch()).openDays, 1);
    });
  });

  group('SaverSurveyGate', () {
    test('never in the first session, even with old saves', () async {
      final d = await launch(oldSave).evaluate();
      expect(d!.show, isFalse);
      expect(d.reason, 'first_session');
    });

    test('a second launch the same day: still only one open day', () async {
      await launch(oldSave).evaluate();
      SessionPrompts.resetForTest();
      final d = await launch(oldSave).evaluate();
      expect(d!.reason, 'open_days');
    });

    test('second day: shows, then never again (once ever)', () async {
      await launch(oldSave).evaluate();
      clock = clock.add(const Duration(days: 1));
      SessionPrompts.resetForTest();
      final shown = await launch(oldSave).evaluate();
      expect(shown!.show, isTrue);
      expect(shown.savesCount, 1);
      expect(shown.daysSinceFirstSave, 10);

      clock = clock.add(const Duration(days: 3));
      SessionPrompts.resetForTest();
      final later = await launch(oldSave).evaluate();
      expect(later!.show, isFalse);
      expect(later.reason, 'done');
    });

    test('takes the run\'s prompt slot when it shows', () async {
      await launch(oldSave).evaluate();
      clock = clock.add(const Duration(days: 1));
      SessionPrompts.resetForTest();
      await launch(oldSave).evaluate();
      expect(SessionPrompts.claim(), isFalse);
    });

    test('another prompt already shown this run: skipped, not done', () async {
      await launch(oldSave).evaluate();
      clock = clock.add(const Duration(days: 1));
      SessionPrompts.resetForTest();
      SessionPrompts.noteShown();
      expect((await launch(oldSave).evaluate())!.reason, 'session_prompt');

      // Next run, nothing else asked: now it shows.
      clock = clock.add(const Duration(days: 1));
      SessionPrompts.resetForTest();
      expect((await launch(oldSave).evaluate())!.show, isTrue);
    });

    test('evaluates once per run', () async {
      final gate = launch(oldSave);
      expect(await gate.evaluate(), isNotNull);
      expect(await gate.evaluate(), isNull);
    });

    test('saves are not read when a cheap rule already says no', () async {
      final saves = _Saves(SaveDates(wantToTry: [DateTime(2026, 10, 1)]));
      await launch(saves).evaluate();
      expect(saves.reads, 0);
    });

    test('debug force shows on any run, first session included', () async {
      final d = await launch(oldSave, force: true).evaluate();
      expect(d!.show, isTrue);
      SessionPrompts.resetForTest();
      expect((await launch(oldSave, force: true).evaluate())!.show, isTrue);
    });

    test('force is off in tests unless asked for', () {
      expect(SaverSurveyGate.forced, isFalse);
    });
  });
}
