import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:nook/features/cafe_details/domain/entities/cafe_details_entity.dart';

class CafeTagsList extends StatelessWidget {
  const CafeTagsList({super.key, required this.tags});

  final List<TagEntity> tags;

  @override
  Widget build(BuildContext context) {
    final featuredTags = tags.where((tag) => tag.isFeatured).toList();

    if (featuredTags.isEmpty) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      height: 30,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 22),
        itemCount: featuredTags.length,
        separatorBuilder: (context, index) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final tag = featuredTags[index];
          final tagIcon = _resolveIcon(tag.iconName);

          return Container(
            alignment: Alignment.center,
            height: 30,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF868584)),
            ),
            child: Row(
              children: [
                tagIcon != null
                    ? Icon(tagIcon, size: 16, color: const Color(0xFF868584))
                    : Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Color(0xFF868584),
                          shape: BoxShape.circle,
                        ),
                      ),
                const SizedBox(width: 4),
                Text(
                  tag.name,
                  style: const TextStyle(
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

  IconData? _resolveIcon(String? iconName) {
    if (iconName == null || iconName.trim().isEmpty) {
      return null;
    }

    final normalized = iconName.trim().toLowerCase();

    const iconMap = <String, IconData>{
      'coffee': LucideIcons.coffee,
      'cup-soda': LucideIcons.cupSoda,
      'wifi': LucideIcons.wifi,
      'book-open': LucideIcons.bookOpen,
      'laptop': LucideIcons.laptop,
      'armchair': LucideIcons.armchair,
      'leaf': LucideIcons.leaf,
      'music': LucideIcons.music,
      'dog': LucideIcons.dog,
      'car': LucideIcons.car,
      'sun': LucideIcons.sun,
      'moon': LucideIcons.moon,
      'clock': LucideIcons.clock,
      'sparkles': LucideIcons.sparkles,
      'graduation-cap': LucideIcons.graduationCap,
      'users': LucideIcons.users,
      'user': LucideIcons.user,
      'map-pin': LucideIcons.mapPin,
      'heart': LucideIcons.heart,
    };

    return iconMap[normalized];
  }
}
