import 'package:flutter/material.dart';
import 'package:nook/features/crawls/presentation/widgets/crawl_ui.dart';

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
  VoidCallback? _then(BuildContext context, VoidCallback? action) {
    if (action == null) return null;
    return () {
      Navigator.pop(context);
      action();
    };
  }

  @override
  Widget build(BuildContext context) {
    return CrawlSheet(
      title: listName,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (onMakeCrawl != null)
            CrawlSheetAction(
              title: 'Turn into a crawl',
              subtitle: 'Pick 3 to 6 of these cafes and visit them in order',
              onTap: _then(context, onMakeCrawl),
            ),
          if (onEdit != null)
            CrawlSheetAction(
              title: 'Edit list',
              subtitle: 'Name and description',
              onTap: _then(context, onEdit),
            ),
          if (onDelete != null)
            CrawlSheetAction(
              title: 'Delete list',
              destructive: true,
              onTap: _then(context, onDelete),
            ),
        ],
      ),
    );
  }
}
