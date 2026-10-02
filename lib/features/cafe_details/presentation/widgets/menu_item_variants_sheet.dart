import 'package:flutter/material.dart';
import 'package:nook/core/utils/adaptive_tap.dart';
import 'package:nook/features/cafe_details/domain/entities/cafe_details_entity.dart';
import 'package:nook/features/cafe_details/presentation/widgets/cafe_details_common.dart';

/// The sizes of one menu item with the price of each. Read-only: nothing is
/// selected or ordered here.
class MenuItemVariantsSheet extends StatelessWidget {
  const MenuItemVariantsSheet({super.key, required this.item});

  final MenuItemEntity item;

  static Future<void> show(BuildContext context, MenuItemEntity item) {
    if (!item.hasVariants) {
      return Future.value();
    }

    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => MenuItemVariantsSheet(item: item),
    );
  }

  static String _formatPrice(double price) => '₱${price.toStringAsFixed(2)}';

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final variants = item.variants;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.8,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: CafeDetailsTokens.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      item.name,
                      style: textTheme.bodyLarge?.copyWith(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: CafeDetailsTokens.ink,
                      ),
                    ),
                  ),
                  AdaptiveTap(
                    onTap: () => Navigator.of(context).pop(),
                    borderRadius: BorderRadius.circular(22),
                    child: Semantics(
                      button: true,
                      label: 'Close',
                      child: const SizedBox.square(
                        dimension: 44,
                        child: Icon(
                          Icons.close,
                          size: 22,
                          color: CafeDetailsTokens.ink,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  itemCount: variants.length,
                  separatorBuilder: (_, _) => const Divider(
                    color: CafeDetailsTokens.border,
                    thickness: 1,
                    height: 1,
                  ),
                  itemBuilder: (context, index) {
                    final variant = variants[index];
                    return _VariantRow(
                      label: variant.label,
                      isDefault: variant.isDefault,
                      priceLabel: _formatPrice(
                        variant.resolvedPrice(item.price),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
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
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodyMedium?.copyWith(
                      fontSize: 14,
                      fontWeight: isDefault ? FontWeight.w500 : FontWeight.w400,
                      color: CafeDetailsTokens.ink,
                    ),
                  ),
                ),
                if (isDefault) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: CafeDetailsTokens.tint,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      'Default',
                      style: textTheme.bodySmall?.copyWith(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: CafeDetailsTokens.ink,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 16),
          Text(
            priceLabel,
            style: textTheme.bodyMedium?.copyWith(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: CafeDetailsTokens.ink,
            ),
          ),
        ],
      ),
    );
  }
}
