import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:nook/core/analytics/analytics_service.dart';
import 'package:nook/core/analytics/log_app_event.dart';
import 'package:nook/core/analytics/saves_events.dart';
import 'package:nook/core/cafe/domain/entities/cafe_status.dart';
import 'package:nook/core/cafe/presentation/cafe_status_cubit.dart';
import 'package:nook/core/presentation/widgets/guest_sign_in_sheet.dart';
import 'package:nook/core/utils/toast_helper.dart';
import 'package:nook/features/guest_saves/data/guest_saves_store.dart';
import 'package:nook/features/guest_saves/domain/cafe_snapshot.dart';
import 'package:nook/features/guest_saves/presentation/cubit/guest_saves_cubit.dart';
import 'package:nook/features/lists/bloc/lists_bloc.dart';
import 'package:nook/features/lists/bloc/lists_event.dart';
import 'package:nook/injection_container.dart';

/// The copy of the one-time prompt after a guest's first save.
const keepSavesPromptMessage =
    'Saved on this phone. Sign in to keep it everywhere.';

/// The sign-in sheet's title and reason when a guest asks to keep their
/// saves (the first-save toast, the Saved tab card).
const keepSavesSheetTitle = 'Keep your saves on any phone';
const keepSavesSheetReason =
    'Sign in and everything you saved on this phone moves to your account.';

/// Opens the guest sign-in sheet with the keep-your-saves reason. Google or
/// Apple sign in right there (GuestSavesSync then moves the saves to the
/// account); email opens `/login`. [surface] is a [KeepSavesSurface] value.
Future<void> openKeepSavesSignIn(BuildContext context, String surface) =>
    GuestSignInSheet.show(
      context,
      icon: LucideIcons.bookmark,
      title: keepSavesSheetTitle,
      reason: keepSavesSheetReason,
      trigger: 'keep_saves_$surface',
    );

/// A guest tapped Been or Want to Try on [cafe]: kept on this phone, with
/// the same toggle rule as the signed-in pills (tapping the current status
/// clears it). Been skips the ranking flow, which needs an account.
///
/// Returns the status it set and whether the one-time sign-in prompt was
/// the confirmation, or null when nothing could be saved.
Future<({CafeStatus next, bool askedToSignIn})?> toggleGuestStatus(
  BuildContext context, {
  required CafeSnapshot cafe,
  required CafeStatus tapped,
  double bottomOffset = 0,
}) async {
  final saves = context.read<GuestSavesCubit>();
  await saves.load();
  final current = saves.state.statusFor(cafe.id);
  final next = current == tapped ? CafeStatus.none : tapped;
  if (next != CafeStatus.none) HapticFeedback.lightImpact();

  final outcome = await saves.set(cafe, next);
  if (!context.mounted) return null;
  if (outcome == null) {
    showPrimaryToast(
      context,
      "Couldn't save. Please try again.",
      bottomOffset: bottomOffset,
    );
    return null;
  }

  if (next == CafeStatus.none) {
    showPrimaryToastWithAction(
      context,
      current == CafeStatus.been
          ? 'Removed from Been'
          : 'Removed from Want to try',
      actionLabel: 'Undo',
      // The cubit is app-wide, so Undo works after leaving the page.
      onAction: () => unawaited(saves.set(cafe, current)),
      bottomOffset: bottomOffset,
    );
    return (next: next, askedToSignIn: false);
  }

  final asked = await _confirmGuestSave(
    context,
    saves: saves,
    status: next,
    bottomOffset: bottomOffset,
  );
  return (next: next, askedToSignIn: asked);
}

/// The toast after a guest's save: once per phone, the soft sign-in prompt;
/// afterwards the same words a signed-in save gets. True when it was the
/// sign-in prompt.
Future<bool> _confirmGuestSave(
  BuildContext context, {
  required GuestSavesCubit saves,
  required CafeStatus status,
  required double bottomOffset,
}) async {
  final prompt = await saves.claimKeepSavesPrompt();
  if (!context.mounted) return false;
  if (prompt) {
    showKeepSavesPrompt(context, bottomOffset: bottomOffset);
    return true;
  }
  showPrimaryToast(context, switch (status) {
    CafeStatus.been => 'Added to Been',
    _ => 'Saved for your next coffee run',
  }, bottomOffset: bottomOffset);
  return false;
}

/// "Saved on this phone. Sign in to keep it everywhere." A toast with a
/// Sign in action, never a wall: ignoring it keeps the save.
void showKeepSavesPrompt(BuildContext context, {double bottomOffset = 0}) {
  const surface = {'surface': KeepSavesSurface.firstSaveToast};
  logAppEvent(SavesEvents.keepSavesPromptShown, properties: surface);
  showPrimaryToastWithAction(
    context,
    keepSavesPromptMessage,
    actionLabel: 'Sign in',
    duration: const Duration(seconds: 6),
    onAction: () {
      logAppEvent(SavesEvents.keepSavesPromptTapped, properties: surface);
      if (context.mounted) {
        unawaited(
          openKeepSavesSignIn(context, KeepSavesSurface.firstSaveToast),
        );
      }
    },
    bottomOffset: bottomOffset,
  );
}

/// One tap to Want to Try, for a guest (on this phone) or an account (the
/// server, as the pills do it). A cafe that already has a status is left
/// alone. Returns whether it is now saved.
Future<bool> saveWantToTry(
  BuildContext context, {
  required CafeSnapshot cafe,
  required bool signedIn,
  double bottomOffset = 0,
}) async {
  if (!signedIn) {
    final saves = context.read<GuestSavesCubit>();
    await saves.load();
    if (saves.state.statusFor(cafe.id) != CafeStatus.none) return true;
    if (!context.mounted) return false;
    await toggleGuestStatus(
      context,
      cafe: cafe,
      tapped: CafeStatus.wantToTry,
      bottomOffset: bottomOffset,
    );
    return saves.state.statusFor(cafe.id) == CafeStatus.wantToTry;
  }

  final cubit = context.read<CafeStatusCubit>();
  final listsBloc = context.read<ListsBloc>();
  if (!cubit.state.isKnown(cafe.id)) await cubit.loadFor([cafe.id]);
  if (!context.mounted) return false;
  if (!cubit.state.isKnown(cafe.id)) {
    showPrimaryToast(
      context,
      "Couldn't save. Please try again.",
      bottomOffset: bottomOffset,
    );
    return false;
  }
  if (cubit.state.statusFor(cafe.id) != CafeStatus.none) return true;

  HapticFeedback.lightImpact();
  final ok = await cubit.set(cafe.id, CafeStatus.wantToTry);
  if (!context.mounted) return ok;
  if (!ok) {
    showPrimaryToast(
      context,
      "Couldn't save. Please try again.",
      bottomOffset: bottomOffset,
    );
    return false;
  }
  listsBloc.add(LoadUserLists());
  if (sl.isRegistered<AnalyticsService>()) {
    sl<AnalyticsService>().track(cafe.id, 'mark_want_to_try');
  }
  unawaited(recordSignedInSave(CafeStatus.wantToTry));
  showPrimaryToast(
    context,
    'Saved for your next coffee run',
    bottomOffset: bottomOffset,
  );
  return true;
}

/// `first_save` for a signed-in save, if it is the phone's first.
Future<void> recordSignedInSave(CafeStatus status) async {
  if (!sl.isRegistered<GuestSavesStore>()) return;
  await recordFirstSave(sl<GuestSavesStore>(), status, guest: false);
}
