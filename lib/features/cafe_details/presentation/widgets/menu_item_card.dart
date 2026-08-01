import 'package:flutter/material.dart';
import 'package:nook/core/extensions/extensions.dart';
import 'package:nook/features/cafe_details/domain/entities/cafe_details_entity.dart';

class MenuItemCard extends StatelessWidget {
  const MenuItemCard({super.key, required this.item});

  final MenuItemEntity item;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // The name once. There was a second Text under it rendering
        // `item.name` again, in subtitle grey — and MenuItemEntity carries no
        // description for it to have meant, so every row printed its own name
        // twice.
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
        Text(
          // displayPrice so a variant item reads the same here as on the
          // highlight card above it.
          '₱${item.displayPrice}',
          style: context.textTheme.bodySmallMed.copyWith(color: Colors.black),
        ),
      ],
    );
  }
}
