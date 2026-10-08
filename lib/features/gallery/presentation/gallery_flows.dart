import 'package:flutter/material.dart';
import 'package:nook/core/cafe/domain/entities/cafe_summary.dart';
import 'package:nook/core/utils/toast_helper.dart';
import 'package:nook/features/gallery/data/gallery_photo_picker.dart';
import 'package:nook/features/gallery/domain/entities/gallery_photo.dart';
import 'package:nook/features/gallery/domain/entities/picked_cafe.dart';
import 'package:nook/features/gallery/domain/i_cafe_picker_source.dart';
import 'package:nook/features/gallery/presentation/cubit/gallery_cubit.dart';
import 'package:nook/features/gallery/presentation/widgets/add_gallery_photos_sheet.dart';
import 'package:nook/features/gallery/presentation/widgets/cafe_picker_sheet.dart';
import 'package:nook/features/lists/presentation/widgets/lists_ui.dart';

/// What the gallery's two "add" journeys need. One object so callers (the
/// profile tab, the ranking reveal) pass one thing, and tests one fake.
class GalleryFlowDeps {
  const GalleryFlowDeps({
    required this.cubit,
    required this.picker,
    required this.cafes,
  });

  final GalleryCubit cubit;
  final GalleryPhotoPicker picker;
  final ICafePickerSource cafes;
}

const _pickFailed =
    "Couldn't open your photos. Check Nook's photo access in Settings.";

/// + on the Gallery tab: pick photos → which cafe → add. One cafe for the
/// batch (docs/ux/coffee-gallery.md, journey 3).
Future<void> addPhotosToGallery(
  BuildContext context,
  GalleryFlowDeps deps,
) async {
  List<PickedGalleryPhoto> photos;
  try {
    photos = await deps.picker.pickMany();
  } catch (_) {
    if (context.mounted) showPrimaryToast(context, _pickFailed);
    return;
  }
  if (photos.isEmpty || !context.mounted) return;

  // The first photo that knows where it was taken suggests the cafe. A
  // failed lookup is just no suggestion.
  final located = photos.where((p) => p.hasLocation).firstOrNull;
  final Future<CafeSummary?>? takenHere = located == null
      ? null
      : deps.cafes
            .takenAt(located.latitude!, located.longitude!)
            .then<CafeSummary?>((c) => c, onError: (Object _) => null);

  Future<PickedCafe?> pickCafe() => showCafePickerSheet(
    context,
    source: deps.cafes,
    takenHere: takenHere,
    photoCount: photos.length,
  );

  final cafe = await pickCafe();
  if (cafe == null || !context.mounted) return;

  // The sheet only starts the upload and closes: the photos then wait in
  // the grid with a progress bar, and a failed one offers Retry there
  // (Figma E2), so nothing holds the person or can be lost by a swipe.
  Future<({int added, int failed})>? upload;
  final started = await showAddGalleryPhotosSheet(
    context,
    photos: photos,
    cafe: cafe,
    onChangeCafe: pickCafe,
    onSave: ({required cafe, required photos, drinkName, caption}) async {
      upload = deps.cubit.upload(
        cafeId: cafe.id,
        photos: photos,
        source: GalleryPhotoSource.gallery,
        drinkName: drinkName,
        caption: caption,
      );
    },
  );
  final pending = upload;
  if (!started || pending == null) return;
  final count = photos.length;
  if (context.mounted) {
    showPrimaryToast(
      context,
      count == 1
          ? 'Adding your photo to your gallery…'
          : 'Adding $count photos to your gallery…',
    );
  }
  final result = await pending;
  if (!context.mounted) return;
  if (result.failed == 0) {
    showPrimaryToast(
      context,
      result.added == 1
          ? 'Photo added to your gallery'
          : '${result.added} photos added',
    );
  } else {
    showPrimaryToast(
      context,
      result.failed == 1
          ? "A photo didn't upload. Tap Retry on it."
          : "${result.failed} photos didn't upload. Tap Retry on them.",
    );
  }
}

/// The ranking reveal's "Add a photo of what you had": camera or library,
/// then the add sheet with the cafe fixed. Returns the photo that was added,
/// or null when the person backed out or it failed (they were told).
Future<PickedGalleryPhoto?> addRankPhoto(
  BuildContext context,
  GalleryFlowDeps deps, {
  required PickedCafe cafe,
}) async {
  final source = await ListsSheet.show<_Source>(
    context,
    builder: (sheetContext) => ListsSheet(
      title: 'Add a photo',
      gap: 4,
      children: [
        ListsSheetAction(
          title: 'Take a photo',
          onTap: () => Navigator.pop(sheetContext, _Source.camera),
        ),
        ListsSheetAction(
          title: 'Choose from library',
          onTap: () => Navigator.pop(sheetContext, _Source.library),
        ),
      ],
    ),
  );
  if (source == null || !context.mounted) return null;

  PickedGalleryPhoto? photo;
  try {
    photo = source == _Source.camera
        ? await deps.picker.takePhoto()
        : await deps.picker.pickOne();
  } catch (_) {
    if (context.mounted) showPrimaryToast(context, _pickFailed);
    return null;
  }
  if (photo == null || !context.mounted) return null;

  final saved = await showAddGalleryPhotosSheet(
    context,
    photos: [photo],
    cafe: cafe,
    waitsForUpload: true,
    onSave: ({required cafe, required photos, drinkName, caption}) =>
        deps.cubit.addPhotos(
          cafeId: cafe.id,
          photos: photos,
          source: GalleryPhotoSource.rank,
          drinkName: drinkName,
          caption: caption,
        ),
  );
  return saved ? photo : null;
}

enum _Source { camera, library }
