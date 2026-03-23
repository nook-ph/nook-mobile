import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:nook/features/cafe_details/domain/entities/cafe_details_entity.dart';
import 'package:nook/features/cafe_details/presentation/widgets/menu_category_section.dart';

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

  String _formatPrice(double price) {
    return '₱${price.toStringAsFixed(2)}';
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final cardWidth = ((screenWidth - 44) / 2) - 6;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(cafeName != null ? '$cafeName Menu' : 'Menu'),
        backgroundColor: Colors.white,
      ),
      body: ListView(
        children: [
          if (highlights.isNotEmpty) ...[
            const SizedBox(height: 24),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 22),
              child: Text(
                'Highlights',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: Colors.black,
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 178,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 22),
                itemCount: highlights.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final item = highlights[index];

                  return Container(
                    width: cardWidth,
                    height: 178,
                    clipBehavior: Clip.hardEdge,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFFE0E0E0),
                        width: 1.0,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 3,
                          child:
                              item.imageUrl != null && item.imageUrl!.isNotEmpty
                              ? Image.network(
                                  item.imageUrl!,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                    color: const Color(0xFFF5F5F5),
                                    alignment: Alignment.center,
                                    child: const Icon(
                                      Icons.image_not_supported_outlined,
                                      color: Color(0xFFBDBDBD),
                                    ),
                                  ),
                                )
                              : Container(
                                  color: const Color(0xFFF5F5F5),
                                  alignment: Alignment.center,
                                  child: const Icon(
                                    Icons.image_outlined,
                                    color: Color(0xFFBDBDBD),
                                  ),
                                ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 15),
                                ),
                                const Gap(2),
                                Text(
                                  _formatPrice(item.price),
                                  style: const TextStyle(
                                    fontSize: 15,
                                    color: Colors.black,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            const Gap(24),

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
