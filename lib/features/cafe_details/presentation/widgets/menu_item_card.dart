import 'package:flutter/material.dart';
import 'package:nook/core/extensions/extensions.dart';
import 'package:nook/features/cafe_details/domain/entities/cafe_details_entity.dart';

class MenuItemCard extends StatelessWidget {
  const MenuItemCard({super.key, required this.item});

  final MenuItemEntity item;

  String _formatPrice(double price) {
    return '₱${price.toStringAsFixed(2)}';
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.name,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: Colors.black,
                ),
              ),
              Text(
                item.name,
                style: context.textTheme.bodySmall?.copyWith(
                  color: const Color(0xFF848685),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Text(
          _formatPrice(item.price),
          style: context.textTheme.bodySmallMed.copyWith(
            color: Colors.black,
          ),
        ),
      ],
    );
  }
}
