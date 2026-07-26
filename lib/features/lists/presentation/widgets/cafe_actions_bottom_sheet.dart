import 'package:flutter/material.dart';
import 'package:nook/core/extensions/extensions.dart';

class CafeActionsBottomSheet extends StatelessWidget {
  const CafeActionsBottomSheet({
    super.key,
    required this.cafeName,
    required this.onViewDetails,
    required this.onRemove,
  });

  final String cafeName;
  final VoidCallback onViewDetails;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                cafeName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: context.textTheme.bodySmall?.copyWith(
                  color: Colors.grey,
                ),
              ),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.info_outline, color: Color(0xFF344E41)),
              title: Text(
                'View details',
                style: context.textTheme.bodyMedium?.copyWith(
                  color: Colors.black,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                onViewDetails();
              },
            ),
            Divider(height: 1, color: Theme.of(context).colorScheme.border),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: Text(
                'Remove from list',
                style: context.textTheme.bodyMedium?.copyWith(
                  color: Colors.red,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                onRemove();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
