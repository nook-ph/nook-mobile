import 'package:flutter/material.dart';
import 'package:nook/core/cafe/domain/entities/cafe_summary.dart';
import 'package:nook/core/utils/toast_helper.dart';
import 'package:nook/features/gallery/data/gallery_photo_picker.dart';
import 'package:nook/features/gallery/domain/entities/gallery_photo.dart';
import 'package:nook/features/gallery/domain/entities/picked_cafe.dart';
import 'package:nook/features/gallery/domain/i_cafe_picker_source.dart';
import 'package:nook/features/gallery/presentation/cubit/gallery_cubit.dart';
import 'package:nook/core/analytics/profile_events.dart';
import 'package:nook/features/cups/domain/i_cups_repository.dart';
import 'package:nook/features/cups/presentation/widgets/cup_composer_sheet.dart';
import 'package:nook/features/gallery/presentation/widgets/cafe_picker_sheet.dart';
import 'package:nook/features/lists/presentation/widgets/lists_ui.dart';

/// What the gallery's two "add" journeys need. One object so callers (the
/// profile tab, the ranking reveal) pass one thing, and tests one fake.
class GalleryFlowDeps {
  const GalleryFlowDeps({
    required this.cubit,
    required this.picker,
    required this.cafes,
    this.cups,
  });

  final GalleryCubit cubit;
  final GalleryPhotoPicker picker;
  final ICafePickerSource cafes;

  /// Where cups are posted; the registered repository when null.
  final ICupsRepository? cups;
}

const _pickFailed =
    "Couldn't open your photos. Check Nook's photo access in Settings.";

/// + on the profile: pick photos → which cafe → the cup composer. One
/// cafe for the batch (docs/ux/coffee-gallery.md, journey 3).
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

  // The photos become a new cup at that cafe (a cup is a visit), through
  // the same composer as everywhere else.
  final outcome = await openCupComposer(
    context,
    cafe: cafe,
    source: CupSource.profile,
    photos: photos,
    repository: deps.cups,
  );
  if (outcome != null) await deps.cubit.load(refresh: true);
}

/// The ranking reveal's "Add a photo of what you had": camera or library,
/// then the cup composer for this visit with the photo in it. Returns the
/// photo when the cup was posted, or null when the person backed out or
/// it failed (they were told).
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

  final outcome = await openCupComposer(
    context,
    cafe: cafe,
    source: CupSource.rankReveal,
    photos: [photo],
    repository: deps.cups,
  );
  return outcome == null ? null : photo;
}

enum _Source { camera, library }
