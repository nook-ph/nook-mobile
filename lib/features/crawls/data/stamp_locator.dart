import 'dart:async';

import 'package:geolocator/geolocator.dart';
import 'package:nook/features/crawls/domain/entities/crawl_exception.dart';

/// A position good enough to claim a stamp with.
class StampFix {
  final double lat;
  final double lng;
  final double accuracyMeters;

  const StampFix({
    required this.lat,
    required this.lng,
    required this.accuracyMeters,
  });
}

abstract class IStampLocator {
  /// A fresh, high-accuracy fix. Throws [StampLocationUnavailable].
  Future<StampFix> currentFix();
}

/// Deliberately separate from `DeviceLocation`, which is tuned for display
/// distances (medium accuracy, cached, 3 s timeout). A stamp is verified
/// against this fix, so it must be fresh and as precise as the device allows.
class GeolocatorStampLocator implements IStampLocator {
  const GeolocatorStampLocator();

  static const _timeout = Duration(seconds: 12);

  @override
  Future<StampFix> currentFix() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const StampLocationUnavailable(LocationProblem.serviceOff);
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      throw const StampLocationUnavailable(LocationProblem.deniedForever);
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.unableToDetermine) {
      throw const StampLocationUnavailable(LocationProblem.denied);
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      ).timeout(_timeout);
      return StampFix(
        lat: position.latitude,
        lng: position.longitude,
        accuracyMeters: position.accuracy,
      );
    } on TimeoutException {
      throw const StampLocationUnavailable(LocationProblem.timeout);
    }
  }
}
