import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nook/core/analytics/log_app_event.dart';
import 'package:nook/core/analytics/profile_events.dart';
import 'package:nook/core/block/block_cubit.dart';
import 'package:nook/core/cafe/domain/entities/report_reason.dart';
import 'package:nook/core/utils/toast_helper.dart';
import 'package:nook/features/cafe_details/presentation/widgets/cafe_guest_sign_in_sheet.dart';
import 'package:nook/features/cafe_details/presentation/widgets/review_actions_sheet.dart';
import 'package:nook/features/cafe_details/presentation/widgets/review_sheet_shell.dart';
import 'package:nook/features/cups/domain/entities/cup.dart';
import 'package:nook/features/cups/domain/i_cups_repository.dart';
import 'package:nook/features/cups/presentation/cubit/cafe_cups_cubit.dart';
import 'package:nook/features/cups/presentation/widgets/cup_composer_sheet.dart';
import 'package:nook/features/cups/data/cups_community_photos_repository.dart';
import 'package:nook/features/gallery/domain/entities/picked_cafe.dart';
import 'package:nook/features/gallery/presentation/widgets/community_photo_actions.dart';
import 'package:nook/injection_container.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show Supabase;

String? _signedInUserId() {
  try {
    return Supabase.instance.client.auth.currentUser?.id;
  } catch (_) {
    return null;
  }
}

/// "Add your cup" / "Edit your cup" from anywhere: a guest gets the sign-in
/// sheet (and the composer after signing in, through
/// [CafeGuestAction.writeReview]); everyone else the composer.
Future<CupComposerOutcome?> startCup(
  BuildContext context, {
  required PickedCafe cafe,
  required String source,
  CupCard? editing,
  String? note,
  List<CupMenuOption> menu = const [],
  double toastOffset = 0,
  ValueGetter<String?>? currentUserId,
}) async {
  final me = (currentUserId ?? _signedInUserId)();
  if (me == null) {
    await CafeGuestSignInSheet.show(
      context,
      action: CafeGuestAction.writeReview,
      cafeId: cafe.id,
      cafeName: cafe.name,
    );
    return null;
  }
  return openCupComposer(
    context,
    cafe: cafe,
    source: source,
    editing: editing,
    note: note,
    menu: menu,
    toastOffset: toastOffset,
  );
}

/// Opens [card]'s photos full screen at [index].
Future<void> openCupPhotos(
  BuildContext context, {
  required CupCard card,
  required int index,
  required String cafeId,
  required String cafeName,
}) => openCommunityPhotoViewer(
  context,
  photos: cupPhotosToCommunity(card, cafeId: cafeId, cafeName: cafeName),
  index: index,
  cafeId: cafeId,
  surface: CafePhotoSurface.grid,
);

/// Helpful on someone else's card through [cubit], or the sign-in sheet
/// for a guest. Says so when it doesn't go through.
Future<void> toggleCupHelpful(
  BuildContext context, {
  required CafeCupsCubit cubit,
  required CupCard card,
  double toastOffset = 0,
  ValueGetter<String?>? currentUserId,
}) async {
  if (card.isMine || !card.canVote) return;
  if ((currentUserId ?? _signedInUserId)() == null) {
    await CafeGuestSignInSheet.show(
      context,
      action: CafeGuestAction.helpfulReview,
    );
    return;
  }
  try {
    if (!await cubit.toggleHelpful(card)) return;
    logAppEvent(
      CupEvents.helpfulToggled,
      properties: {
        'cafe_id': cubit.cafeId,
        'voted': !card.hasVoted,
        'target': card.cupId != null ? 'cup' : 'review',
      },
    );
  } catch (_) {
    if (!context.mounted) return;
    showPrimaryToast(
      context,
      "Couldn't update. Please try again.",
      bottomOffset: toastOffset,
    );
  }
}

