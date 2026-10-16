import 'package:flutter_test/flutter_test.dart';
import 'package:nook/core/analytics/saver_survey_events.dart';
import 'package:nook/features/saver_survey/domain/saver_survey_reasons.dart';
import 'package:nook/features/saver_survey/domain/saver_survey_rules.dart';

void main() {
  final now = DateTime(2026, 10, 16, 10);
  DateTime daysAgo(int d) => now.subtract(Duration(days: d));

  SaverSurveyDecision decide({
    bool done = false,
    bool firstSession = false,
    int openDays = 2,
    bool prompt = false,
    SaveDates? saves,
    bool unknownSaves = false,
  }) => SaverSurveyRules.decide(
    signals: SaverSurveySignals(
      done: done,
      firstSession: firstSession,
      openDays: openDays,
      promptShownThisSession: prompt,
      saves: unknownSaves ? null : saves ?? SaveDates(wantToTry: [daysAgo(6)]),
    ),
    now: now,
  );

  group('SaverSurveyRules', () {
    test('shows for an old Want to Try, no recent Been, two open days', () {
      final d = decide(
        saves: SaveDates(
          wantToTry: [daysAgo(6), daysAgo(1)],
          been: [daysAgo(20)],
        ),
      );
      expect(d.show, isTrue);
      expect(d.savesCount, 2);
      expect(d.daysSinceFirstSave, 20);
    });

    test('a save exactly five days old counts', () {
      expect(decide(saves: SaveDates(wantToTry: [daysAgo(5)])).show, isTrue);
    });

    test('only saves newer than five days: not yet', () {
      final d = decide(saves: SaveDates(wantToTry: [daysAgo(4), daysAgo(0)]));
      expect(d.show, isFalse);
      expect(d.reason, 'no_old_save');
    });

    test('no Want to Try at all: no', () {
      expect(decide(saves: const SaveDates()).show, isFalse);
    });

    test('a Been in the last 14 days: no', () {
      final d = decide(
        saves: SaveDates(wantToTry: [daysAgo(10)], been: [daysAgo(13)]),
      );
      expect(d.reason, 'recent_been');
    });

    test('a Been 14 or more days ago does not block', () {
      final d = decide(
        saves: SaveDates(wantToTry: [daysAgo(10)], been: [daysAgo(14)]),
      );
      expect(d.show, isTrue);
    });

    test('opened on one day only: no', () {
      expect(decide(openDays: 1).reason, 'open_days');
    });

    test('never in the first session', () {
      expect(decide(firstSession: true).reason, 'first_session');
    });

    test('once ever', () {
      expect(decide(done: true).reason, 'done');
    });

    test('another prompt this session: no', () {
      expect(decide(prompt: true).reason, 'session_prompt');
    });

    test('saves that could not be read: no', () {
      expect(decide(unknownSaves: true).reason, 'saves_unknown');
    });

    test('a save dated in the future does not count as old', () {
      final d = decide(
        saves: SaveDates(wantToTry: [now.add(const Duration(days: 9))]),
      );
      expect(d.show, isFalse);
    });
  });

  group('reasons', () {
    test('six answers with unique ids, Something else last', () {
      final ids = SaverSurveyCopy.reasons.map((r) => r.id).toList();
      expect(ids.toSet().length, ids.length);
      expect(SaverSurveyCopy.reasons.last, SaverSurveyCopy.other);
      expect(SaverSurveyCopy.maxPicks, 2);
    });
  });

  test('length bucket never carries the text', () {
    expect(saverSurveyLengthBucket(0), 'none');
    expect(saverSurveyLengthBucket(1), '1_20');
    expect(saverSurveyLengthBucket(20), '1_20');
    expect(saverSurveyLengthBucket(21), '21_60');
    expect(saverSurveyLengthBucket(60), '21_60');
    expect(saverSurveyLengthBucket(120), '61_120');
  });
}
