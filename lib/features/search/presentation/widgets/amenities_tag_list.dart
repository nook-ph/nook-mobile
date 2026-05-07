import 'package:flutter/material.dart';
import 'package:nook/core/utils/adaptive_tap.dart';
import 'package:nook/core/utils/tag_icon_resolver.dart';
import 'package:nook/utils/theme/custom_themes/color_scheme.dart';

class AmenitiesTagList extends StatelessWidget {
  const AmenitiesTagList({super.key, this.onTagTap, this.filterQuery});

  final ValueChanged<String>? onTagTap;
  final String? filterQuery;

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

  static bool hasMatches(String? query) {
    final q = query?.trim().toLowerCase() ?? '';
    if (q.isEmpty) return true;
    return amenitiesTags.any((item) {
      final label = item['label'] as String? ?? '';
      return label.toLowerCase().contains(q);
    });
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final primaryAccent = Theme.of(context).colorScheme.primary80;
    final borderColor = Theme.of(context).colorScheme.border;
    final filteredTags = _filteredTags();

    if (filteredTags.isEmpty) {
      return const SizedBox.shrink();
    }

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
            itemCount: filteredTags.length,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemBuilder: (context, index) {
              final item = filteredTags[index];
              final label = item['label'] as String? ?? '';
              final fallbackIcon = item['icon'] as IconData?;
              final resolvedIcon = resolveTagIcon(label);

              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: AdaptiveTap(
                  onTap: onTagTap == null ? null : () => onTagTap!(label),
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
                        child: _buildHighlightedLabel(textTheme, label),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _filteredTags() {
    final query = filterQuery?.trim().toLowerCase() ?? '';
    if (query.isEmpty) return amenitiesTags;

    return amenitiesTags
        .where((item) {
          final label = item['label'] as String? ?? '';
          return label.toLowerCase().contains(query);
        })
        .toList();
  }

  Widget _buildHighlightedLabel(TextTheme textTheme, String label) {
    final query = filterQuery?.trim() ?? '';
    final baseStyle = textTheme.bodyLarge?.copyWith(
      fontWeight: FontWeight.w500,
      color: Colors.black,
    );
    final highlightStyle = baseStyle?.copyWith(
      fontWeight: FontWeight.w700,
      backgroundColor: Colors.black12,
    );

    if (query.isEmpty) {
      return Text(label, style: baseStyle);
    }

    final lowerLabel = label.toLowerCase();
    final lowerQuery = query.toLowerCase();
    if (!lowerLabel.contains(lowerQuery)) {
      return Text(label, style: baseStyle);
    }

    final spans = <TextSpan>[];
    var start = 0;
    while (true) {
      final index = lowerLabel.indexOf(lowerQuery, start);
      if (index < 0) {
        spans.add(TextSpan(text: label.substring(start), style: baseStyle));
        break;
      }
      if (index > start) {
        spans.add(
          TextSpan(text: label.substring(start, index), style: baseStyle),
        );
      }
      spans.add(
        TextSpan(
          text: label.substring(index, index + query.length),
          style: highlightStyle,
        ),
      );
      start = index + query.length;
    }

    return RichText(
      text: TextSpan(children: spans),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}
