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
          Text(day, style: TextStyle(fontSize: 12, color: color)),
          Text(hours, style: TextStyle(fontSize: 12, color: color)),
        ],
      ),
    );
  }
}
