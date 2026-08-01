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
