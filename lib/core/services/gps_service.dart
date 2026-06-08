import 'dart:async';

import 'package:geolocator/geolocator.dart';

class GpsResult {
  final Position? position;
  final bool denied;
  final bool timeout;

  const GpsResult({this.position, this.denied = false, this.timeout = false});
}

abstract class GpsService {
  Future<GpsResult> getCurrentPosition({
    Duration timeout = const Duration(seconds: 10),
  });

  Future<bool> requestPermission();

  Future<bool> isLocationEnabled();
}

class GpsServiceImpl implements GpsService {
  @override
  Future<GpsResult> getCurrentPosition({Duration timeout = const Duration(seconds: 10)}) async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return const GpsResult(denied: true);

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return const GpsResult(denied: true);
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 0,
        ),
      ).timeout(
        timeout,
        onTimeout: () => throw TimeoutException('GPS acquisition timed out'),
      );

      return GpsResult(position: position);
    } on TimeoutException {
      return const GpsResult(timeout: true);
    } catch (e) {
      return const GpsResult(denied: true);
    }
  }

  @override
  Future<bool> requestPermission() async {
    final permission = await Geolocator.requestPermission();
    return permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always;
  }

  @override
  Future<bool> isLocationEnabled() async {
    return Geolocator.isLocationServiceEnabled();
  }
}
