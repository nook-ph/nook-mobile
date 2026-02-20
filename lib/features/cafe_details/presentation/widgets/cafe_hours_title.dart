import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:nook/features/cafe_details/presentation/widgets/day_row.dart';

class CafeHoursTile extends StatelessWidget {
  const CafeHoursTile({super.key});

  @override
  Widget build(BuildContext context) {
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
              fontSize: 14,
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
          children: const [
            DayRow('Sunday', 'Closed', isToday: false),
            DayRow('Monday', '8:30 AM - 10:00 PM', isToday: false),
            DayRow('Tuesday', '8:30 AM - 10:00 PM', isToday: false),
            DayRow('Wednesday', '8:30 AM - 10:00 PM', isToday: false),
            DayRow('Thursday', '8:30 AM - 10:00 PM', isToday: true),
            DayRow('Friday', '8:30 AM - 10:00 PM', isToday: false),
            DayRow('Saturday', '8:30 AM - 10:00 PM', isToday: false),
          ],
        ),
      ),
    );
  }
}
