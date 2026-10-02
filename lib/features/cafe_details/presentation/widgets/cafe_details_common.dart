import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:nook/core/location/device_location.dart';
import 'package:nook/core/presentation/widgets/cafe_distance_label.dart';
import 'package:nook/features/cafe_details/presentation/utils/cafe_open_status.dart';

/// Colours and small pieces shared by the cafe details sections.
class CafeDetailsTokens {
  const CafeDetailsTokens._();

  static const ink = Color(0xFF0A0F0D);
  static const muted = Color(0xFF767574);
  static const brand = Color(0xFF344E41);
  static const border = Color(0xFFE0E0E0);
  static const tint = Color(0xFFEEEEEE);
  static const openDot = Color(0xFF0F893E);
  static const closed = Color(0xFFB3261E);
  static const star = Color(0xFF588157);

  /// Amber for "Opens soon" / "Closes soon".
  static const soon = Color(0xFFA15C00);

  /// Colour of the status word ("Open", "Closed", "Closes soon").
  static Color statusLabel(CafeOpenStatus status) {
    if (status.isSoon) return soon;
    return status.isOpen ? brand : closed;
  }

  /// Colour of the dot in front of the status.
  static Color statusDot(CafeOpenStatus status) {
    if (status.isSoon) return soon;
    return status.isOpen ? openDot : closed;
  }

  /// Page gutter, matching the rest of the details page.
  static const gutter = 22.0;
}

/// A section heading ("Amenities", "Hours & location").
class CafeSectionTitle extends StatelessWidget {
  const CafeSectionTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: CafeDetailsTokens.ink,
      ),
    );
  }
}

/// The hairline between sections.
class CafeSectionDivider extends StatelessWidget {
  const CafeSectionDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(
        horizontal: CafeDetailsTokens.gutter,
        vertical: 20,
      ),
      child: Divider(height: 1, thickness: 1, color: CafeDetailsTokens.border),
    );
  }
}

/// Resolves the distance from the device to a point and hands the formatted
/// text ("2.1 km") to [builder]; null until there is a fix, or when the
/// reading is not worth showing.
///
/// Measured from [DeviceLocation] like every other distance in the app.
class CafeDistanceBuilder extends StatefulWidget {
  const CafeDistanceBuilder({
    super.key,
    required this.lat,
    required this.lng,
    required this.builder,
  });

  final double? lat;
  final double? lng;
  final Widget Function(BuildContext context, String? distance) builder;

  @override
  State<CafeDistanceBuilder> createState() => _CafeDistanceBuilderState();
}

class _CafeDistanceBuilderState extends State<CafeDistanceBuilder> {
  String? _distance;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(covariant CafeDistanceBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.lat != widget.lat || oldWidget.lng != widget.lng) _resolve();
  }

  Future<void> _resolve() async {
    final lat = widget.lat, lng = widget.lng;
    if (lat == null || lng == null) return;
    final position = await DeviceLocation.instance.ensure();
    if (position == null || !mounted) return;
    final text = formatDistanceMeters(
      Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        lat,
        lng,
      ),
    );
    if (mounted) setState(() => _distance = text);
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _distance);
}
