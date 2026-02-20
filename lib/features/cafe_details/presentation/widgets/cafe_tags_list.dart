import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class CafeTagsList extends StatelessWidget {
  const CafeTagsList({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 30,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 22),
        itemCount: 4,
        separatorBuilder: (context, index) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          return Container(
            alignment: Alignment.center,
            height: 30,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF868584)),
            ),
            child: const Row(
              children: [
                Icon(
                  LucideIcons.graduationCap,
                  size: 16,
                  color: Color(0xFF868584),
                ),
                SizedBox(width: 4),
                Text(
                  'Student Friendly',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF868584),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
