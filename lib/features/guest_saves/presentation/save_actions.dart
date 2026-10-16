import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:nook/core/analytics/analytics_service.dart';
import 'package:nook/core/analytics/saves_events.dart';
import 'package:nook/core/cafe/domain/entities/cafe_status.dart';
import 'package:nook/core/cafe/presentation/cafe_status_cubit.dart';
import 'package:nook/core/presentation/pages/main_screen.dart';
import 'package:nook/core/presentation/tab_requests.dart';
import 'package:nook/core/presentation/widgets/guest_sign_in_sheet.dart';
import 'package:nook/features/auth/presentation/widgets/sign_in_choices.dart';
import 'package:nook/core/utils/toast_helper.dart';
import 'package:nook/features/guest_saves/data/guest_saves_store.dart';
import 'package:nook/features/guest_saves/domain/cafe_snapshot.dart';
import 'package:nook/features/guest_saves/presentation/engagement_score.dart';
import 'package:nook/features/guest_saves/presentation/cubit/guest_saves_cubit.dart';
import 'package:nook/features/lists/bloc/lists_bloc.dart';
import 'package:nook/features/lists/bloc/lists_event.dart';
import 'package:nook/injection_container.dart';

/// Opens the Saved tab from anywhere: a toast's "View", the merge toast.
void openSavedTab() => TabRequests.open(MainShell.savedTab);

/// The line after a guest's first save: where it went, with Undo and View
/// (View also shows where saves live). Short, so it fits beside both
/// actions at large text (review N8). Not an ask: that comes from the
/// engagement score.
const firstSaveMessage = 'Saved on this phone';

/// After later saves: where it went, with View (Saved) and Undo.
String savedToMessage(CafeStatus status) =>
    status == CafeStatus.been ? 'Added to Been' : 'Saved to Want to try';
const saveUndoLabel = 'Undo';
const saveViewLabel = 'View';

/// The first-save line stays this long (or, with a screen reader on, until
/// closed).
const firstSaveDuration = Duration(seconds: 10);

/// The sign-in sheet's title and reason when a guest asks to keep their
/// saves (the first-save toast, the Saved tab card).
const keepSavesSheetTitle = 'Keep your saves on any phone';
const keepSavesSheetReason =
    'Sign in and everything you saved on this phone moves to your account.';

/// Opens the guest sign-in sheet with the keep-your-saves reason. Google or
/// Apple sign in right there (GuestSavesSync then moves the saves to the
/// account); email opens `/login`. [surface] is a [KeepSavesSurface] value.
Future<SignInChoice?> openKeepSavesSignIn(
  BuildContext context,
  String surface,
) => GuestSignInSheet.show(
  context,
  icon: LucideIcons.bookmark,
  title: keepSavesSheetTitle,
  reason: keepSavesSheetReason,
  trigger: 'keep_saves_$surface',
);

/// The sheet after a guest's "I went" on the visit reminder: the cafe is
/// already marked Been on this phone; ranking it needs an account.
const reminderSignInTitle = 'Sign in to add it to your ranking';
String reminderSignInReason(String cafeName) {
  final name = cafeName.trim().isEmpty ? 'This cafe' : cafeName.trim();
  return '$name is marked Been on this phone. Sign in to say how it was '
      'and rank it.';
}

/// "I went" on the visit reminder, for a guest: marks [cafe] Been on this
/// phone (unless it already is), then the one follow-up, the keep-saves
/// sign-in with a reason about ranking. Skipping it keeps the Been.
Future<void> markBeenFromReminder(
  BuildContext context, {
  required CafeSnapshot cafe,
}) async {
  final saves = context.read<GuestSavesCubit>();
  await saves.load();
  if (saves.state.statusFor(cafe.id) != CafeStatus.been) {
    HapticFeedback.lightImpact();
    final outcome = await setGuestStatus(
      saves,
      cafe,
      CafeStatus.been,
      source: SavesSource.reminder,
    );
    if (!context.mounted) return;
    if (outcome == null) {
      showPrimaryToast(context, "Couldn't save. Please try again.");
    }
  }
  if (!context.mounted) return;
  dismissToasts();
  await GuestSignInSheet.show(
    context,
    icon: LucideIcons.listOrdered,
    title: reminderSignInTitle,
    reason: reminderSignInReason(cafe.name),
    trigger: 'keep_saves_${KeepSavesSurface.reminder}',
  );
}

/// A guest tapped Been or Want to Try on [cafe]: kept on this phone, with
/// the same toggle rule as the signed-in pills (tapping the current status
/// clears it). Been skips the ranking flow, which needs an account.
/// [source] is a [SavesSource] value when the tap was not a plain one.
Future<void> toggleGuestStatus(
  BuildContext context, {
  required CafeSnapshot cafe,
  required CafeStatus tapped,
  double bottomOffset = 0,
  String? source,
}) async {
  final saves = context.read<GuestSavesCubit>();
  await saves.load();
  final current = saves.state.statusFor(cafe.id);
  final next = current == tapped ? CafeStatus.none : tapped;
  if (next != CafeStatus.none) HapticFeedback.lightImpact();

  final outcome = await setGuestStatus(
    saves,
    cafe,
    next,
    source: next == CafeStatus.none ? source ?? SavesSource.pill : source,
  );
  if (!context.mounted) return;
  if (outcome == null) {
    showPrimaryToast(
      context,
      "Couldn't save. Please try again.",
      bottomOffset: bottomOffset,
    );
    return;
  }

  if (next == CafeStatus.none) {
    showPrimaryToastWithAction(
      context,
      current == CafeStatus.been
          ? 'Removed from Been'
          : 'Removed from Want to try',
      actionLabel: saveUndoLabel,
      // The cubit is app-wide, so Undo works after leaving the page.
      onAction: () => unawaited(undoGuestStatus(saves, cafe, next, outcome)),
      // Undo matters most here: no timeout with a screen reader on (N6).
      duration: toastDurationFor(context, const Duration(seconds: 5)),
      bottomOffset: bottomOffset,
    );
    return;
  }

  await _confirmGuestSave(
    context,
    saves: saves,
    cafe: cafe,
    status: next,
    outcome: outcome,
    bottomOffset: bottomOffset,
    source: source,
  );
}

