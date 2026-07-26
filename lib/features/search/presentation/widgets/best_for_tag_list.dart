import 'package:flutter/material.dart';
import 'package:nook/core/utils/adaptive_tap.dart';
import 'package:nook/core/utils/tag_icon_resolver.dart';
import 'package:nook/utils/theme/custom_themes/color_scheme.dart';

class BestForTagList extends StatelessWidget {
  const BestForTagList({super.key, this.onTagTap, this.filterQuery});

  final ValueChanged<String>? onTagTap;
  final String? filterQuery;

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

  static bool hasMatches(String? query) {
    final q = query?.trim().toLowerCase() ?? '';
    if (q.isEmpty) return true;
    return bestForTags.any((item) {
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
            'Best For',
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
                      Expanded(child: _buildHighlightedLabel(textTheme, label)),
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
    if (query.isEmpty) return bestForTags;

    return bestForTags.where((item) {
      final label = item['label'] as String? ?? '';
      return label.toLowerCase().contains(query);
    }).toList();
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
