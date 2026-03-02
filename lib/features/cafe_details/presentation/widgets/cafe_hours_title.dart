import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:nook/features/cafe_details/domain/use_cases/get_cafe_details_usecase.dart';
import 'package:nook/features/cafe_details/presentation/widgets/day_row.dart';

class CafeHoursTile extends StatelessWidget {
  final CafeDetailsResult? cafe;

  static const List<String> _orderedDays = [
    'sunday',
    'monday',
    'tuesday',
    'wednesday',
    'thursday',
    'friday',
    'saturday',
  ];

  const CafeHoursTile({super.key, required this.cafe});

  String _formatDayLabel(String day) {
    return day[0].toUpperCase() + day.substring(1);
  }

  String _formatTime(String value) {
    final parts = value.split(':');
    if (parts.length < 2) {
      return value;
    }

    final hour24 = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour24 == null || minute == null) {
      return value;
    }

    final period = hour24 >= 12 ? 'PM' : 'AM';
    final hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12;
    final minuteText = minute.toString().padLeft(2, '0');
    return '$hour12:$minuteText $period';
  }

  String _formatHours(Map<String, dynamic> dayHours) {
    final open = dayHours['open']?.toString();
    final close = dayHours['close']?.toString();

    if (open == null || close == null || open.isEmpty || close.isEmpty) {
      return 'Closed';
    }

    return '${_formatTime(open)} - ${_formatTime(close)}';
  }

  @override
  Widget build(BuildContext context) {
    final operatingHours = cafe?.cafeDetails.operatingHours ?? {};
    final weekday = DateTime.now().weekday;
    final todayDay = weekday == DateTime.sunday
        ? 'sunday'
        : _orderedDays[weekday];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22),
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
        ),
        child: ExpansionTile(
          tilePadding: EdgeInsets.zero,
          leading: const Icon(LucideIcons.clock, color: Colors.black, size: 20),
          title: const Text(
            'Hours',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
          ),
          iconColor: Colors.grey.shade600,
          collapsedIconColor: Colors.grey.shade600,
          childrenPadding: const EdgeInsets.only(
            left: 44,
            right: 0,
            bottom: 16,
          ),
          children: _orderedDays.map((day) {
            final dayHoursRaw = operatingHours[day];
            final dayHours = dayHoursRaw is Map
                ? Map<String, dynamic>.from(dayHoursRaw)
                : <String, dynamic>{};

            return DayRow(
              _formatDayLabel(day),
              _formatHours(dayHours),
              isToday: day == todayDay,
            );
          }).toList(),
        ),
      ),
    );
  }
}
