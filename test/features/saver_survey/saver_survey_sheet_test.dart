import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/core/analytics/saver_survey_events.dart';
import 'package:nook/features/guest_saves/domain/cafe_snapshot.dart';
import 'package:nook/features/saver_survey/domain/saver_survey_follow_up.dart';
import 'package:nook/features/saver_survey/domain/saver_survey_reasons.dart';
import 'package:nook/features/saver_survey/presentation/saver_survey_sheet.dart';

void main() {
  late SaverSurveyResult? result;
  late bool closed;
  late List<SaverSurveyAnswer> sent;

  // Open 08:00-21:00 every day; Manila 10:00 on a Friday.
  final hours = {
    for (final d in [
      'monday',
      'tuesday',
      'wednesday',
      'thursday',
      'friday',
      'saturday',
      'sunday',
    ])
      d: {'open': '08:00', 'close': '21:00'},
  };
  final now = DateTime.utc(2026, 10, 16, 2);
  final brew = CafeSnapshot(id: 'b', name: 'Brew Szn', operatingHours: hours);

  Future<void> open(
    WidgetTester tester, {
    SaverSurveyFollowUp? Function(SaverSurveyAnswer)? followUp,
    Future<SaverSurveyFollowUp?> Function()? onUseLocation,
  }) async {
    closed = false;
    result = null;
    sent = [];
    // A Pixel-class phone, as on the emulator.
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () async {
                  result = await showSaverSurveySheet(
                    context,
                    sheet: SaverSurveySheet(
                      cafeName: 'Brew Szn',
                      days: 9,
                      now: () => now,
                      onSend: (answer) async {
                        sent.add(answer);
                        return followUp?.call(answer);
                      },
                      onUseLocation: onUseLocation,
                    ),
                  );
                  closed = true;
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  Finder row(String label) => find.text(label);
  Finder send() => find.text(SaverSurveyCopy.sendLabel);

  testWidgets('names the cafe and shows every reason, no text field', (
    tester,
  ) async {
    await open(tester);
    expect(find.text(SaverSurveyCopy.title), findsOneWidget);
    expect(
      find.textContaining('You saved Brew Szn 9 days ago.', findRichText: true),
      findsOneWidget,
    );
    for (final r in SaverSurveyCopy.reasons) {
      expect(row(r.label), findsOneWidget);
    }
    await tester.tap(row(SaverSurveyCopy.other.label));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('Send does nothing until something is picked', (tester) async {
    await open(tester);
    await tester.tap(send());
    await tester.pumpAndSettle();
    expect(closed, isFalse);
    expect(sent, isEmpty);
  });

  testWidgets('a third pick replaces the oldest; sent in list order', (
    tester,
  ) async {
    await open(tester);
    await tester.tap(row('Too far from me'));
    await tester.tap(row("Haven't had time"));
    await tester.pump();
    await tester.tap(row('Found somewhere else')); // replaces "Too far"
    await tester.pump();
    await tester.tap(send());
    await tester.pumpAndSettle();
    expect(sent.single.reasons, ['no_time', 'found_elsewhere']);
    expect(sent.single.analytics(), {
      'reasons': ['no_time', 'found_elsewhere'],
    });
    // No card: the sheet closed.
    expect(closed, isTrue);
    expect(result, isNull);
  });

  testWidgets('Skip resolves null without sending', (tester) async {
    await open(tester);
    await tester.tap(find.text(SaverSurveyCopy.skipLabel));
    await tester.pumpAndSettle();
    expect(closed, isTrue);
    expect(result, isNull);
    expect(sent, isEmpty);
  });

  testWidgets('open state card: today\'s hours, See cafe', (tester) async {
    await open(
      tester,
      followUp: (_) =>
          SaverSurveyFollowUp(SaverSurveyFollowUpKind.openState, cafe: brew),
    );
    await tester.tap(row("Not sure it's open"));
    await tester.pump();
    await tester.tap(send());
    await tester.pumpAndSettle();
    expect(sent, hasLength(1));
    expect(closed, isFalse);
    expect(find.text(SaverSurveyCopy.thanks), findsOneWidget);
    expect(find.text('Brew Szn'), findsOneWidget);
    expect(find.text('Open until 9 PM'), findsOneWidget);
    await tester.tap(find.text('See cafe'));
    await tester.pumpAndSettle();
    expect(result!.action, SaverSurveyActions.seeCafe);
    expect(result!.followUp.cafe, brew);
  });

  testWidgets('no hours: says so', (tester) async {
    await open(
      tester,
      followUp: (_) => const SaverSurveyFollowUp(
        SaverSurveyFollowUpKind.openState,
        cafe: CafeSnapshot(id: 'x', name: 'Quiet'),
      ),
    );
    await tester.tap(row("Not sure it's open"));
    await tester.pump();
    await tester.tap(send());
    await tester.pumpAndSettle();
    expect(find.text('No hours listed yet'), findsOneWidget);
  });

  testWidgets('nearest card leads with the distance', (tester) async {
    await open(
      tester,
      followUp: (_) => SaverSurveyFollowUp(
        SaverSurveyFollowUpKind.nearest,
        cafe: brew,
        distanceMeters: 1240,
      ),
    );
    await tester.tap(row('Too far from me'));
    await tester.pump();
    await tester.tap(send());
    await tester.pumpAndSettle();
    expect(find.text('1.2 km away · Open until 9 PM'), findsOneWidget);
  });

  testWidgets('location card: Use my location swaps to the nearest', (
    tester,
  ) async {
    await open(
      tester,
      followUp: (_) =>
          const SaverSurveyFollowUp(SaverSurveyFollowUpKind.locationAsk),
      onUseLocation: () async => SaverSurveyFollowUp(
        SaverSurveyFollowUpKind.nearest,
        cafe: brew,
        distanceMeters: 800,
      ),
    );
    await tester.tap(row('Too far from me'));
    await tester.pump();
    await tester.tap(send());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Use my location'));
    await tester.pumpAndSettle();
    expect(closed, isFalse);
    expect(find.text('800 m away · Open until 9 PM'), findsOneWidget);
  });

  testWidgets('share and later cards; close pops null', (tester) async {
    await open(
      tester,
      followUp: (a) => a.reasons.contains('waiting_for_friend')
          ? SaverSurveyFollowUp(SaverSurveyFollowUpKind.share, cafe: brew)
          : const SaverSurveyFollowUp(SaverSurveyFollowUpKind.later),
    );
    await tester.tap(row('Saving it for later'));
    await tester.pump();
    await tester.tap(send());
    await tester.pumpAndSettle();
    expect(find.text("It'll stay in Your places."), findsOneWidget);
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(closed, isTrue);
    expect(result, isNull);

    await open(
      tester,
      followUp: (_) =>
          SaverSurveyFollowUp(SaverSurveyFollowUpKind.share, cafe: brew),
    );
    await tester.tap(row('Waiting for a friend'));
    await tester.pump();
    await tester.tap(send());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Share'));
    await tester.pumpAndSettle();
    expect(result!.action, SaverSurveyActions.share);
  });

  testWidgets('fits at text scale 2.0 without overflow, both faces', (
    tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await open(
      tester,
      followUp: (_) => SaverSurveyFollowUp(
        SaverSurveyFollowUpKind.nearest,
        cafe: brew,
        distanceMeters: 1240,
      ),
    );
    expect(tester.takeException(), isNull);
    expect(send(), findsOneWidget);
    await tester.ensureVisible(row('Too far from me'));
    await tester.tap(row('Too far from me'));
    await tester.pump();
    await tester.tap(send());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('See cafe'), findsOneWidget);
  });
}
