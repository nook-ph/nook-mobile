import 'package:flutter/material.dart';
import 'package:nook/core/utils/tag_icon_resolver.dart';
import 'package:nook/utils/theme/custom_themes/color_scheme.dart';

class BestForTagList extends StatelessWidget {
  const BestForTagList({super.key});

  static const List<Map<String, dynamic>> bestForTags = [
    {'label': 'Date Spot', 'icon': Icons.favorite_border},
    {'label': 'Solo Work / Study', 'icon': Icons.laptop_mac_outlined},
    {'label': 'Group Hangout', 'icon': Icons.group_outlined},
    {'label': 'Book Cafe', 'icon': Icons.menu_book_outlined},
    {'label': 'Late Night', 'icon': Icons.nightlight_outlined},
    {'label': 'Quick Coffee', 'icon': Icons.coffee_outlined},
    {'label': 'Family Friendly', 'icon': Icons.family_restroom_outlined},
    {'label': 'Nature Cafe', 'icon': Icons.park_outlined},
    {'label': 'Special Occasion', 'icon': Icons.celebration_outlined},
    {'label': 'Specialty Coffee', 'icon': Icons.local_cafe_outlined},
    {'label': 'Student Friendly', 'icon': Icons.school_outlined},
    {'label': 'Aesthetic / IG-worthy', 'icon': Icons.camera_alt_outlined},
    {'label': 'Community Space', 'icon': Icons.storefront_outlined},
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
            'Best For',
            style: textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w500,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 16),
          ListView.builder(
            itemCount: bestForTags.length,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemBuilder: (context, index) {
              final item = bestForTags[index];
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
