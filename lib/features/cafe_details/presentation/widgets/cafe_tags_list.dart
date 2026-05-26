import 'package:flutter/material.dart';
import 'package:nook/core/utils/tag_icon_resolver.dart';
import 'package:nook/features/cafe_details/domain/entities/cafe_details_entity.dart';
import 'package:nook/utils/theme/custom_themes/color_scheme.dart';
import 'package:nook/utils/theme/custom_themes/text_theme.dart';

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
          final tagIcon = resolveTagIcon(tag.name);

          return Container(
            alignment: Alignment.center,
            height: 30,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Theme.of(context).colorScheme.primary60,
              ),
            ),
            child: Row(
              children: [
                tagIcon != null
                    ? Icon(
                        tagIcon,
                        size: 16,
                        color: Theme.of(context).colorScheme.primary60,
                      )
                    : Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary60,
                          shape: BoxShape.circle,
                        ),
                      ),
                const SizedBox(width: 4),
                Text(
                  tag.name,
                  style: Theme.of(context).textTheme.bodySmallMed.copyWith(
                    color: Theme.of(context).colorScheme.gray,
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
