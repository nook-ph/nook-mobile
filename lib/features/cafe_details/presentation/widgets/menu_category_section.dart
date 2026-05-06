import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:nook/features/cafe_details/domain/entities/cafe_details_entity.dart';
import 'package:nook/features/cafe_details/presentation/widgets/menu_item_variants_sheet.dart';

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
              _MenuItemRow(item: items[i]),
              if (i < items.length - 1) const Gap(14),
            ],
          ],
        ),

        const Gap(24),

        const Divider(color: Color(0xFFE0E0E0), thickness: 1, height: 1),
      ],
    );
  }
}

class _MenuItemRow extends StatelessWidget {
  const _MenuItemRow({required this.item});

  final MenuItemEntity item;

  @override
  Widget build(BuildContext context) {
    final row = Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.name,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.black,
                ),
              ),
              Text(
                item.name,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: Colors.black,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Row(
          children: [
            Text(
              '₱${item.displayPrice}',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.black,
              ),
            ),
            if (item.hasVariants) ...[
              const SizedBox(width: 6),
              const Icon(Icons.chevron_right, size: 16, color: Colors.black),
            ],
          ],
        ),
      ],
    );

    if (!item.hasVariants) {
      return row;
    }

    return GestureDetector(
      onTap: () => MenuItemVariantsSheet.show(context, item),
      behavior: HitTestBehavior.opaque,
      child: row,
    );
  }
}
