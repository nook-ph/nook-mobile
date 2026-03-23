import 'package:flutter/material.dart';
import 'package:nook/features/cafe_details/domain/entities/cafe_details_entity.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

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
          final tagIcon = _resolveIcon(tag.name);

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

  IconData? _resolveIcon(String? tagName) {
    if (tagName == null || tagName.trim().isEmpty) {
      return null;
    }

    final name = tagName.trim().toLowerCase();

    switch (name) {
      case 'date spot':
        return PhosphorIcons.heart();
      case 'solo work / study':
        return PhosphorIcons.laptop();
      case 'group hangout':
      case 'family friendly':
        return PhosphorIcons.users();
      case 'book cafe':
        return PhosphorIcons.bookOpen();
      case 'late night':
        return PhosphorIcons.moon();
      case 'quick coffee':
      case 'specialty coffee':
        return PhosphorIcons.coffee();
      case 'nature cafe':
        return PhosphorIcons.leaf();
      case 'special occasion':
        return PhosphorIcons.sparkle();
      case 'student friendly':
        return PhosphorIcons.graduationCap();
      case 'aesthetic / ig-worthy':
        return PhosphorIcons.instagramLogo();
      case 'pet friendly':
        return PhosphorIcons.dog();
      case 'free wifi':
        return PhosphorIcons.wifiHigh();
      case 'power outlets':
        return PhosphorIcons.plug();
      case 'air conditioned':
        return PhosphorIcons.snowflake();
      case 'outdoor seating':
        return PhosphorIcons.chair();
      case 'parking available':
        return PhosphorIcons.park();
      case 'reservations accepted':
        return PhosphorIcons.calendarCheck();
      case 'private rooms':
        return PhosphorIcons.doorOpen();
      case 'wheelchair accessible':
        return PhosphorIcons.wheelchair();
      case 'takeaway available':
        return PhosphorIcons.shoppingBag();
      case 'smoking area':
        return PhosphorIcons.cigarette();
      case 'open 24 hours':
        return PhosphorIcons.clock();
      default:
        if (name.contains('wifi')) return PhosphorIcons.wifiHigh();
        if (name.contains('cash')) return PhosphorIcons.money();
        if (name.contains('card') ||
            name.contains('credit') ||
            name.contains('debit')) {
          return PhosphorIcons.creditCard();
        }
        if (name.contains('wallet') ||
            name.contains('gcash') ||
            name.contains('maya')) {
          return PhosphorIcons.wallet();
        }
        return null;
    }
  }
}
