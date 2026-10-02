import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:nook/core/location/device_location.dart';

Position _at(double lat) => Position(
  latitude: lat,
  longitude: 123.9,
  timestamp: DateTime(2026, 10, 3),
  accuracy: 10,
  altitude: 0,
  altitudeAccuracy: 0,
  heading: 0,
  headingAccuracy: 0,
  speed: 0,
  speedAccuracy: 0,
);

void main() {
  late DateTime now;
  late List<Position?> answers;
  late int reads;
  late DeviceLocation location;

  setUp(() {
    now = DateTime(2026, 10, 3, 9);
    answers = [];
    reads = 0;
    location = DeviceLocation.test(
      fetch: () async {
        reads++;
        return answers.isEmpty ? null : answers.removeAt(0);
      },
      now: () => now,
    );
  });

  test('a fresh position is served without asking the device again', () async {
    answers = [_at(10.30)];

    expect((await location.ensure())!.latitude, 10.30);
    now = now.add(const Duration(seconds: 30));
    expect((await location.ensure())!.latitude, 10.30);

    expect(reads, 1);
  });

  test(
    'a position past its max age is re-read behind the cached one',
    () async {
      answers = [_at(10.30), _at(10.35)];
      await location.ensure();

      now = now.add(const Duration(minutes: 5));
      // Nothing waits on GPS: the old position comes back at once...
      expect((await location.ensure())!.latitude, 10.30);
      await pumpEventQueue();

      // ...and the new one lands in the notifier.
      expect(reads, 2);
      expect(location.position.value!.latitude, 10.35);
    },
  );

  test(
    'forceRefresh waits for a new read even when the cache is fresh',
    () async {
      answers = [_at(10.30), _at(10.35)];
      await location.ensure();

      final fresh = await location.ensure(forceRefresh: true);

      expect(fresh!.latitude, 10.35);
      expect(reads, 2);
    },
  );

  test('a caller can ask for a tighter max age', () async {
    answers = [_at(10.30), _at(10.35)];
    await location.ensure();

    now = now.add(const Duration(seconds: 20));
    await location.ensure(maxAge: const Duration(seconds: 10));
    await pumpEventQueue();

    expect(location.position.value!.latitude, 10.35);
  });

  test(
    'a failed re-read keeps the last position and is not retried at once',
    () async {
      answers = [_at(10.30), null];
      await location.ensure();

      now = now.add(const Duration(minutes: 5));
      expect((await location.ensure(forceRefresh: true))!.latitude, 10.30);
      expect((await location.ensure())!.latitude, 10.30);
      await pumpEventQueue();

      expect(reads, 2);
    },
  );

  test('concurrent callers share one read', () async {
    final gate = Completer<Position?>();
    final shared = DeviceLocation.test(
      fetch: () {
        reads++;
        return gate.future;
      },
    );

    final first = shared.ensure();
    final second = shared.ensure(forceRefresh: true);
    gate.complete(_at(10.30));

    expect((await first)!.latitude, 10.30);
    expect((await second)!.latitude, 10.30);
    expect(reads, 1);
  });

  test('with no position yet, every call asks again', () async {
    expect(await location.ensure(), isNull);
    answers = [_at(10.30)];
    expect((await location.ensure())!.latitude, 10.30);
    expect(reads, 2);
  });

  test('a throwing source reads as no position', () async {
    final broken = DeviceLocation.test(
      fetch: () async => throw TimeoutException('gps'),
    );

    expect(await broken.ensure(), isNull);
  });
}
