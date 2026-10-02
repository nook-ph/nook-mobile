import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

/// Why there may be no position: [servicesOff] is the phone-wide Location
/// Services switch, [denied] any permission state that rules a fix out, and
/// [deniedForever] the one only the system settings can undo.
typedef LocationAccess = ({bool servicesOff, bool denied, bool deniedForever});

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
  DeviceLocation._();

  static final DeviceLocation instance = DeviceLocation._();

  /// Null until a fix is resolved, or if location is off/denied.
  final ValueNotifier<Position?> position = ValueNotifier<Position?>(null);

  Future<Position?>? _inFlight;

  /// Resolves a position once and caches it. Safe to call from every widget
  /// build — concurrent callers share the same request, and a resolved
  /// position short-circuits.
  Future<Position?> ensure() {
    if (position.value != null) return Future.value(position.value);
    return _inFlight ??= _resolve()..whenComplete(() => _inFlight = null);
  }

  /// The first position there is: the cached one, else the device's last
  /// known one, else a fresh fix. A screen that only needs "roughly here" to
  /// start a query should wait on this rather than on [ensure], which holds
  /// out for the fresh fix.
  ///
  /// With a position already cached this answers at once and refreshes the
  /// cache behind it, so the next caller measures from where the device is
  /// now.
  Future<Position?> first() {
    final known = position.value;
    if (known != null) {
      _inFlight ??= _resolve()..whenComplete(() => _inFlight = null);
      return Future.value(known);
    }

    final completer = Completer<Position?>();
    void onPosition() {
      if (!completer.isCompleted && position.value != null) {
        completer.complete(position.value);
      }
    }

    position.addListener(onPosition);
    ensure().then((resolved) {
      position.removeListener(onPosition);
      if (!completer.isCompleted) completer.complete(resolved);
    });
    return completer.future;
  }

  /// Whether a position can be asked for at all. Answers in a few
  /// milliseconds and never prompts.
  Future<LocationAccess> access() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return (servicesOff: true, denied: false, deniedForever: false);
      }
      final permission = await Geolocator.checkPermission();
      return (
        servicesOff: false,
        denied:
            permission == LocationPermission.denied ||
            permission == LocationPermission.deniedForever ||
            permission == LocationPermission.unableToDetermine,
        deniedForever: permission == LocationPermission.deniedForever,
      );
    } catch (_) {
      return (servicesOff: false, denied: true, deniedForever: false);
    }
  }

  Future<Position?> _resolve() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return null;

      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever ||
          permission == LocationPermission.unableToDetermine) {
        return null;
      }

      // Last known first so a distance can appear immediately, then upgrade to
      // a real fix when one arrives.
      final cached = await Geolocator.getLastKnownPosition();
      if (cached != null) position.value = cached;

      final fresh = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
        ),
      ).timeout(const Duration(seconds: 3));
      position.value = fresh;
      return fresh;
    } catch (_) {
      // Denied, disabled, or timed out — callers render no distance at all,
      // which is the honest answer.
      return position.value;
    }
  }
}
