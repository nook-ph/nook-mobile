import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:nook/core/analytics/retention_tracking_events.dart';
import 'package:nook/core/location/location_prompt_tracking.dart';

import '../analytics/recording_analytics.dart';

void main() {
  late RecordingAnalytics analytics;

  setUp(() => analytics = RecordingAnalytics.install(addTearDown));

  test('maps every permission to a result value', () {
    expect(locationPermissionResult(LocationPermission.always), 'granted');
    expect(
      locationPermissionResult(LocationPermission.whileInUse),
      'while_in_use',
    );
    expect(locationPermissionResult(LocationPermission.denied), 'denied');
    expect(
      locationPermissionResult(LocationPermission.deniedForever),
      'denied_forever',
    );
    expect(
      locationPermissionResult(LocationPermission.unableToDetermine),
      'unavailable',
    );
  });

  test('request logs shown then the answer, once each', () async {
    final prompt = LocationPromptTracker(
      LocationPromptSurface.home,
      requestPermission: () async => LocationPermission.whileInUse,
    );

    prompt.shown();
    final answer = await prompt.request();
    prompt.result('denied');

    expect(answer, LocationPermission.whileInUse);
    expect(analytics.names, [
      LocationPromptEvents.shown,
      LocationPromptEvents.result,
    ]);
    expect(analytics.propertiesOf(LocationPromptEvents.shown), {
      'surface': 'home',
    });
    expect(analytics.propertiesOf(LocationPromptEvents.result), {
      'surface': 'home',
      'result': 'while_in_use',
      'system_prompt': true,
    });
  });

  test('a result without shown logs shown first', () {
    LocationPromptTracker(
      LocationPromptSurface.map,
    ).result('denied', systemPrompt: false);

    expect(analytics.names, [
      LocationPromptEvents.shown,
      LocationPromptEvents.result,
    ]);
    expect(
      analytics.propertiesOf(LocationPromptEvents.result)?['system_prompt'],
      false,
    );
  });

  test('a platform error logs unavailable and rethrows', () async {
    final prompt = LocationPromptTracker(
      LocationPromptSurface.mapFab,
      requestPermission: () async => throw Exception('busy'),
    );

    await expectLater(prompt.request(), throwsException);

    expect(analytics.propertiesOf(LocationPromptEvents.result), {
      'surface': 'map_fab',
      'result': 'unavailable',
      'system_prompt': true,
    });
  });
}
