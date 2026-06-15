import 'package:flutter/material.dart';
import 'package:nook/core/extensions/extensions.dart';

class ListOptionsBottomSheet extends StatelessWidget {
  final String listId;
  final String listName;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const ListOptionsBottomSheet({
    super.key,
    required this.listId,
    required this.listName,
    required this.onEdit,
    required this.onDelete,
  });

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
                listName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: context.textTheme.bodySmall?.copyWith(color: Colors.grey),
              ),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(
                Icons.edit_outlined,
                color: Color(0xFF344E41),
              ),
              title: Text(
                'Edit',
                style: context.textTheme.bodyMedium?.copyWith(color: Colors.black),
              ),
              onTap: () {
                Navigator.pop(context);
                onEdit();
              },
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: Text(
                'Delete',
                style: context.textTheme.bodyMedium?.copyWith(color: Colors.red),
              ),
              onTap: () {
                Navigator.pop(context);
                onDelete();
              },
            ),
          ],
        ),
      ),
    );
  }
}
