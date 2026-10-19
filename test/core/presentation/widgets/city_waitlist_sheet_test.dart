import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/core/analytics/retention_tracking_events.dart';
import 'package:nook/core/presentation/widgets/city_waitlist_sheet.dart';

import '../../analytics/recording_analytics.dart';

Widget _app() => MaterialApp(
  home: Scaffold(
    body: Builder(
      builder: (context) => Center(
        child: TextButton(
          onPressed: () => requestCityWaitlist(context, surface: 'map'),
          child: const Text('ask'),
        ),
      ),
    ),
  ),
);

void main() {
  late RecordingAnalytics analytics;

  setUp(() => analytics = RecordingAnalytics.install(addTearDown));

  test('clean trims, single-spaces and caps the city', () {
    expect(CityWaitlistSheet.clean('  Cagayan   de  Oro '), 'Cagayan de Oro');
    expect(CityWaitlistSheet.clean('x' * 80).length, 60);
    expect(CityWaitlistSheet.clean('   '), '');
  });

  test('analyticsCity sends the canonical name of a matched city', () {
    expect(CityWaitlistSheet.analyticsCity('davao'), 'Davao');
    expect(CityWaitlistSheet.analyticsCity(' Iloilo City '), 'Iloilo');
    expect(CityWaitlistSheet.analyticsCity('DUMAGUETE'), 'Dumaguete');
    expect(CityWaitlistSheet.analyticsCity('Paranaque'), 'Parañaque');
    // An n typed with a separate tilde, and stray punctuation.
    expect(CityWaitlistSheet.analyticsCity('Paran\u0303aque'), 'Parañaque');
    expect(CityWaitlistSheet.analyticsCity('Davao!'), 'Davao');
    expect(CityWaitlistSheet.analyticsCity('"QC"'), 'Quezon City');
    // With a province or the country after it.
    expect(CityWaitlistSheet.analyticsCity('Davao City, Philippines'), 'Davao');
    expect(CityWaitlistSheet.analyticsCity('Iloilo City, Iloilo'), 'Iloilo');
    expect(CityWaitlistSheet.analyticsCity('Manila PH'), 'Manila');
    expect(CityWaitlistSheet.analyticsCity('Cebu City'), 'Cebu');
    expect(CityWaitlistSheet.analyticsCity('Lapu Lapu'), 'Lapu-Lapu');
    // Still nothing typed is sent.
    expect(CityWaitlistSheet.analyticsCity('12 Rizal St, Davao'), 'other');
    expect(CityWaitlistSheet.analyticsCity('parañaque city'), 'Parañaque');
    expect(CityWaitlistSheet.analyticsCity('City of Makati'), 'Makati');
    expect(CityWaitlistSheet.analyticsCity('quezon  city'), 'Quezon City');
    expect(CityWaitlistSheet.analyticsCity('QC'), 'Quezon City');
    expect(CityWaitlistSheet.analyticsCity('cdo'), 'Cagayan de Oro');
    expect(CityWaitlistSheet.analyticsCity('Lapu Lapu'), 'Lapu-Lapu');
    expect(CityWaitlistSheet.analyticsCity('Gen. San.'), 'General Santos');
  });

  test('analyticsCity sends other for anything not a known city', () {
    for (final typed in [
      'Juan Dela Cruz',
      'Maria',
      'Juan Dela Cruz, juan@gmail.com, Makati',
      '0917 123 4567',
      '123 Rizal St, Makati',
      'my house near the old church plaza',
      'Springfield',
      '',
    ]) {
      expect(CityWaitlistSheet.analyticsCity(typed), CityWaitlistSheet.other);
    }
  });

  test('every suggestion is a known city sent as written', () {
    for (final city in CityWaitlistSheet.suggestions) {
      expect(CityWaitlistSheet.analyticsCity(city), city);
    }
  });

  testWidgets('a picked city is logged with its surface', (tester) async {
    await tester.pumpWidget(_app());
    await tester.tap(find.text('ask'));
    await tester.pumpAndSettle();

    expect(find.text(CityWaitlistSheet.title), findsOneWidget);
    await tester.tap(find.text('Davao'));
    await tester.pump();
    await tester.tap(find.text(CityWaitlistSheet.sendLabel));
    await tester.pumpAndSettle();

    expect(analytics.flat, [
      [
        CityWaitlistEvents.requested,
        {'city': 'Davao', 'surface': 'map'},
      ],
    ]);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  });

  testWidgets('a typed city is logged; closing without one logs nothing', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    await tester.tap(find.text('ask'));
    await tester.pumpAndSettle();

    // Send does nothing while the field is empty.
    await tester.tap(find.text(CityWaitlistSheet.sendLabel));
    await tester.pumpAndSettle();
    expect(find.text(CityWaitlistSheet.title), findsOneWidget);

    await tester.tapAt(const Offset(20, 20));
    await tester.pumpAndSettle();
    expect(analytics.events, isEmpty);

    await tester.tap(find.text('ask'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), ' Iloilo City ');
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pumpAndSettle();

    expect(analytics.propertiesOf(CityWaitlistEvents.requested), {
      'city': 'Iloilo',
      'surface': 'map',
    });
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  });

  testWidgets('a typed name that is not a city is sent as other, never raw', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    await tester.tap(find.text('ask'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Juan Dela Cruz');
    await tester.pump();
    await tester.tap(find.text(CityWaitlistSheet.sendLabel));
    await tester.pumpAndSettle();

    expect(analytics.flat, [
      [
        CityWaitlistEvents.requested,
        {'city': CityWaitlistSheet.other, 'surface': 'map'},
      ],
    ]);
    expect(analytics.flat.toString(), isNot(contains('Juan')));
    // Thanked all the same.
    expect(find.text(CityWaitlistSheet.thanks), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  });
}
