import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:nook/features/cafe_details/domain/entities/cafe_details_entity.dart';
import 'package:nook/features/cafe_details/presentation/widgets/menu_item_card.dart';

class MenuCategorySection extends StatelessWidget {
  const MenuCategorySection({
    super.key,
    required this.categoryName,
    required this.items,
  });

  final String categoryName;
  final List<MenuItemEntity> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          categoryName,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w500,
            color: Colors.black,
          ),
        ),

        const Gap(14),

        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (int i = 0; i < items.length; i++) ...[
              MenuItemCard(item: items[i]),
              if (i < items.length - 1) const Gap(14),
            ],
          ],
        ),

        const Gap(24),

        const Divider(
          color: Color(0xFFE0E0E0),
          thickness: 1,
          height: 1,
        ),
      ],
    );
  }
}
