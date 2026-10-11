import 'package:flutter/material.dart';
import 'package:nook/core/analytics/log_app_event.dart';
import 'package:nook/core/analytics/profile_events.dart';
import 'package:nook/core/utils/toast_helper.dart';
import 'package:nook/features/cafe_details/presentation/widgets/review_actions_sheet.dart';
import 'package:nook/features/cafe_details/presentation/widgets/review_sheet_shell.dart';
import 'package:nook/features/gallery/data/read_only_gallery_repository.dart';
import 'package:nook/features/gallery/domain/entities/community_photo.dart';
import 'package:nook/features/gallery/domain/entities/gallery_photo.dart';
import 'package:nook/features/gallery/presentation/cubit/gallery_cubit.dart';
import 'package:nook/features/gallery/presentation/pages/gallery_viewer_page.dart';
import 'package:nook/features/public_profile/domain/i_public_profile_repository.dart';
import 'package:nook/features/public_profile/presentation/pages/public_profile_page.dart';
import 'package:nook/injection_container.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show Supabase;

/// A community photo's credit tapped, on the strip, the grid or the
/// viewer: logs it and opens their public profile. Your own does nothing.
void openPhotoAuthor(
  BuildContext context,
  PhotoCredit credit, {
  required String cafeId,
  required String surface,
}) {
  if (credit.isSelf) return;
  logAppEvent(
    CafePhotoEvents.authorTapped,
    properties: {'cafe_id': cafeId, 'surface': surface},
  );
  PublicProfilePage.open(
    context,
    userId: credit.userId,
    nameHint: '@${credit.username}',
    source: ProfileViewSource.cafePhotos,
  );
}

/// Opens [photos] full screen at [index], swiping through the ones already
/// loaded. Each shows who added it in place of the cafe chip; a signed-in
/// visitor can report someone else's.
Future<void> openCommunityPhotoViewer(
  BuildContext context, {
  required List<CommunityPhoto> photos,
  required int index,
  required String cafeId,
  required String surface,
}) async {
  logAppEvent(
    CafePhotoEvents.opened,
    properties: {'cafe_id': cafeId, 'surface': surface, 'position': index},
  );
  final credits = {for (final p in photos) p.id: p.credit};
  final cubit = GalleryCubit(
    repository: ReadOnlyGalleryRepository([for (final p in photos) p.photo]),
  );
  // In memory: done within the frame, so the viewer opens on its photo.
  await cubit.load();
  if (!context.mounted) {
    await cubit.close();
    return;
  }
  await GalleryViewerPage.open(
    context,
    cubit: cubit,
    photo: photos[index].photo,
    isOwner: false,
    onOpenCafe: null,
    creditOf: (photo) => credits[photo.id],
    onOpenAuthor: (credit) => openPhotoAuthor(
      context,
      credit,
      cafeId: cafeId,
      surface: CafePhotoSurface.viewer,
    ),
    onReport: _signedIn() ? (photo) => _report(context, photo, credits) : null,
  );
  await cubit.close();
}

/// Whether someone is signed in, so a "…" → Report makes sense.
bool communityPhotoReportable() => _signedIn();

/// "…" → Report on someone else's community photo, from the story viewer.
Future<void> reportCommunityPhoto(BuildContext context, CommunityPhoto photo) =>
    _report(context, photo.photo, {photo.id: photo.credit});

bool _signedIn() {
  try {
    return Supabase.instance.client.auth.currentUser != null;
  } catch (_) {
    return false;
  }
}

/// "…" on someone else's photo: why, then the report (as on a profile).
Future<void> _report(
  BuildContext context,
  GalleryPhoto photo,
  Map<String, PhotoCredit> credits,
) async {
  if (credits[photo.id]?.isSelf ?? false) return;
  final sent = await ReviewSheetShell.show<bool>(
    context,
    builder: (_) => ReportReasonSheet<PhotoReportReason>(
      title: 'Report this photo?',
      message:
          'For the photo or what it says. They won’t know who reported it.',
      reasons: PhotoReportReason.values,
      labelOf: (reason) => reason.label,
      onSubmit: (reason, details) async {
        await sl<IPublicProfileRepository>().reportPhoto(
          photo.id,
          reason,
          details: details.isEmpty ? null : details,
        );
        logAppEvent(
          ProfileEvents.photoReported,
          properties: {'reason': reason.wire},
        );
      },
    ),
  );
  if (sent == true && context.mounted) {
    showPrimaryToast(context, ReviewReportSheet.sentMessage);
  }
}
