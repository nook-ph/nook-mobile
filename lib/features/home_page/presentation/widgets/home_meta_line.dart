import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:nook/core/cafe/domain/entities/cafe_summary.dart';
import 'package:nook/core/extensions/extensions.dart';
import 'package:nook/core/location/device_location.dart';
import 'package:nook/core/presentation/widgets/cafe_distance_label.dart';

/// The short place name a compact card leads its meta line with: the
/// neighbourhood, else the city, else whatever address there is.
String homeCardArea(CafeSummary cafe) {
  for (final part in [cafe.neighborhood, cafe.city, cafe.address]) {
    final trimmed = part?.trim() ?? '';
    if (trimmed.isNotEmpty) return trimmed;
  }
  return '';
}

/// "IT Park · 492 m". Either half is dropped when it is unknown, so a card
/// without a position reads "IT Park" rather than ending in a dangling dot.
String homeMetaText(String area, String? distance) {
  final parts = [
    area.trim(),
    distance?.trim() ?? '',
  ].where((part) => part.isNotEmpty);
  return parts.join(' · ');
}

/// Where a cafe is and how far, on one line. The distance is measured from
/// the device (see [DeviceLocation]) and disappears without a fix.
class HomeMetaLine extends StatefulWidget {
  const HomeMetaLine({super.key, required this.area, this.lat, this.lng});

  final String area;
  final double? lat;
  final double? lng;

  @override
  State<HomeMetaLine> createState() => _HomeMetaLineState();
}

class _HomeMetaLineState extends State<HomeMetaLine> {
  @override
  void initState() {
    super.initState();
    DeviceLocation.instance.ensure();
  }

  String? _distance(Position? position) {
    final lat = widget.lat;
    final lng = widget.lng;
    if (position == null || lat == null || lng == null) return null;
    return formatDistanceMeters(
      Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        lat,
        lng,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Position?>(
      valueListenable: DeviceLocation.instance.position,
      builder: (context, position, _) {
        return Text(
          homeMetaText(widget.area, _distance(position)),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: context.textTheme.bodySmall?.copyWith(
            color: context.colorScheme.gray,
            fontSize: 12,
            height: 1.5,
          ),
        );
      },
    );
  }
}
