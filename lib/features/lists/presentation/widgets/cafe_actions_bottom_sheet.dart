import 'package:flutter/material.dart';
import 'package:nook/features/lists/presentation/widgets/lists_ui.dart';

/// The ⋯ sheet of a cafe inside a list (Figma "Cafe actions sheet").
class CafeActionsBottomSheet extends StatelessWidget {
  const CafeActionsBottomSheet({
    super.key,
    required this.cafeName,
    required this.listName,
    required this.onViewDetails,
    required this.onRemove,
  });

  final String cafeName;

  /// Named under Remove, so it is clear the cafe only leaves this list.
  final String listName;
  final VoidCallback onViewDetails;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return ListsSheet(
      title: cafeName,
      gap: 2,
      children: [
        ListsSheetAction(
          title: 'View details',
          onTap: () {
            Navigator.pop(context);
            onViewDetails();
          },
        ),
        ListsSheetAction(
          title: 'Remove from list',
          subtitle: 'Only removes it from $listName',
          destructive: true,
          onTap: () {
            Navigator.pop(context);
            onRemove();
          },
        ),
      ],
    );
  }
}