/// "…" on a card. Yours: Edit or Delete. Someone else's: Report or Block
/// (a guest is asked to sign in first).
Future<void> showCupOptions(
  BuildContext context, {
  required CupCard card,
  required String cafeId,
  required String cafeName,
  required VoidCallback onEdit,
  required VoidCallback onChanged,
  double toastOffset = 0,
  ICupsRepository? repository,
  ValueGetter<String?>? currentUserId,
}) async {
  final repo = repository ?? sl<ICupsRepository>();
  if (card.isMine) {
    final choice = await ReviewSheetShell.show<ReviewOption>(
      context,
      builder: (_) => ReviewOptionsSheet.forOwnCup(cafeName: cafeName),
    );
    if (!context.mounted) return;
    if (choice == ReviewOption.edit) {
      onEdit();
      return;
    }
    if (choice != ReviewOption.delete) return;
    final confirmed = await ReviewSheetShell.show<bool>(
      context,
      builder: (_) => ReviewConfirmSheet.deleteCup(cafeName: cafeName),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await repo.deleteCup(card);
      logAppEvent(
        CupEvents.deleted,
        properties: {'cafe_id': cafeId, 'backend': repo.mode.name},
      );
      if (!context.mounted) return;
      showPrimaryToast(context, 'Cup deleted', bottomOffset: toastOffset);
      onChanged();
    } catch (_) {
      if (!context.mounted) return;
      showPrimaryToast(
        context,
        "Couldn't delete your cup. Please try again.",
        bottomOffset: toastOffset,
      );
    }
    return;
  }

  final choice = await ReviewSheetShell.show<ReviewOption>(
    context,
    builder: (_) => ReviewOptionsSheet.forOtherCup(authorLabel: card.label),
  );
  if (choice == null || !context.mounted) return;
  if ((currentUserId ?? _signedInUserId)() == null) {
    await CafeGuestSignInSheet.show(
      context,
      action: CafeGuestAction.reportReview,
    );
    return;
  }
  final target = card.cupId != null
      ? 'cup'
      : card.reviewId != null
      ? 'review'
      : 'photos';

  if (choice == ReviewOption.report) {
    final sent = await ReviewSheetShell.show<bool>(
      context,
      builder: (_) => ReviewReportSheet(
        title: 'Why are you reporting this cup?',
        onSubmit: (reason, details) async {
          await repo.reportCup(
            card,
            cafeId: cafeId,
            reason: reason,
            details: details,
          );
          logAppEvent(
            CupEvents.reported,
            properties: {
              'cafe_id': cafeId,
              'reason': reason.code,
              'target': target,
            },
          );
        },
      ),
    );
    if (sent == true && context.mounted) {
      showPrimaryToast(
        context,
        ReviewReportSheet.sentMessage,
        bottomOffset: toastOffset,
      );
    }
    return;
  }

  if (choice == ReviewOption.block) {
    final blockCubit = context.read<BlockCubit>();
    final confirmed = await ReviewSheetShell.show<bool>(
      context,
      builder: (_) => ReviewConfirmSheet.blockUser(authorName: card.label),
    );
    if (confirmed != true) return;
    try {
      // Best-effort: the block is what must happen.
      try {
        await repo.reportCup(
          card,
          cafeId: cafeId,
          reason: ReportReason.inappropriateContent,
          details: 'Auto-filed when the reporter blocked this user.',
        );
      } catch (_) {}
      await blockCubit.block(card.userId);
      logAppEvent(ProfileEvents.userBlocked, properties: {'from': 'cup'});
      if (!context.mounted) return;
      showPrimaryToast(
        context,
        '${card.label} blocked. Their content is now hidden.',
        bottomOffset: toastOffset,
      );
      onChanged();
    } catch (_) {
      if (!context.mounted) return;
      showPrimaryToast(
        context,
        'Could not block this user. Please try again.',
        bottomOffset: toastOffset,
      );
    }
  }
}
