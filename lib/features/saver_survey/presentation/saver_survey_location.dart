import 'dart:async';

import 'package:geolocator/geolocator.dart';
import 'package:nook/core/location/device_location.dart';
import 'package:nook/core/location/location_prompt_tracking.dart';
import 'package:nook/core/preferences/location_prompt_store.dart';
import 'package:nook/injection_container.dart';

typedef SurveyPosition = ({double lat, double lng});

/// Where the saver survey's "Too far from me" follow-up measures from.
/// Never wakes the GPS on its own: only the position the app already has,
/// or the phone's last known one. Asking goes through the same system
/// prompt, store and logging as Home's ask, and only on a tap.
class SaverSurveyLocation {
  SaverSurveyLocation({LocationPromptStore? promptStore})
    : _promptStore =
          promptStore ??
          (sl.isRegistered<LocationPromptStore>()
              ? sl<LocationPromptStore>()
              : LocationPromptStore());

  final LocationPromptStore _promptStore;

  /// The last position, when location is allowed and one is cached.
  Future<SurveyPosition?> lastPosition() async {
    try {
      final access = await DeviceLocation.instance.access();
      if (access.servicesOff || access.denied) return null;
      final p =
          DeviceLocation.instance.position.value ??
          await Geolocator.getLastKnownPosition();
      return p == null ? null : (lat: p.latitude, lng: p.longitude);
    } catch (_) {
      return null;
    }
  }

  /// Whether the system prompt may still be shown: services on, permission
  /// not yet given or refused for good, and not asked before from anywhere
  /// (the rule Home and Map follow).
  Future<bool> canAsk() async {
    try {
      final access = await DeviceLocation.instance.access();
      if (access.servicesOff || !access.denied || access.deniedForever) {
        return false;
      }
      return !await _promptStore.hasRequested();
    } catch (_) {
      return false;
    }
  }

  /// Shows the system prompt; on a yes, a position (a short wait for a fix
  /// is fine here, the person asked for it). Null when refused or no fix.
  Future<SurveyPosition?> ask() async {
    try {
      await _promptStore.markRequested();
      final answer = await LocationPromptTracker(
        LocationPromptSurface.saverSurvey,
      ).request();
      if (answer != LocationPermission.always &&
          answer != LocationPermission.whileInUse) {
        return null;
      }
      final p = await DeviceLocation.instance
          .ensure(forceRefresh: true)
          .timeout(const Duration(seconds: 5), onTimeout: () => null);
      return p == null ? null : (lat: p.latitude, lng: p.longitude);
    } catch (_) {
      return null;
    }
  }
}
