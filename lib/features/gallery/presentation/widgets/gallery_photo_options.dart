import 'package:flutter/material.dart';
import 'package:nook/core/utils/content_filter.dart';
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
            title: photo.drinkName == null && photo.caption == null
                ? 'Add what you had'
                : 'Edit drink and note',
            subtitle:
                photo.drinkName ??
                photo.caption ??
                'The drink, and a line about it',
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
      final details = await showPhotoDetailsSheet(context, photo: photo);
      if (details == null || !context.mounted) return false;
      final ok = await cubit.setDetails(
        photo,
        drinkName: details.drink,
        caption: details.note,
      );
      if (!ok && context.mounted) {
        showPrimaryToast(context, "Couldn't save your changes. Try again.");
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

/// Asks for the drink and the note on [photo]. Returns both (empty text
/// clears), or null when dismissed. A review photo has no note: its review
/// says it.
Future<({String drink, String note})?> showPhotoDetailsSheet(
  BuildContext context, {
  required GalleryPhoto photo,
}) {
  return ListsSheet.show<({String drink, String note})>(
    context,
    builder: (_) => _PhotoDetailsSheet(photo: photo),
  );
}

class _PhotoDetailsSheet extends StatefulWidget {
  const _PhotoDetailsSheet({required this.photo});

  final GalleryPhoto photo;

  @override
  State<_PhotoDetailsSheet> createState() => _PhotoDetailsSheetState();
}

class _PhotoDetailsSheetState extends State<_PhotoDetailsSheet> {
  late final _drink = TextEditingController(text: widget.photo.drinkName);
  late final _note = TextEditingController(text: widget.photo.caption);
  String? _error;

  @override
  void dispose() {
    _drink.dispose();
    _note.dispose();
    super.dispose();
  }

  void _save() {
    final error = galleryTextError(_drink.text, _note.text);
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    Navigator.pop(context, (
      drink: _drink.text.trim(),
      note: _note.text.trim(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final error = _error;
    return ListsSheet(
      title: widget.photo.isFromReview ? 'What did you have?' : 'Edit photo',
      children: [
        DrinkNameField(
          controller: _drink,
          autofocus: true,
          onDone: widget.photo.isFromReview ? _save : null,
        ),
        if (!widget.photo.isFromReview) GalleryNoteField(controller: _note),
        if (error != null)
          Semantics(
            liveRegion: true,
            child: Text(error, style: listsText(13, color: ListsTokens.danger)),
          ),
        ListsPillButton(label: 'Save', onTap: _save),
      ],
    );
  }
}

/// The community-guidelines check for a photo's drink and note, as for
/// reviews and bios. Null when both are fine.
String? galleryTextError(String drink, String note) =>
    ContentFilter.containsObjectionable(drink) ||
        ContentFilter.containsObjectionable(note)
    ? ContentFilter.rejectionMessage
    : null;

/// The optional note on a photo: a few lines, with an n/150 counter inside
/// the field that turns dark near the limit (PayPal's counter;
/// docs/references/profile-v2).
class GalleryNoteField extends StatelessWidget {
  const GalleryNoteField({
    super.key,
    required this.controller,
    this.enabled = true,
  });

  final TextEditingController controller;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(ListsTokens.radius),
      borderSide: const BorderSide(color: ListsTokens.border),
    );
    return TextField(
      controller: controller,
      enabled: enabled,
      minLines: 2,
      maxLines: 4,
      maxLength: maxGalleryCaption,
      textCapitalization: TextCapitalization.sentences,
      style: listsText(16),
      buildCounter:
          (context, {required currentLength, required isFocused, maxLength}) {
            final near = currentLength >= maxGalleryCaption - 10;
            return Text(
              '$currentLength/$maxGalleryCaption',
              style: listsText(
                12,
                weight: near ? FontWeight.w600 : FontWeight.w400,
                color: near ? ListsTokens.ink : ListsTokens.muted,
              ),
            );
          },
      decoration: InputDecoration(
        labelText: 'Say something about it (optional)',
        labelStyle: listsText(14, color: ListsTokens.muted),
        alignLabelWithHint: true,
        hintText: 'Too sweet for me, but the foam held up.',
        hintStyle: listsText(16, color: ListsTokens.muted),
        border: border,
        enabledBorder: border,
        focusedBorder: border.copyWith(
          borderSide: const BorderSide(color: ListsTokens.brand, width: 1.5),
        ),
        contentPadding: const EdgeInsets.all(14),
      ),
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
