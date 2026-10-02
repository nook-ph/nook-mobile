import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nook/features/lists/presentation/widgets/list_tokens.dart';
import 'package:nook/features/lists/presentation/widgets/lists_ui.dart';

/// What the New list and Edit list sheets resolve with.
class ListFormInput {
  const ListFormInput({required this.name, this.description});

  final String name;
  final String? description;
}

/// Longest list name the sheets accept.
const listNameLimit = 50;

/// Asks for a new list's name and description (Figma "New list sheet").
/// Resolves null when the sheet is closed without creating.
Future<ListFormInput?> showCreateListSheet(BuildContext context) {
  return ListsSheet.show<ListFormInput>(
    context,
    builder: (_) => const ListFormSheet(),
  );
}

/// Edits a list's name and description (Figma "Edit list sheet"). Resolves
/// null when nothing was saved.
Future<ListFormInput?> showEditListSheet(
  BuildContext context, {
  required String name,
  String? description,
}) {
  return ListsSheet.show<ListFormInput>(
    context,
    builder: (_) =>
        ListFormSheet(initialName: name, initialDescription: description ?? ''),
  );
}

/// The form behind both sheets. With an [initialName] it is the edit sheet:
/// the title and button change, and Save stays dimmed until something
/// differs. Create stays dimmed until a name is typed.
class ListFormSheet extends StatefulWidget {
  const ListFormSheet({super.key, this.initialName, this.initialDescription});

  final String? initialName;
  final String? initialDescription;

  @override
  State<ListFormSheet> createState() => _ListFormSheetState();
}

class _ListFormSheetState extends State<ListFormSheet> {
  late final TextEditingController _name = TextEditingController(
    text: widget.initialName ?? '',
  )..addListener(_onChanged);
  late final TextEditingController _description = TextEditingController(
    text: widget.initialDescription ?? '',
  )..addListener(_onChanged);

  bool get _isEdit => widget.initialName != null;
  String get _trimmedName => _name.text.trim();
  String get _trimmedDescription => _description.text.trim();

  bool get _canSubmit {
    if (_trimmedName.isEmpty) return false;
    if (!_isEdit) return true;
    return _trimmedName != widget.initialName!.trim() ||
        _trimmedDescription != (widget.initialDescription ?? '').trim();
  }

  void _onChanged() => setState(() {});

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_canSubmit) return;
    Navigator.of(context).pop(
      ListFormInput(
        name: _trimmedName,
        description: _trimmedDescription.isEmpty ? null : _trimmedDescription,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final length = _name.text.characters.length;
    final atLimit = length >= listNameLimit;

    return ListsSheet(
      title: _isEdit ? 'Edit list' : 'New list',
      gap: 16,
      children: [
        _Field(
          label: 'List name',
          counter: '$length / $listNameLimit',
          // Reaching the limit turns the count and the stroke red: the field
          // will not take another character.
          warn: atLimit,
          child: _input(
            controller: _name,
            hint: 'e.g., Cebu Specialty Spots',
            autofocus: true,
            warn: atLimit,
            maxLength: listNameLimit,
            textInputAction: TextInputAction.next,
          ),
        ),
        _Field(
          label: 'Description (optional)',
          child: SizedBox(
            height: 88,
            child: _input(
              controller: _description,
              hint: 'What is this list for?',
              expands: true,
              textInputAction: TextInputAction.newline,
            ),
          ),
        ),
        ListsPillButton(
          label: _isEdit ? 'Save' : 'Create',
          onTap: _canSubmit ? _submit : null,
        ),
      ],
    );
  }

  Widget _input({
    required TextEditingController controller,
    required String hint,
    bool autofocus = false,
    bool warn = false,
    bool expands = false,
    int? maxLength,
    TextInputAction? textInputAction,
  }) {
    OutlineInputBorder border(Color color, double width) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(ListsTokens.radius),
      borderSide: BorderSide(color: color, width: width),
    );

    return TextField(
      controller: controller,
      autofocus: autofocus,
      expands: expands,
      maxLines: expands ? null : 2,
      minLines: expands ? null : 1,
      textAlignVertical: TextAlignVertical.top,
      textCapitalization: TextCapitalization.sentences,
      textInputAction: textInputAction,
      inputFormatters: [
        if (maxLength != null) LengthLimitingTextInputFormatter(maxLength),
      ],
      cursorColor: ListsTokens.brand,
      style: listsText(14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: listsText(14, color: ListsTokens.muted),
        isDense: true,
        filled: true,
        fillColor: ListsTokens.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 13,
        ),
        enabledBorder: warn
            ? border(ListsTokens.danger, 1.5)
            : border(ListsTokens.border, 1),
        focusedBorder: border(
          warn ? ListsTokens.danger : ListsTokens.brand,
          1.5,
        ),
      ),
    );
  }
}

/// A Medium 12 label with an optional count on the right, 6 above its input.
class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.child,
    this.counter,
    this.warn = false,
  });

  final String label;
  final Widget child;
  final String? counter;
  final bool warn;

  @override
  Widget build(BuildContext context) {
    final count = counter;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(label, style: listsText(12, weight: FontWeight.w500)),
            ),
            if (count != null)
              Text(
                count,
                style: listsText(
                  12,
                  color: warn ? ListsTokens.danger : ListsTokens.muted,
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}

/// Confirms deleting a list (Figma "Delete list dialog"). Resolves true only
/// when Delete is tapped.
Future<bool> showDeleteListConfirm(
  BuildContext context, {
  required String listName,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    barrierColor: const Color(0x66000000),
    builder: (dialogContext) => Dialog(
      backgroundColor: ListsTokens.surface,
      surfaceTintColor: ListsTokens.surface,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 30),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Delete list?', style: listsText(16, weight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(
              '"$listName" will be permanently deleted. '
              "Cafes won't be deleted.",
              style: listsText(14, color: ListsTokens.muted),
            ),
            // The design's 8 spacer between two 8 gaps.
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: ListsPillButton(
                    label: 'Cancel',
                    style: ListsPillStyle.outlined,
                    height: 44,
                    onTap: () => Navigator.of(dialogContext).pop(false),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ListsPillButton(
                    label: 'Delete',
                    style: ListsPillStyle.danger,
                    height: 44,
                    onTap: () => Navigator.of(dialogContext).pop(true),
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
