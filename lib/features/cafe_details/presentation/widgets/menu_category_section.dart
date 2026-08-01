import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:nook/core/extensions/extensions.dart';
import 'package:nook/core/utils/adaptive_tap.dart';
import 'package:nook/features/cafe_details/domain/entities/cafe_details_entity.dart';
import 'package:nook/features/cafe_details/presentation/widgets/menu_item_variants_sheet.dart';
// Assuming AdaptiveTap is imported from your common widgets folder
// import 'package:nook/core/widgets/adaptive_tap.dart';

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
          style: context.textTheme.titleMediumSemi.copyWith(
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
    // The visual content of the row
    final Widget rowContent = Padding(
      // Padding gives the AdaptiveTap ripple/fade room to breathe
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // The name once. The row carried a second Text below it styled as a
          // subtitle but rendering `item.name` again, so every item on the
          // menu printed its own name twice. MenuItemEntity has no
          // description field for it to have meant.
          Expanded(
            child: Text(
              item.name,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w500,
                color: Colors.black,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Row(
            children: [
              Text(
                '₱${item.displayPrice}',
                style: context.textTheme.bodySmallMed.copyWith(
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
      ),
    );

    if (!item.hasVariants) {
      return rowContent;
    }

    return AdaptiveTap(
      onTap: () => MenuItemVariantsSheet.show(context, item),
      borderRadius: BorderRadius.circular(8),
      child: rowContent,
    );
  }
}
