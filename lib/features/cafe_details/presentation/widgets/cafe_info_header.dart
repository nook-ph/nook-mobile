import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:geolocator/geolocator.dart';
import 'package:nook/features/cafe_details/domain/use_cases/get_cafe_details_usecase.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:nook/utils/theme/custom_themes/text_theme.dart';
import 'package:nook/utils/theme/custom_themes/color_scheme.dart';

class CafeInfoHeader extends StatefulWidget {
  final CafeDetailsResult? cafe;
  const CafeInfoHeader({super.key, required this.cafe});

  @override
  State<CafeInfoHeader> createState() => _CafeInfoHeaderState();
}

class _CafeInfoHeaderState extends State<CafeInfoHeader> {
  double? _distanceMeters;

  static const List<String> _orderedDays = [
    'sunday',
    'monday',
    'tuesday',
    'wednesday',
    'thursday',
    'friday',
    'saturday',
  ];

  @override
  void initState() {
    super.initState();
    _fetchDistance();
  }

  @override
  void didUpdateWidget(covariant CafeInfoHeader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.cafe?.cafeDetails.id != widget.cafe?.cafeDetails.id) {
      _fetchDistance();
    }
  }

  Future<void> _fetchDistance() async {
    final cafe = widget.cafe?.cafeDetails;
    if (cafe == null) return;
    try {
      final position = await Geolocator.getLastKnownPosition();
      if (position == null) return;
      final distance = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        cafe.lat,
        cafe.lng,
      );
      if (mounted) setState(() => _distanceMeters = distance);
    } catch (_) {}
  }

  String _formatDisplayTime(TimeOfDay time) {
    final hour24 = time.hour;
    final minuteText = time.minute.toString().padLeft(2, '0');
    final period = hour24 >= 12 ? 'PM' : 'AM';
    final hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12;
    return '$hour12:$minuteText $period';
  }

  TimeOfDay? _parseTime(String? value) {
    if (value == null || value.isEmpty) return null;
    final parts = value.split(':');
    if (parts.length < 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    return TimeOfDay(hour: hour, minute: minute);
  }

  int _toMinutes(TimeOfDay time) => (time.hour * 60) + time.minute;

  String _locationText(CafeDetailsResult? cafe) {
    final details = cafe?.cafeDetails;
    if (details == null) return '';
    final parts = [details.neighborhood, details.city]
        .where((value) => value.trim().isNotEmpty)
        .map((value) => value.trim())
        .toList();
    return parts.join(', ');
  }

  ({bool isOpen, TimeOfDay? closeTime, TimeOfDay? openTime}) _buildStatus(
    Map<String, dynamic> operatingHours,
  ) {
    final now = DateTime.now();
    final nowMinutes = (now.hour * 60) + now.minute;
    final dayKey = now.weekday == DateTime.sunday
        ? 'sunday'
        : _orderedDays[now.weekday];
    final dayHoursRaw = operatingHours[dayKey];
    final dayHours = dayHoursRaw is Map
        ? Map<String, dynamic>.from(dayHoursRaw)
        : <String, dynamic>{};
    final openTime = _parseTime(dayHours['open']?.toString());
    final closeTime = _parseTime(dayHours['close']?.toString());
    if (openTime == null || closeTime == null) {
      return (isOpen: false, closeTime: null, openTime: null);
    }
    final openMinutes = _toMinutes(openTime);
    final closeMinutes = _toMinutes(closeTime);
    final isOvernight = closeMinutes <= openMinutes;
    final isOpen = isOvernight
        ? (nowMinutes >= openMinutes || nowMinutes < closeMinutes)
        : (nowMinutes >= openMinutes && nowMinutes < closeMinutes);
    return (isOpen: isOpen, closeTime: closeTime, openTime: openTime);
  }

  @override
  Widget build(BuildContext context) {
    final operatingHours = widget.cafe?.cafeDetails.operatingHours ?? {};
    final locationText = _locationText(widget.cafe);
    final status = _buildStatus(operatingHours);
    final dotColor = status.isOpen
        ? const Color(0xFF0F893E)
        : const Color(0xFFD11A17);
    final statusColor = status.isOpen
        ? const Color(0xFF344E41)
        : const Color(0xFFDD5C5C);
    final statusText = status.isOpen ? 'OPEN NOW' : 'CLOSED';
    final statusDetail = status.isOpen
        ? (status.closeTime != null
              ? 'Closes at ${_formatDisplayTime(status.closeTime!)}'
              : null)
        : (status.openTime != null
              ? 'Opens at ${_formatDisplayTime(status.openTime!)}'
              : null);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.cafe?.cafeDetails.name ?? 'Cafe Name',
            style: Theme.of(context).textTheme.titleLargeSemi,
          ),
          const SizedBox(height: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    (widget.cafe?.cafeDetails.rating ?? 0).toStringAsFixed(1),
                    style: Theme.of(context).textTheme.bodyLargeMed,
                  ),
                  const SizedBox(width: 4),
                  RatingBarIndicator(
                    rating: (widget.cafe?.cafeDetails.rating ?? 0).toDouble(),
                    itemBuilder: (context, index) => Icon(
                      PhosphorIconsFill.star,
                      color: Theme.of(context).colorScheme.primary60,
                      size: 14,
                    ),
                    itemCount: 5,
                    itemSize: 16,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '(${widget.cafe?.cafeDetails.reviewCount} reviews)',
                    style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                      color: Theme.of(context).colorScheme.gray,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (_distanceMeters != null) ...[
                    Text(
                      '${(_distanceMeters! / 1000).toStringAsFixed(1)} km',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w400,
                        color: Color(0xFF868584),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 4,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFF868584),
                        borderRadius: BorderRadius.circular(100),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    locationText,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w400,
                      color: Color(0xFF868584),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: dotColor,
                      borderRadius: BorderRadius.circular(100),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    statusText,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: statusColor,
                    ),
                  ),
                  if (statusDetail != null) ...[
                    const SizedBox(width: 8),
                    const Text(
                      '|',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w400,
                        color: Color(0xFF868584),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      statusDetail,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w400,
                        color: Color(0xFF868584),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
