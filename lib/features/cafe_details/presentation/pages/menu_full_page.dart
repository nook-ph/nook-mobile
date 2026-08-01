import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:nook/core/utils/adaptive_tap.dart';
import 'package:nook/core/widgets/error/section_empty_widget.dart';
import 'package:nook/features/cafe_details/domain/entities/cafe_details_entity.dart';
import 'package:nook/features/cafe_details/presentation/widgets/menu_category_section.dart';
import 'package:nook/features/cafe_details/presentation/widgets/menu_highlight_card.dart';
import 'package:nook/features/cafe_details/presentation/widgets/menu_item_variants_sheet.dart';

class MenuFullPage extends StatelessWidget {
  const MenuFullPage({
    super.key,
    required this.menuItems,
    required this.highlights,
    this.cafeName,
  });

  final List<MenuItemEntity> menuItems;
  final List<MenuItemEntity> highlights;
  final String? cafeName;

  Map<String, List<MenuItemEntity>> get _groupedCategories {
    final map = <String, List<MenuItemEntity>>{};
    for (final item in menuItems) {
      final category = item.categoryName ?? 'Others';
      map.putIfAbsent(category, () => []).add(item);
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final cardWidth = ((screenWidth - 44) / 2) - 6;
    const double radius = 12.0;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: AdaptiveTap(
          onTap: () => Navigator.of(context).pop(),
          child: const Padding(
            padding: EdgeInsets.all(8),
            child: Icon(Icons.arrow_back, color: Colors.black),
          ),
        ),
      ),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 22.0,
              vertical: 12.0,
            ),
            child: Text(
              cafeName != null ? '$cafeName Menu' : 'Menu',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Colors.black,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (menuItems.isEmpty) ...[
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 22.0),
              child: SectionEmptyWidget(
                title: 'No menu posted yet',
                subtitle: 'This cafe has not shared a menu. Check back later.',
                icon: Icons.restaurant_menu_outlined,
              ),
            ),
          ] else ...[
            if (highlights.isNotEmpty) ...[
              const SizedBox(height: 12),
              SizedBox(
                height: MenuHighlightCard.listHeight,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  itemCount: highlights.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    final item = highlights[index];
                    return MenuHighlightCard(
                      item: item,
                      width: cardWidth,
                      onTap: item.hasVariants
                          ? () => MenuItemVariantsSheet.show(context, item)
                          : null,
                    );
                  },
                ),
              ),
              const Gap(24),
            ],
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (int i = 0; i < _groupedCategories.keys.length; i++) ...[
                    MenuCategorySection(
                      categoryName: _groupedCategories.keys.elementAt(i),
                      items: _groupedCategories.values.elementAt(i),
                    ),
                    if (i < _groupedCategories.keys.length - 1) const Gap(24),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
