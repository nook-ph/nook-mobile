import 'package:geolocator/geolocator.dart';
import 'package:nook/core/location/device_location.dart';
import 'package:nook/core/preferences/location_prompt_store.dart';

/// Whether search can measure from the phone.
enum SearchLocationStatus {
  /// Permission is granted and Location Services are on.
  available,

  /// The system prompt has not been shown yet.
  notAsked,

  /// Denied (once or for good), or Location Services are off for the phone.
  off,
}

/// The phone's position, when there is one, and why not when there is none.
typedef SearchLocation = ({
  double? lat,
  double? lng,
  SearchLocationStatus status,
});

typedef SearchLocationResolver = Future<SearchLocation> Function();

/// Reads the app-wide cached position (a fresh GPS fix per keystroke batch
/// held every search for up to 3 s), and the permission state behind a
/// missing one.
Future<SearchLocation> resolveSearchLocation() async {
  try {
    final position = await DeviceLocation.instance.ensure();
    if (position != null) {
      return (
        lat: position.latitude,
        lng: position.longitude,
        status: SearchLocationStatus.available,
      );
    }
    return (lat: null, lng: null, status: await searchLocationStatus());
  } catch (_) {
    return (lat: null, lng: null, status: SearchLocationStatus.available);
  }
}

/// Android reports "denied" both before the first prompt and after one
/// refusal, so the prompt store tells the two apart.
Future<SearchLocationStatus> searchLocationStatus({
  LocationPromptStore? promptStore,
}) async {
  if (!await Geolocator.isLocationServiceEnabled()) {
    return SearchLocationStatus.off;
  }
  final permission = await Geolocator.checkPermission();
  return switch (permission) {
    LocationPermission.always ||
    LocationPermission.whileInUse => SearchLocationStatus.available,
    LocationPermission.deniedForever => SearchLocationStatus.off,
    LocationPermission.denied || LocationPermission.unableToDetermine =>
      await (promptStore ?? LocationPromptStore()).hasRequested()
          ? SearchLocationStatus.off
          : SearchLocationStatus.notAsked,
  };
}

/// "Use my location" / "Turn on": the shortest way to a position from where
/// the phone is now. Shows the system prompt while it still can, otherwise
/// opens the settings screen that holds the switch.
Future<void> turnOnSearchLocation({LocationPromptStore? promptStore}) async {
  try {
    if (!await Geolocator.isLocationServiceEnabled()) {
      await Geolocator.openLocationSettings();
      return;
    }
    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.deniedForever) {
      await Geolocator.openAppSettings();
      return;
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.unableToDetermine) {
      await (promptStore ?? LocationPromptStore()).markRequested();
      await Geolocator.requestPermission();
    }
  } catch (_) {
    // Best-effort: the row keeps saying location is off.
  }
}