/// Sets [cafe]'s on-phone status and keeps the engagement score in step: a
/// new save earns its points once per cafe, and removing or undoing it
/// takes them back (ux finding 7). Null when the phone could not store it.
Future<GuestSaveOutcome?> setGuestStatus(
  GuestSavesCubit saves,
  CafeSnapshot cafe,
  CafeStatus status, {
  String? source,
}) async {
  final outcome = await saves.set(cafe, status, source: source);
  if (outcome == null || !sl.isRegistered<EngagementScore>()) return outcome;
  final engagement = sl<EngagementScore>();
  if (status == CafeStatus.none && outcome.previous != CafeStatus.none) {
    await engagement.recordUnsave(cafe.id);
  } else if (status != CafeStatus.none && outcome.previous == CafeStatus.none) {
    await engagement.recordSave(cafe.id);
  }
  return outcome;
}

/// Undo on a guest's save toast: puts back what [outcome]'s change to
/// [changedTo] replaced, keeping the engagement score in step as
/// [setGuestStatus] does.
Future<void> undoGuestStatus(
  GuestSavesCubit saves,
  CafeSnapshot cafe,
  CafeStatus changedTo,
  GuestSaveOutcome outcome,
) async {
  if (!await saves.undo(cafe.id, outcome)) return;
  if (!sl.isRegistered<EngagementScore>()) return;
  final engagement = sl<EngagementScore>();
  final restored = outcome.previous;
  if (restored == CafeStatus.none && changedTo != CafeStatus.none) {
    await engagement.recordUnsave(cafe.id);
  } else if (restored != CafeStatus.none && changedTo == CafeStatus.none) {
    await engagement.recordSave(cafe.id);
  }
}

/// The cafe page's top-right bookmark, for a guest: Want to try on this
/// phone, the same toggle as the pill. On a Been cafe it does not switch
/// silently (review N3): it says so and offers the move.
Future<void> guestTopSave(
  BuildContext context, {
  required CafeSnapshot cafe,
  double bottomOffset = 0,
}) async {
  final saves = context.read<GuestSavesCubit>();
  await saves.load();
  if (!context.mounted) return;
  if (saves.state.statusFor(cafe.id) == CafeStatus.been) {
    showPrimaryToastWithAction(
      context,
      alreadyBeenMessage,
      actionLabel: moveToWantToTryLabel,
      onAction: () {
        if (!context.mounted) return;
        unawaited(
          toggleGuestStatus(
            context,
            cafe: cafe,
            tapped: CafeStatus.wantToTry,
            bottomOffset: bottomOffset,
            source: SavesSource.topSave,
          ),
        );
      },
      duration: toastDurationFor(context, const Duration(seconds: 5)),
      bottomOffset: bottomOffset,
    );
    return;
  }
  await toggleGuestStatus(
    context,
    cafe: cafe,
    tapped: CafeStatus.wantToTry,
    bottomOffset: bottomOffset,
    source: SavesSource.topSave,
  );
}

const alreadyBeenMessage = 'Already in Been';
const moveToWantToTryLabel = 'Move to Want to try';

/// After a guest's save: the engagement score's ask when it is due (a save
/// is a value moment), else a toast saying where the save went. Once per
/// phone that is the "Saved on this phone" line; after it, "Saved to Want
/// to try". Both have Undo and View. An ask that ends without a sign-in is
/// followed by the usual toast, so the save is still confirmed (N4).
Future<void> _confirmGuestSave(
  BuildContext context, {
  required GuestSavesCubit saves,
  required CafeSnapshot cafe,
  required CafeStatus status,
  required GuestSaveOutcome outcome,
  required double bottomOffset,
  String? source,
}) async {
  final engagement = sl.isRegistered<EngagementScore>()
      ? sl<EngagementScore>()
      : null;
  var asked = false;
  // One ask per trip: the directions nudge was this trip's, so its save
  // only confirms.
  if (engagement != null && source != SavesSource.directionsNudge) {
    final result = await engagement.maybeAsk(
      context,
      trigger: SignUpAskTrigger.afterSave,
      savesCount: saves.state.saves.length,
      saved: SignUpAskSave(cafeName: cafe.name, status: status),
    );
    // Email went on to /login: no save toast over the login screen (its
    // View would pop it).
    if (result == SignUpAskResult.signedIn ||
        result == SignUpAskResult.signInStarted ||
        !context.mounted) {
      return;
    }
    asked = result.shown;
  }

  void undo() => unawaited(undoGuestStatus(saves, cafe, status, outcome));
  final firstLine = !asked && await saves.claimFirstSaveLine();
  if (!context.mounted) return;
  showPrimaryToastWithAction(
    context,
    firstLine ? firstSaveMessage : savedToMessage(status),
    secondaryActionLabel: saveUndoLabel,
    onSecondaryAction: undo,
    actionLabel: saveViewLabel,
    onAction: openSavedTab,
    duration: toastDurationFor(
      context,
      firstLine ? firstSaveDuration : const Duration(seconds: 5),
    ),
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
  String? source,
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
      source: source,
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
