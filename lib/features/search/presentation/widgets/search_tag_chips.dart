import 'package:flutter/material.dart';
import 'package:nook/core/utils/tag_icon_resolver.dart';
import 'package:nook/utils/theme/custom_themes/color_scheme.dart';

class SearchTagChips extends StatelessWidget {
  final String label;
  final List<String> tags;
  final Set<String> selectedTags;
  final Function(String, bool) onTagSelected;

  const SearchTagChips({
    super.key,
    required this.label,
    required this.tags,
    required this.selectedTags,
    required this.onTagSelected,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final borderColor = Theme.of(context).colorScheme.border;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            label,
            style: textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
          ),
        ),
        SizedBox(
          height: 44,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            scrollDirection: Axis.horizontal,
            itemCount: tags.length,
            separatorBuilder: (context, index) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final tag = tags[index];
              final isSelected = selectedTags.contains(tag);
              final icon = resolveTagIcon(tag);

              return FilterChip(
                label: Text(tag),
                selected: isSelected,
                onSelected: (selected) => onTagSelected(tag, selected),
                avatar: icon != null
                    ? Icon(
                        icon,
                        size: 16,
                        color: isSelected ? Colors.white : Colors.black,
                      )
                    : null,
                backgroundColor: Colors.white,
                selectedColor: Colors.black,
                labelStyle: textTheme.bodyMedium?.copyWith(
                  color: isSelected ? Colors.white : Colors.black,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(
                    color: isSelected ? Colors.black : borderColor,
                    width: 1,
                  ),
                ),
                showCheckmark: false,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              );
            },
          ),
        ),
      ],
    );
  }
}
