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

  test('analyticsCity sends place names, never contact details', () {
    expect(CityWaitlistSheet.analyticsCity('davao'), 'Davao');
    expect(CityWaitlistSheet.analyticsCity(' Iloilo City '), 'Iloilo City');
    expect(CityWaitlistSheet.analyticsCity('Dumaguete'), 'Dumaguete');
    expect(CityWaitlistSheet.analyticsCity('Parañaque'), 'Parañaque');
    expect(
      CityWaitlistSheet.analyticsCity('Juan Dela Cruz, juan@gmail.com, Makati'),
      CityWaitlistSheet.other,
    );
    expect(CityWaitlistSheet.analyticsCity('0917 123 4567'), 'other');
    expect(CityWaitlistSheet.analyticsCity('123 Rizal St, Makati'), 'other');
    expect(
      CityWaitlistSheet.analyticsCity('my house near the old church plaza'),
      'other',
    );
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
      'city': 'Iloilo City',
      'surface': 'map',
    });
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  });
}
