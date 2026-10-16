import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/features/saver_survey/domain/saver_survey_reasons.dart';
import 'package:nook/features/saver_survey/presentation/saver_survey_sheet.dart';

void main() {
  late SaverSurveyAnswer? result;
  late bool closed;

  Future<void> open(WidgetTester tester) async {
    closed = false;
    result = null;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () async {
                  result = await showSaverSurveySheet(context);
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

  testWidgets('shows the question and every reason', (tester) async {
    await open(tester);
    expect(find.text(SaverSurveyCopy.title), findsOneWidget);
    for (final r in SaverSurveyCopy.reasons) {
      expect(row(r.label), findsOneWidget);
    }
  });

  testWidgets('Send does nothing until something is picked', (tester) async {
    await open(tester);
    await tester.tap(send());
    await tester.pumpAndSettle();
    expect(closed, isFalse);
  });

  testWidgets('at most two picks; Send returns them in list order', (
    tester,
  ) async {
    await open(tester);
    await tester.tap(row('Too far from me'));
    await tester.tap(row("Haven't had time"));
    await tester.pump();
    await tester.tap(row('Found somewhere else')); // a third: ignored
    await tester.pump();
    await tester.tap(send());
    await tester.pumpAndSettle();
    expect(result!.reasons, ['no_time', 'too_far']);
    expect(result!.analytics()['other_text_present'], false);
  });

  testWidgets('Something else opens a field; only its length is sent', (
    tester,
  ) async {
    await open(tester);
    expect(find.byType(TextField), findsNothing);
    await tester.tap(row(SaverSurveyCopy.other.label));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '  Parking is hard  ');
    await tester.tap(send());
    await tester.pumpAndSettle();
    expect(result!.reasons, ['other']);
    expect(result!.otherText, 'Parking is hard');
    final props = result!.analytics();
    expect(props['other_text_present'], true);
    expect(props['other_text_length'], '1_20');
    expect(
      props.values.whereType<String>(),
      isNot(contains('Parking is hard')),
    );
  });

  testWidgets('the field stops at 120 characters', (tester) async {
    await open(tester);
    await tester.tap(row(SaverSurveyCopy.other.label));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'a' * 200);
    await tester.tap(send());
    await tester.pumpAndSettle();
    expect(result!.otherText.length, SaverSurveyCopy.maxOtherLength);
  });

  testWidgets('Skip resolves null', (tester) async {
    await open(tester);
    await tester.tap(find.text(SaverSurveyCopy.skipLabel));
    await tester.pumpAndSettle();
    expect(closed, isTrue);
    expect(result, isNull);
  });

  testWidgets('fits at text scale 2.0 without overflow', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await open(tester);
    expect(tester.takeException(), isNull);
    expect(send(), findsOneWidget);
  });
}
