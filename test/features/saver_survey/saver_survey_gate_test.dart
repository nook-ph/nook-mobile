import 'package:flutter_test/flutter_test.dart';
import 'package:nook/core/presentation/session_ask_budget.dart';
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
    SessionAskBudget.instance.resetForTest();
    clock = DateTime(2026, 10, 10, 9);
  });

  /// One app run: a fresh store and gate, as after a cold start.
  SaverSurveyGate launch(_Saves saves, {bool force = false}) => SaverSurveyGate(
    store: SaverSurveyStore(now: now),
    saves: () => saves,
    now: now,
    force: force,
  );

  final oldSave = _Saves(
    SaveDates(wantToTry: [WantToTrySave(DateTime(2026, 10, 1))]),
  );

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
      SessionAskBudget.instance.resetForTest();
      final d = await launch(oldSave).evaluate();
      expect(d!.reason, 'open_days');
    });

    test('second day: shows, then never again (once ever)', () async {
      await launch(oldSave).evaluate();
      clock = clock.add(const Duration(days: 1));
      SessionAskBudget.instance.resetForTest();
      final gate = launch(oldSave);
      final shown = await gate.evaluate();
      expect(shown!.show, isTrue);
      expect(shown.savesCount, 1);
      expect(shown.daysSinceFirstSave, 10);
      expect(shown.staleDays, 10);
      expect(gate.commit(), isTrue);
      await gate.doneWritten;

      clock = clock.add(const Duration(days: 3));
      SessionAskBudget.instance.resetForTest();
      final later = await launch(oldSave).evaluate();
      expect(later!.show, isFalse);
      expect(later.reason, 'done');
    });

    test(
      'deciding spends nothing; commit takes the slot and the flag',
      () async {
        await launch(oldSave).evaluate();
        clock = clock.add(const Duration(days: 1));
        SessionAskBudget.instance.resetForTest();
        final gate = launch(oldSave);
        expect((await gate.evaluate())!.show, isTrue);
        // Decided, not committed (the user left Home): nothing is spent.
        expect(SessionAskBudget.instance.anyShown, isFalse);
        expect(await SaverSurveyStore(now: now).isDone(), isFalse);

        expect(gate.commit(), isTrue);
        await gate.doneWritten;
        expect(SessionAskBudget.instance.claim('test'), isFalse);
        expect(await SaverSurveyStore(now: now).isDone(), isTrue);
      },
    );

    test('a decision not committed shows again next run', () async {
      await launch(oldSave).evaluate();
      clock = clock.add(const Duration(days: 1));
      SessionAskBudget.instance.resetForTest();
      await launch(oldSave).evaluate(); // never committed
      SessionAskBudget.instance.resetForTest();
      expect((await launch(oldSave).evaluate())!.show, isTrue);
    });

    test(
      'commit fails when another prompt took the slot after deciding',
      () async {
        await launch(oldSave).evaluate();
        clock = clock.add(const Duration(days: 1));
        SessionAskBudget.instance.resetForTest();
        final gate = launch(oldSave);
        expect((await gate.evaluate())!.show, isTrue);
        SessionAskBudget.instance.noteShown('test');
        expect(gate.commit(), isFalse);
        await gate.doneWritten;
        expect(await SaverSurveyStore(now: now).isDone(), isFalse);
      },
    );

    test('not-shown is reported once per run', () {
      final gate = launch(oldSave);
      expect(gate.claimNotShownReport(), isTrue);
      expect(gate.claimNotShownReport(), isFalse);
    });

    test('another prompt already shown this run: skipped, not done', () async {
      await launch(oldSave).evaluate();
      clock = clock.add(const Duration(days: 1));
      SessionAskBudget.instance.resetForTest();
      SessionAskBudget.instance.noteShown('test');
      expect((await launch(oldSave).evaluate())!.reason, 'session_prompt');

      // Next run, nothing else asked: now it shows.
      clock = clock.add(const Duration(days: 1));
      SessionAskBudget.instance.resetForTest();
      expect((await launch(oldSave).evaluate())!.show, isTrue);
    });

    test('evaluates once per run', () async {
      final gate = launch(oldSave);
      expect(await gate.evaluate(), isNotNull);
      expect(await gate.evaluate(), isNull);
    });

    test('saves are not read when a cheap rule already says no', () async {
      final saves = _Saves(
        SaveDates(wantToTry: [WantToTrySave(DateTime(2026, 10, 1))]),
      );
      await launch(saves).evaluate();
      expect(saves.reads, 0);
    });

    test('debug force shows on any run, first session included', () async {
      final d = await launch(oldSave, force: true).evaluate();
      expect(d!.show, isTrue);
      SessionAskBudget.instance.resetForTest();
      expect((await launch(oldSave, force: true).evaluate())!.show, isTrue);
    });

    test('force is off in tests unless asked for', () {
      expect(SaverSurveyGate.forced, isFalse);
    });
  });
}
