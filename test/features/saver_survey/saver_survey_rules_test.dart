import 'package:flutter_test/flutter_test.dart';
import 'package:nook/features/guest_saves/domain/cafe_snapshot.dart';
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
      saves: unknownSaves
          ? null
          : saves ?? SaveDates(wantToTry: [WantToTrySave(daysAgo(6))]),
    ),
    now: now,
  );

  group('SaverSurveyRules', () {
    test('shows for an old Want to Try, no recent Been, two open days', () {
      final d = decide(
        saves: SaveDates(
          wantToTry: [WantToTrySave(daysAgo(6)), WantToTrySave(daysAgo(1))],
          been: [daysAgo(20)],
        ),
      );
      expect(d.show, isTrue);
      expect(d.savesCount, 2);
      expect(d.daysSinceFirstSave, 20);
    });

    test('a save exactly five days old counts', () {
      expect(
        decide(saves: SaveDates(wantToTry: [WantToTrySave(daysAgo(5))])).show,
        isTrue,
      );
    });

    test('only saves newer than five days: not yet', () {
      final d = decide(
        saves: SaveDates(
          wantToTry: [WantToTrySave(daysAgo(4)), WantToTrySave(daysAgo(0))],
        ),
      );
      expect(d.show, isFalse);
      expect(d.reason, 'no_old_save');
    });

    test('no Want to Try at all: no', () {
      expect(decide(saves: const SaveDates()).show, isFalse);
    });

    test('a Been in the last 14 days: no', () {
      final d = decide(
        saves: SaveDates(
          wantToTry: [WantToTrySave(daysAgo(10))],
          been: [daysAgo(13)],
        ),
      );
      expect(d.reason, 'recent_been');
    });

    test('a Been 14 or more days ago does not block', () {
      final d = decide(
        saves: SaveDates(
          wantToTry: [WantToTrySave(daysAgo(10))],
          been: [daysAgo(14)],
        ),
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

    test('another prompt this session: no, but only after the saves', () {
      expect(decide(prompt: true).reason, 'session_prompt');
      expect(
        decide(prompt: true, saves: const SaveDates()).reason,
        'no_old_save',
      );
    });

    test('saves that could not be read: no', () {
      expect(decide(unknownSaves: true).reason, 'saves_unknown');
    });

    test('a save dated in the future does not count as old', () {
      final d = decide(
        saves: SaveDates(
          wantToTry: [WantToTrySave(now.add(const Duration(days: 9)))],
        ),
      );
      expect(d.show, isFalse);
    });
  });

  group('the oldest save', () {
    const brew = CafeSnapshot(id: 'b', name: 'Brew Szn');
    const julio = CafeSnapshot(id: 'j', name: 'Cafe Julio');

    test('names the oldest old Want to Try and its age', () {
      final d = decide(
        saves: SaveDates(
          wantToTry: [
            WantToTrySave(daysAgo(6), julio),
            WantToTrySave(daysAgo(9), brew),
            WantToTrySave(daysAgo(2), const CafeSnapshot(id: 'n', name: 'New')),
          ],
        ),
      );
      expect(d.cafe, brew);
      expect(d.staleDays, 9);
      expect(d.wantToTry, hasLength(3));
    });

    test('a known cafe wins over an older date-only save', () {
      final d = decide(
        saves: SaveDates(
          wantToTry: [
            WantToTrySave(daysAgo(20)),
            WantToTrySave(daysAgo(7), julio),
          ],
        ),
      );
      expect(d.cafe, julio);
      expect(d.staleDays, 7);
    });

    test('only date-only saves: no cafe, still the oldest age', () {
      final d = decide(
        saves: SaveDates(wantToTry: [WantToTrySave(daysAgo(8))]),
      );
      expect(d.show, isTrue);
      expect(d.cafe, isNull);
      expect(d.staleDays, 8);
    });
  });

  group('reasons', () {
    test('seven answers with unique ids, later first, Something else last', () {
      final ids = SaverSurveyCopy.reasons.map((r) => r.id).toList();
      expect(ids.toSet().length, ids.length);
      expect(ids.first, 'saving_for_later');
      expect(SaverSurveyCopy.reasons.last, SaverSurveyCopy.other);
      expect(SaverSurveyCopy.maxPicks, 2);
    });

    test('the message names the cafe and its age', () {
      expect(
        SaverSurveyCopy.message(cafeName: 'Brew Szn', days: 9),
        "You saved Brew Szn 9 days ago. No rush — if something's in the way, "
        'pick up to two.',
      );
      expect(
        SaverSurveyCopy.message(cafeName: null, days: 1),
        startsWith('You saved a cafe yesterday.'),
      );
    });
  });
}
