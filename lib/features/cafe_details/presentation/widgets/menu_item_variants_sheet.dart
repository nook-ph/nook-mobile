import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:nook/features/cafe_details/domain/entities/cafe_details_entity.dart';

class MenuItemVariantsSheet extends StatelessWidget {
  const MenuItemVariantsSheet({super.key, required this.item});

  final MenuItemEntity item;

  static Future<void> show(BuildContext context, MenuItemEntity item) {
    if (!item.hasVariants) {
      return Future.value();
    }

    return showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isDismissible: true,
      enableDrag: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      clipBehavior: Clip.antiAlias,
      builder: (context) => MenuItemVariantsSheet(item: item),
    );
  }

  String _formatPrice(double price) {
    return '₱${price.toStringAsFixed(2)}';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item.name,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
          ),
          const Gap(12),
          for (final variant in item.variants) ...[
            _VariantRow(
              label: variant.label,
              isDefault: variant.isDefault,
              priceLabel: _formatPrice(variant.resolvedPrice(item.price)),
            ),
            const Gap(10),
          ],
        ],
      ),
    );
  }
}

class _VariantRow extends StatelessWidget {
  const _VariantRow({
    required this.label,
    required this.isDefault,
    required this.priceLabel,
  });

  final String label;
  final bool isDefault;
  final String priceLabel;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Row(
            children: [
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isDefault ? FontWeight.w600 : FontWeight.w400,
                    color: Colors.black,
                  ),
                ),
              ),
              if (isDefault) ...[
                const Gap(6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.black),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'Default',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        Text(
          priceLabel,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
      ],
    );
  }
}
