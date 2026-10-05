import 'package:flutter/material.dart';
import 'package:nook/core/utils/toast_helper.dart';
import 'package:nook/features/gallery/domain/entities/gallery_photo.dart';
import 'package:nook/features/gallery/presentation/cubit/gallery_cubit.dart';
import 'package:nook/features/lists/presentation/widgets/list_tokens.dart';
import 'package:nook/features/lists/presentation/widgets/lists_ui.dart';

/// What the owner can do to one photo. Delete is last and red; a review
/// photo offers its review instead, because deleting it here would quietly
/// edit a public review (docs/ux/coffee-gallery.md, finding 7).
///
/// Returns true when the photo was deleted, so a viewer showing it can move
/// on. [onOpenReview] is null where there is no review page to open.
Future<bool> showGalleryPhotoOptions(
  BuildContext context, {
  required GalleryCubit cubit,
  required GalleryPhoto photo,
  VoidCallback? onOpenReview,
}) async {
  final choice = await ListsSheet.show<_Option>(
    context,
    builder: (sheetContext) {
      final pinned = cubit.state.pinnedCount;
      return ListsSheet(
        title: 'Photo options',
        gap: 4,
        children: [
          if (!photo.isHidden)
            ListsSheetAction(
              title: photo.isPinned ? 'Unpin' : 'Pin to top',
              subtitle: photo.isPinned
                  ? 'It goes back to its place by date.'
                  : 'Pinned photos show first · $pinned of $maxGalleryPins '
                        'pinned',
              onTap: () => Navigator.pop(sheetContext, _Option.pin),
            ),
          ListsSheetAction(
            title: photo.drinkName == null ? 'Add what you had' : 'Edit drink',
            subtitle: photo.drinkName ?? 'Like "Iced Spanish latte"',
            onTap: () => Navigator.pop(sheetContext, _Option.drink),
          ),
          ListsSheetAction(
            title: photo.isHidden ? 'Show on profile' : 'Hide from profile',
            subtitle: photo.isHidden
                ? 'Everyone can see it again.'
                : 'Only you will see it. You can show it again any time.',
            onTap: () => Navigator.pop(sheetContext, _Option.hide),
          ),
          if (photo.isFromReview)
            ListsSheetAction(
              title: 'Part of your review',
              subtitle: onOpenReview == null
                  ? 'Remove it from the review to delete it.'
                  : 'Open your reviews to remove it there.',
              onTap: () => Navigator.pop(sheetContext, _Option.review),
            )
          else
            ListsSheetAction(
              title: 'Delete photo',
              subtitle: 'Removes it from your gallery for good.',
              destructive: true,
              onTap: () => Navigator.pop(sheetContext, _Option.delete),
            ),
        ],
      );
    },
  );
  if (!context.mounted || choice == null) return false;

  switch (choice) {
    case _Option.pin:
      final outcome = await cubit.togglePin(photo);
      if (!context.mounted) return false;
      switch (outcome) {
        case PinOutcome.full:
          showPrimaryToast(
            context,
            'You can pin $maxGalleryPins photos. Unpin one first.',
          );
        case PinOutcome.failed:
          showPrimaryToast(context, "Couldn't update the photo. Try again.");
        case PinOutcome.pinned:
          showPrimaryToast(context, 'Pinned to the top of your gallery');
        case PinOutcome.unpinned:
          break;
      }
      return false;
    case _Option.drink:
      final drink = await showDrinkNameSheet(context, initial: photo.drinkName);
      if (drink == null || !context.mounted) return false;
      final ok = await cubit.setDrinkName(photo, drink);
      if (!ok && context.mounted) {
        showPrimaryToast(context, "Couldn't save the drink. Try again.");
      }
      return false;
    case _Option.hide:
      final hide = !photo.isHidden;
      final ok = await cubit.setHidden(photo, hidden: hide);
      if (!context.mounted) return false;
      showPrimaryToast(
        context,
        !ok
            ? "Couldn't update the photo. Try again."
            : hide
            ? 'Hidden from your profile'
            : 'Showing on your profile',
      );
      return false;
    case _Option.review:
      onOpenReview?.call();
      return false;
    case _Option.delete:
      final sure = await _confirmDelete(context);
      if (sure != true || !context.mounted) return false;
      final ok = await cubit.delete(photo);
      if (!context.mounted) return ok;
      showPrimaryToast(
        context,
        ok ? 'Photo deleted' : "Couldn't delete the photo. Try again.",
      );
      return ok;
  }
}

enum _Option { pin, drink, hide, review, delete }

Future<bool?> _confirmDelete(BuildContext context) {
  return ListsSheet.show<bool>(
    context,
    builder: (sheetContext) => ListsSheet(
      title: 'Delete this photo?',
      children: [
        Text(
          "It leaves your gallery and your profile. This can't be undone.",
          style: listsText(14, color: ListsTokens.muted),
        ),
        ListsPillButton(
          label: 'Delete photo',
          style: ListsPillStyle.danger,
          onTap: () => Navigator.pop(sheetContext, true),
        ),
        ListsTextButton(
          label: 'Cancel',
          onTap: () => Navigator.pop(sheetContext, false),
        ),
      ],
    ),
  );
}

/// Asks for the drink in a photo. Returns the text (empty clears it), or
/// null when dismissed.
Future<String?> showDrinkNameSheet(BuildContext context, {String? initial}) {
  return ListsSheet.show<String>(
    context,
    builder: (_) => _DrinkNameSheet(initial: initial),
  );
}

class _DrinkNameSheet extends StatefulWidget {
  const _DrinkNameSheet({this.initial});

  final String? initial;

  @override
  State<_DrinkNameSheet> createState() => _DrinkNameSheetState();
}

class _DrinkNameSheetState extends State<_DrinkNameSheet> {
  late final _controller = TextEditingController(text: widget.initial ?? '');

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() => Navigator.pop(context, _controller.text.trim());

  @override
  Widget build(BuildContext context) {
    return ListsSheet(
      title: 'What did you have?',
      children: [
        DrinkNameField(controller: _controller, autofocus: true, onDone: _save),
        ListsPillButton(label: 'Save', onTap: _save),
      ],
    );
  }
}

/// The optional drink field, shared by the add sheet and the edit sheet.
class DrinkNameField extends StatelessWidget {
  const DrinkNameField({
    super.key,
    required this.controller,
    this.autofocus = false,
    this.onDone,
    this.enabled = true,
  });

  final TextEditingController controller;
  final bool autofocus;
  final bool enabled;
  final VoidCallback? onDone;

  @override
  Widget build(BuildContext context) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(ListsTokens.radius),
      borderSide: const BorderSide(color: ListsTokens.border),
    );
    return TextField(
      controller: controller,
      autofocus: autofocus,
      enabled: enabled,
      maxLength: 60,
      textCapitalization: TextCapitalization.sentences,
      textInputAction: TextInputAction.done,
      onSubmitted: (_) => onDone?.call(),
      style: listsText(16),
      decoration: InputDecoration(
        labelText: 'Drink (optional)',
        labelStyle: listsText(14, color: ListsTokens.muted),
        hintText: 'Iced Spanish latte',
        hintStyle: listsText(16, color: ListsTokens.muted),
        counterText: '',
        border: border,
        enabledBorder: border,
        focusedBorder: border.copyWith(
          borderSide: const BorderSide(color: ListsTokens.brand, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
      ),
    );
  }
}
