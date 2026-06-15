import 'package:flutter/material.dart';

class DayRow extends StatelessWidget {
  const DayRow(this.day, this.hours, {super.key, required this.isToday});

  final String day;
  final String hours;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    final color = isToday ? const Color(0xFFD65A5A) : Colors.grey.shade600;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(day, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: color)),
          Text(hours, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: color)),
        ],
      ),
    );
  }
}
