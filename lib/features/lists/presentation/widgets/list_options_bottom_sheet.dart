import 'package:flutter/material.dart';
import 'package:nook/features/lists/presentation/widgets/lists_ui.dart';

/// The ⋯ sheet of a list (Figma "List options sheet"): each row says what it
/// does, and Delete is red.
class ListOptionsBottomSheet extends StatelessWidget {
  final String listId;
  final String listName;

  /// Null hides the row. System and default lists can't be edited or deleted,
  /// but can still become a crawl.
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  /// Null when the list has too few cafes to make a crawl from.
  final VoidCallback? onMakeCrawl;

  const ListOptionsBottomSheet({
    super.key,
    required this.listId,
    required this.listName,
    this.onEdit,
    this.onDelete,
    this.onMakeCrawl,
  });

  /// Closes the sheet first so the next surface opens over the list.
  VoidCallback _then(BuildContext context, VoidCallback action) {
    return () {
      Navigator.pop(context);
      action();
    };
  }

  @override
  Widget build(BuildContext context) {
    final makeCrawl = onMakeCrawl;
    final edit = onEdit;
    final delete = onDelete;

    return ListsSheet(
      title: listName,
      gap: 2,
      children: [
        if (makeCrawl != null)
          ListsSheetAction(
            title: 'Turn into a crawl',
            subtitle: 'Pick 3 to 6 of these cafes and visit them in order',
            onTap: _then(context, makeCrawl),
          ),
        if (edit != null)
          ListsSheetAction(
            title: 'Edit',
            subtitle: 'Name and description',
            onTap: _then(context, edit),
          ),
        if (delete != null)
          ListsSheetAction(
            title: 'Delete',
            subtitle: 'Cafes are not deleted',
            destructive: true,
            onTap: _then(context, delete),
          ),
      ],
    );
  }
}
