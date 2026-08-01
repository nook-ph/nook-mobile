import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:nook/core/location/device_location.dart';

/// Formats a distance for display, or null when it shouldn't be shown.
///
/// Nook covers one metro. A reading in the thousands of kilometres means a
/// stale or wrong fix, not a useful fact about the cafe — the emulator's US
/// location rendered "11356.6 km" beside a Cebu cafe as though a user might
/// act on it. Beyond the bound we show nothing rather than something false.
String? formatDistanceMeters(double meters) {
  const maxDisplayMeters = 300000; // 300 km — well past the far end of Cebu.
  if (meters.isNaN || meters.isNegative || meters > maxDisplayMeters) {
    return null;
  }
  if (meters < 1000) return '${meters.round()} m';
  return '${(meters / 1000).toStringAsFixed(1)} km';
}

/// Distance from the device to a cafe. Renders nothing without a fix.
///
/// Always measured from [DeviceLocation], never from the map camera — see that
/// class for why the app had three different answers before.
class CafeDistanceLabel extends StatefulWidget {
  const CafeDistanceLabel({
    super.key,
    required this.lat,
    required this.lng,
    this.style,
  });

  final double? lat;
  final double? lng;
  final TextStyle? style;

  @override
  State<CafeDistanceLabel> createState() => _CafeDistanceLabelState();
}

class _CafeDistanceLabelState extends State<CafeDistanceLabel> {
  @override
  void initState() {
    super.initState();
    DeviceLocation.instance.ensure();
  }

  @override
  Widget build(BuildContext context) {
    final lat = widget.lat;
    final lng = widget.lng;
    if (lat == null || lng == null) return const SizedBox.shrink();

    return ValueListenableBuilder<Position?>(
      valueListenable: DeviceLocation.instance.position,
      builder: (context, position, _) {
        if (position == null) return const SizedBox.shrink();
        final text = formatDistanceMeters(
          Geolocator.distanceBetween(
            position.latitude,
            position.longitude,
            lat,
            lng,
          ),
        );
        if (text == null) return const SizedBox.shrink();
        return Text(text, style: widget.style);
      },
    );
  }
}
