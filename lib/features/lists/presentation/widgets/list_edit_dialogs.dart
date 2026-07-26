import 'package:flutter/material.dart';
import 'package:nook/core/extensions/extensions.dart';
import 'package:nook/core/presentation/widgets/adaptive_buttons.dart';

/// Rename / describe a list. Extracted from the Lists index when list options
/// moved onto the list itself — the index no longer carries a ⋮, so this is
/// reached from `ListDetailPage`.
class EditListDialog extends StatefulWidget {
  const EditListDialog({
    super.key,
    required this.currentName,
    required this.currentIsPublic,
    required this.onSave,
    this.currentDescription,
  });

  final String currentName;
  final String? currentDescription;
  final bool currentIsPublic;
  final void Function(String name, String? description, bool isPublic) onSave;

  @override
  State<EditListDialog> createState() => _EditListDialogState();
}

class _EditListDialogState extends State<EditListDialog> {
  static const _green = Color(0xFF344E41);

  late final TextEditingController _nameController;
  late final TextEditingController _descController;
  late bool _isPublic;

  String get _trimmedName => _nameController.text.trim();
  String get _trimmedDesc => _descController.text.trim();

  bool get _canSave {
    if (_trimmedName.isEmpty) return false;
    return _trimmedName != widget.currentName ||
        _trimmedDesc != (widget.currentDescription ?? '') ||
        _isPublic != widget.currentIsPublic;
  }

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.currentName)
      ..addListener(_onFormChanged);
    _descController = TextEditingController(
      text: widget.currentDescription ?? '',
    )..addListener(_onFormChanged);
    _isPublic = widget.currentIsPublic;
  }

  @override
  void dispose() {
    _nameController.removeListener(_onFormChanged);
    _descController.removeListener(_onFormChanged);
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  void _onFormChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Edit list', style: context.textTheme.titleMediumSemi),
            const SizedBox(height: 16),
            SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _nameController,
                    autofocus: true,
                    maxLength: 50,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: 'List name',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: _green, width: 2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _descController,
                    maxLines: 2,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _saveIfValid(context),
                    decoration: InputDecoration(
                      labelText: 'Description (Optional)',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: _green, width: 2),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                AdaptiveTextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  child: Text(
                    'Cancel',
                    style: context.textTheme.bodyMedium?.copyWith(
                      color: Colors.grey,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                AdaptiveElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF33523F),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                    elevation: 0,
                  ),
                  onPressed: _canSave ? () => _saveIfValid(context) : null,
                  child: Text(
                    'Save',
                    style: context.textTheme.bodySmallMed.copyWith(
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _saveIfValid(BuildContext context) {
    if (!_canSave) return;
    widget.onSave(
      _trimmedName,
      _trimmedDesc.isEmpty ? null : _trimmedDesc,
      _isPublic,
    );
    Navigator.pop(context);
  }
}

/// Confirms deleting a list. Resolves `true` only when the user commits.
Future<bool> showDeleteListConfirm(
  BuildContext context, {
  required String listName,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Delete list?', style: context.textTheme.titleMediumSemi),
            const SizedBox(height: 16),
            Text(
              '"$listName" will be permanently deleted. Cafes won\'t be deleted.',
              style: context.textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                AdaptiveTextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  child: Text(
                    'Cancel',
                    style: context.textTheme.bodyMedium?.copyWith(
                      color: Colors.grey,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                AdaptiveTextButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: Text(
                    'Delete',
                    style: context.textTheme.bodyMedium?.copyWith(
                      color: Colors.red,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );

  return confirmed ?? false;
}
