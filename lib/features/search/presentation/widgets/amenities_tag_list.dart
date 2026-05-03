import 'package:flutter/material.dart';
import 'package:nook/core/utils/tag_icon_resolver.dart';
import 'package:nook/utils/theme/custom_themes/color_scheme.dart';

class AmenitiesTagList extends StatelessWidget {
  const AmenitiesTagList({super.key});

  static const List<Map<String, dynamic>> amenitiesTags = [
    {'label': 'Free WiFi', 'icon': Icons.wifi_outlined},
    {'label': 'Power Outlets', 'icon': Icons.power_outlined},
    {'label': 'Air Conditioned', 'icon': Icons.ac_unit_outlined},
    {'label': 'Outdoor Seating', 'icon': Icons.deck_outlined},
    {'label': 'Parking Available', 'icon': Icons.local_parking_outlined},
    {'label': 'Reservations Accepted', 'icon': Icons.event_available_outlined},
    {'label': 'Private Rooms', 'icon': Icons.meeting_room_outlined},
    {'label': 'Wheelchair Accessible', 'icon': Icons.accessible_outlined},
    {'label': 'Takeaway Available', 'icon': Icons.takeout_dining_outlined},
    {'label': 'Smoking Area', 'icon': Icons.smoking_rooms_outlined},
    {'label': 'Open 24 Hours', 'icon': Icons.schedule_outlined},
    {'label': 'Pet Friendly', 'icon': Icons.pets_outlined},
  ];

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final primaryAccent = Theme.of(context).colorScheme.primary80;
    final borderColor = Theme.of(context).colorScheme.border;

    return Container(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Amenities',
            style: textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w500,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 16),
          ListView.builder(
            itemCount: amenitiesTags.length,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemBuilder: (context, index) {
              final item = amenitiesTags[index];
              final label = item['label'] as String? ?? '';
              final fallbackIcon = item['icon'] as IconData?;
              final resolvedIcon = resolveTagIcon(label);

              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: borderColor, width: 1),
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        resolvedIcon ?? fallbackIcon,
                        color: primaryAccent,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        label,
                        style: textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w500,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
