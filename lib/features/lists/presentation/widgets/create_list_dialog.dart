import 'package:flutter/material.dart';
import 'package:nook/core/extensions/extensions.dart';
import 'package:nook/core/presentation/widgets/adaptive_buttons.dart';
import 'package:nook/core/utils/toast_helper.dart';

class CreateListInput {
  const CreateListInput({
    required this.name,
    this.description,
  });

  final String name;
  final String? description;
}

class CreateListDialog extends StatefulWidget {
  const CreateListDialog({super.key});

  // To re-enable the public/private switch used by ListsPage's FAB, add
  // `final bool showPublicSwitch;` to the constructor (default false), a
  // `bool _isPublic = false;` to the State, and uncomment the SwitchListTile
  // inside the SingleChildScrollView in the build method below.

  @override
  State<CreateListDialog> createState() => _CreateListDialogState();
}

class _CreateListDialogState extends State<CreateListDialog> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.0),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Create New List',
              style: context.textTheme.titleMediumSemi,
            ),
            const SizedBox(height: 16),
            SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _nameController,
                    autofocus: true,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: 'List Name',
                      hintText: 'e.g., Cebu Specialty Spots',
                      labelStyle: TextStyle(
                        color: context.colorScheme.primary100,
                      ),
                      floatingLabelStyle: TextStyle(
                        color: context.colorScheme.primary100,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.0),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.0),
                        borderSide: const BorderSide(
                          color: Color(0xFF33523F),
                          width: 2.0,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _descController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: 'Description (Optional)',
                      hintText: 'What is this list for?',
                      labelStyle: TextStyle(
                        color: context.colorScheme.primary100,
                      ),
                      floatingLabelStyle: TextStyle(
                        color: context.colorScheme.primary100,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.0),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.0),
                        borderSide: const BorderSide(
                          color: Color(0xFF33523F),
                          width: 2.0,
                        ),
                      ),
                    ),
                  ),
                  // const SizedBox(height: 8),
                  // SwitchListTile(
                  //   contentPadding: EdgeInsets.zero,
                  //   title: Text(
                  //     'Public list',
                  //     style: context.textTheme.bodyLargeMed,
                  //   ),
                  //   subtitle: Text(
                  //     'Anyone can view this list',
                  //     style: context.textTheme.bodySmall?.copyWith(color: Colors.grey),
                  //   ),
                  //   value: _isPublic,
                  //   activeColor: const Color(0xFF344E41),
                  //   onChanged: (val) => setState(() => _isPublic = val),
                  // ),
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
                    foregroundColor: context.colorScheme.onSurface,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  child: Text(
                    'Cancel',
                    style: context.textTheme.bodyMedium?.copyWith(color: Colors.grey),
                  ),
                ),
                const SizedBox(width: 8),
                AdaptiveElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF33523F),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                    elevation: 0,
                  ),
                  onPressed: _submit,
                  child: Text(
                    'Create',
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

  void _submit() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      showPrimaryToast(context, 'List name is required.');
      return;
    }

    final description = _descController.text.trim();
    Navigator.pop(
      context,
      CreateListInput(
        name: name,
        description: description.isEmpty ? null : description,
      ),
    );
  }
}
