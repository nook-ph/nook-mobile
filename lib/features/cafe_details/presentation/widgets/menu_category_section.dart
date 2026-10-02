import 'package:flutter/material.dart';
import 'package:nook/core/utils/adaptive_tap.dart';
import 'package:nook/features/cafe_details/domain/entities/cafe_details_entity.dart';
import 'package:nook/features/cafe_details/presentation/widgets/cafe_details_common.dart';
import 'package:nook/features/cafe_details/presentation/widgets/menu_item_variants_sheet.dart';

/// "₱110.00", or "from ₱150.00" when the item's sizes differ in price.
String menuPriceLabel(MenuItemEntity item) {
  final min = item.minPrice;
  final price = '₱${min.toStringAsFixed(2)}';
  return item.hasVariants && item.maxPrice != min ? 'from $price' : price;
}

/// One menu category: its name, then one line per item with the price at the
/// trailing edge. Items with sizes show a chevron and open the sizes sheet.
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
        CafeSectionTitle(categoryName),
        const SizedBox(height: 8),
        for (final item in items) _MenuItemRow(item: item),
      ],
    );
  }
}

class _MenuItemRow extends StatelessWidget {
  const _MenuItemRow({required this.item});

  final MenuItemEntity item;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final row = ConstrainedBox(
      // 44pt keeps a row with sizes a comfortable tap target.
      constraints: const BoxConstraints(minHeight: 44),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              // Long names wrap; the price stays on the first line.
              child: Text(
                item.name,
                style: textTheme.bodyMedium?.copyWith(
                  fontSize: 14,
                  color: CafeDetailsTokens.ink,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Text(
              menuPriceLabel(item),
              style: textTheme.bodyMedium?.copyWith(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: CafeDetailsTokens.ink,
              ),
            ),
            if (item.hasVariants) ...[
              const SizedBox(width: 6),
              const Padding(
                padding: EdgeInsets.only(top: 2),
                child: Icon(
                  Icons.chevron_right,
                  size: 16,
                  color: CafeDetailsTokens.muted,
                ),
              ),
            ],
          ],
        ),
      ),
    );

    if (!item.hasVariants) return row;

    return Semantics(
      button: true,
      hint: 'Shows sizes and prices',
      child: AdaptiveTap(
        onTap: () => MenuItemVariantsSheet.show(context, item),
        borderRadius: BorderRadius.circular(8),
        child: row,
      ),
    );
  }
}
