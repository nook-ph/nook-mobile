import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

/// One device position for the whole app to measure from.
///
/// Distances used to come from three different origins: map and search cards
/// showed the server's `distance_meters`, computed from the **map camera
/// centre**, so "5.8 km" silently changed as you panned; home cards used the
/// device position; and the details header computed its own from
/// `getLastKnownPosition`. Same cafe, three different numbers, all labelled
/// the same way.
///
/// The map still anchors its *query* on the viewport — that is what "cafes in
/// view" means — but nothing displayed to the user is measured from it any
/// more. This is the single origin for anything with "km" next to it.
class DeviceLocation {
  DeviceLocation._() : _fetch = null, _now = DateTime.now;

  /// A standalone instance over a fake position source and clock.
  @visibleForTesting
  DeviceLocation.test({
    required Future<Position?> Function() fetch,
    DateTime Function() now = DateTime.now,
  }) : _fetch = fetch,
       _now = now;

  static final DeviceLocation instance = DeviceLocation._();

  /// How long a resolved position is served before [ensure] looks again.
  /// Short enough that a walk between two cafes is noticed, long enough that
  /// a screen full of distance labels shares one read.
  static const Duration defaultMaxAge = Duration(minutes: 1);

  /// Null until a fix is resolved, or if location is off/denied.
  final ValueNotifier<Position?> position = ValueNotifier<Position?>(null);

  final Future<Position?> Function()? _fetch;
  final DateTime Function() _now;

  Future<Position?>? _inFlight;

  /// When the device was last asked, whether or not it answered. A failed
  /// read counts, so a phone with no fix is not asked again on every build.
  DateTime? _checkedAt;

  /// Resolves a position and caches it. Safe to call from every widget
  /// build — concurrent callers share the same request, and a position
  /// younger than [maxAge] short-circuits.
  ///
  /// An older position is still returned at once, so nothing waits on GPS,
  /// while a new read runs behind it and lands in [position]. Pass
  /// [forceRefresh] to wait for that read instead: on resume, on
  /// pull-to-refresh, and wherever "am I at this cafe" has to be current.
  Future<Position?> ensure({
    Duration maxAge = defaultMaxAge,
    bool forceRefresh = false,
  }) {
    final cached = position.value;
    if (cached == null || forceRefresh) return _refresh();

    final checkedAt = _checkedAt;
    if (checkedAt == null || _now().difference(checkedAt) > maxAge) {
      unawaited(_refresh());
    }
    return Future.value(cached);
  }

  Future<Position?> _refresh() {
    return _inFlight ??= _resolve()..whenComplete(() => _inFlight = null);
  }

  Future<Position?> _resolve() async {
    try {
      final fresh = await (_fetch ?? _fetchFromDevice)();
      if (fresh != null) position.value = fresh;
    } catch (_) {
      // Denied, disabled, or timed out — callers render no distance at all,
      // which is the honest answer.
    }
    _checkedAt = _now();
    return position.value;
  }

  Future<Position?> _fetchFromDevice() async {
    if (!await Geolocator.isLocationServiceEnabled()) return null;

    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever ||
        permission == LocationPermission.unableToDetermine) {
      return null;
    }

    // Last known first so a distance can appear immediately, then upgrade to
    // a real fix when one arrives.
    if (position.value == null) {
      final cached = await Geolocator.getLastKnownPosition();
      if (cached != null) position.value = cached;
    }

    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.medium,
      ),
    ).timeout(const Duration(seconds: 3));
  }
}
