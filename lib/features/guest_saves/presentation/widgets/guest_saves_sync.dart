import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nook/core/analytics/log_app_event.dart';
import 'package:nook/core/analytics/saves_events.dart';
import 'package:nook/core/analytics/screen_tracking.dart';
import 'package:nook/core/cafe/presentation/cafe_status_cubit.dart';
import 'package:nook/core/presentation/bottom_nav.dart';
import 'package:nook/core/presentation/session_ask_budget.dart';
import 'package:nook/core/utils/toast_helper.dart';
import 'package:nook/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:nook/features/guest_saves/presentation/cubit/guest_saves_cubit.dart';
import 'package:nook/features/guest_saves/presentation/cubit/recently_viewed_cubit.dart';
import 'package:nook/features/guest_saves/domain/sign_up_ask_rules.dart';
import 'package:nook/features/guest_saves/presentation/engagement_score.dart';
import 'package:nook/features/guest_saves/presentation/guest_saves_merger.dart';
import 'package:nook/injection_container.dart';
import 'package:nook/features/guest_saves/presentation/save_actions.dart';
import 'package:nook/features/guest_saves/presentation/widgets/merge_ask_sheet.dart';
import 'package:nook/features/lists/bloc/lists_bloc.dart';
import 'package:nook/features/lists/bloc/lists_event.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;

/// Keeps a guest's on-phone saves in step with the session, app-wide:
///
/// - while signed out, they are the statuses every badge and pill shows;
/// - on sign-in (and on any launch that is signed in with saves left over
///   from a failed attempt) they are moved to the account, in the
///   background: signing in never waits for it. Saves a failed merge into
///   another account left are not moved without asking ([MergeAskSheet]),
///   once per sign-in;
/// - on signing out, saves a merge could not move stay on the phone and
///   show as guest saves again (the ones it moved are the account's, and
///   are gone from the phone). Deleting the account drops the ones it
///   left.
///
/// Sits under `main.dart`'s providers, below the listener that resets the
/// status cache on sign-out, so its own work lands after that reset.
class GuestSavesSync extends StatefulWidget {
  const GuestSavesSync({
    super.key,
    required this.child,
    this.isSignedIn,
    this.toastContext,
  });

  final Widget child;

  /// Defaults to the Supabase session; tests pass their own.
  final bool Function()? isSignedIn;

  /// A context under the app's navigator, for the "Moved 3 cafes to your
  /// account" toast and the merge ask (this widget sits above it). Neither
  /// shows when null.
  final BuildContext? Function()? toastContext;

  @override
  State<GuestSavesSync> createState() => _GuestSavesSyncState();
}

class _GuestSavesSyncState extends State<GuestSavesSync> {
  late final GuestSavesMerger _merger = GuestSavesMerger(
    saves: context.read<GuestSavesCubit>(),
    statuses: context.read<CafeStatusCubit>(),
  );

  /// The account signed in, while one is.
  String? _accountId;

  /// The merge ask is on screen (or waiting for a sheet to close).
  bool _asking = false;

  bool get _signedIn =>
      widget.isSignedIn?.call() ??
      Supabase.instance.client.auth.currentSession != null;

  /// When the app was last sent to the background, to tell a new session
  /// (back after [SignUpAskRules.sessionGap]) from a quick switch.
  DateTime? _hiddenAt;
  late final AppLifecycleListener _lifecycle;

  void _onShow() {
    final hidden = _hiddenAt;
    _hiddenAt = null;
    if (hidden != null &&
        DateTime.now().difference(hidden) >= SignUpAskRules.sessionGap) {
      SessionAskBudget.instance.newSession();
      _recordSession();
    }
  }

  /// Debug builds only: `--dart-define=NOOK_PREVIEW_MERGE_TOAST=all` (or
  /// `partial`) shows the merge toast a few seconds after launch, to look at
  /// it without signing in to a real account.
  void _previewMergeToast() {
    if (!kDebugMode) return;
    const preview = String.fromEnvironment('NOOK_PREVIEW_MERGE_TOAST');
    if (preview.isEmpty) return;
    Future<void>.delayed(const Duration(seconds: 6), () {
      if (!mounted) return;
      final toast = widget.toastContext?.call();
      if (toast == null || !toast.mounted) return;
      showMergeToast(
        toast,
        preview == 'partial'
            ? const GuestMergeResult(added: 2, moved: 2, failed: 1)
            : const GuestMergeResult(added: 3, moved: 3, failed: 0),
        onRetry: () {},
      );
    });
  }

  void _recordSession() {
    if (!sl.isRegistered<EngagementScore>()) return;
    unawaited(sl<EngagementScore>().recordSession());
  }

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onHide: () => _hiddenAt = DateTime.now(),
      onShow: _onShow,
    );
    _recordSession();
    _previewMergeToast();
    unawaited(context.read<RecentlyViewedCubit>().load());
    final saves = context.read<GuestSavesCubit>();
    unawaited(
      saves.load().then((_) {
        if (!mounted) return;
        if (_signedIn) {
          // Only into a finished account: a session can exist mid sign-up
          // (the username step), and that account may yet be abandoned for
          // another. Otherwise the AuthAuthenticated listener merges.
          final auth = context.read<AuthBloc>().state;
          if (auth is AuthAuthenticated) _onSignedIn(auth.user.id);
        } else {
          _mirror();
        }
      }),
    );
  }

  void _mirror() {
    if (!mounted || _signedIn) return;
    context.read<CafeStatusCubit>().showLocal(
      context.read<GuestSavesCubit>().state.statusMap,
    );
  }

  /// Moves the saves that are [accountId]'s to take (made while signed
  /// out, or left by an earlier merge into it), then asks about any another
  /// account left, then says what moved in one toast.
  Future<void> _onSignedIn(String accountId) async {
    _accountId = accountId;
    var result = await _merge(accountId);
    if (!mounted) return;
    result += await _askAboutOthers(accountId);
    if (mounted && _accountId == accountId) _confirm(result, accountId);
  }

  Future<GuestMergeResult> _merge(
    String accountId, {
    bool includeOthers = false,
  }) async {
    final lists = context.read<ListsBloc>();
    final result = await _merger.merge(
      accountId: accountId,
      includeOthers: includeOthers,
    );
    // Saved-tab counts and previews come from the lists.
    if (result.added > 0 && mounted) lists.add(LoadUserLists());
    return result;
  }

  bool _stillSignedInAs(String accountId) {
    if (!mounted || _accountId != accountId) return false;
    final auth = context.read<AuthBloc>().state;
    return auth is AuthAuthenticated && auth.user.id == accountId;
  }

  /// Saves another account left on this phone: asked about once per
  /// sign-in, after any sheet already open closes, and moved only on "Add
  /// them". Otherwise they stay on the phone as guest saves, not this
  /// account's.
  Future<GuestMergeResult> _askAboutOthers(String accountId) async {
    if (_asking) return GuestMergeResult.none;
    final saves = context.read<GuestSavesCubit>();
    if ((await _merger.othersFor(accountId)).isEmpty) {
      return GuestMergeResult.none;
    }
    if (await saves.mergeAskedFor() == accountId) return GuestMergeResult.none;
    _asking = true;
    try {
      final sheetContext = await _clearNavigatorContext();
      if (sheetContext == null || !_stillSignedInAs(accountId)) {
        return GuestMergeResult.none;
      }
      final others = await _merger.othersFor(accountId);
      final count = others.length;
      if (count == 0 || !sheetContext.mounted || !_stillSignedInAs(accountId)) {
        return GuestMergeResult.none;
      }
      // Counted before it shows, so a sheet closed by the app going away
      // is not asked again this sign-in.
      await saves.setMergeAskedFor(accountId);
      if (!sheetContext.mounted) return GuestMergeResult.none;
      // A consequence of the sign-in, so it does not wait for the session's
      // budget; it takes it, so nothing else is pushed on top this session.
      SessionAskBudget.instance.spend(SessionAskKind.mergeAsk);
      logAppEvent(
        SavesEvents.guestSavesMergeAsked,
        properties: {'count': count},
      );
      dismissToasts();
      final answer = await MergeAskSheet.show(
        sheetContext,
        count: count,
        names: [for (final s in others) s.cafe.name],
      );
      logAppEvent(
        SavesEvents.guestSavesMergeAnswered,
        properties: {'count': count, 'answer': answer.wire},
      );
      if (answer != MergeAskAnswer.add || !_stillSignedInAs(accountId)) {
        return GuestMergeResult.none;
      }
      return await _merge(accountId, includeOthers: true);
    } finally {
      _asking = false;
    }
  }

  /// A context under the app's navigator with no sheet or dialog on top:
  /// waits for an open one to close, so the ask never stacks on it. Null
  /// when there is no navigator, or the screen never clears.
  Future<BuildContext?> _clearNavigatorContext() async {
    // Let the sign-in's own sheet or page finish closing first.
    await Future<void>.delayed(mergeAskDelay);
    for (var attempt = 0; attempt < 20; attempt++) {
      if (!mounted) return null;
      final context = widget.toastContext?.call();
      if (context == null || !context.mounted) return null;
      final navigator = Navigator.maybeOf(context);
      if (navigator == null) return null;
      Route<dynamic>? top;
      navigator.popUntil((route) {
        top = route;
        return true;
      });
      final open = top;
      if (open is! PopupRoute) return context;
      await open.popped;
      await Future<void>.delayed(mergeAskDelay);
    }
    return null;
  }

  void _confirm(GuestMergeResult result, String accountId) {
    final toast = widget.toastContext?.call();
    if (toast == null || !toast.mounted) return;
    showMergeToast(
      toast,
      result,
      onRetry: () => unawaited(
        _merge(accountId).then((r) {
          if (mounted && _accountId == accountId) _confirm(r, accountId);
        }),
      ),
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<AuthBloc, AuthState>(
          listenWhen: (previous, current) =>
              current is AuthAuthenticated && previous is! AuthAuthenticated,
          listener: (_, state) =>
              unawaited(_onSignedIn((state as AuthAuthenticated).user.id)),
        ),
        BlocListener<AuthBloc, AuthState>(
          listenWhen: (_, current) =>
              current is AuthLoggedOut ||
              current is AuthUnauthenticated ||
              current is AuthAccountDeleted,
          listener: (context, state) {
            final left = _accountId;
            _accountId = null;
            final saves = context.read<GuestSavesCubit>();
            // The session ended: the next sign-in asks again.
            unawaited(saves.setMergeAskedFor(null));
            if (state is AuthLoggedOut || state is AuthAccountDeleted) {
              context.read<RecentlyViewedCubit>().clear();
            }
            // Saves a merge could not move stay on the phone and show as
            // guest saves again; they keep the account they were meant for,
            // so they never move into another account without asking. A
            // deleted account's are dropped with it.
            if (state is AuthAccountDeleted && left != null) {
              unawaited(_merger.dropOwnedBy(left).whenComplete(_mirror));
            }
            // After the app's own listener has reset the status cache.
            scheduleMicrotask(_mirror);
          },
        ),
        BlocListener<GuestSavesCubit, GuestSavesState>(
          listener: (_, _) => _mirror(),
        ),
      ],
      child: widget.child,
    );
  }
}

/// The sheet promised "everything you saved on this phone moves to your
/// account": says that it did (with View, which opens Saved), or that some
/// did not and offers to try again. Nothing when there was nothing to move.
void showMergeToast(
  BuildContext context,
  GuestMergeResult result, {
  required VoidCallback onRetry,
  double? bottomOffset,
}) {
  final message = mergeToastMessage(result);
  if (message == null) return;
  // Above the tab bar when a tab is showing, so it never covers the Saved
  // tab its own View opens (review N7).
  final onTab = ScreenNames.tabs.contains(ScreenTracker.instance.current);
  final offset = bottomOffset ?? (onTab ? BottomNav.height.value : 0.0);
  if (result.failed == 0) {
    showPrimaryToastWithAction(
      context,
      message,
      actionLabel: mergeViewLabel,
      onAction: () {
        logAppEvent(
          SavesEvents.mergeToastViewTapped,
          properties: {'count': result.moved},
        );
        openSavedTab();
      },
      duration: toastDurationFor(context, const Duration(seconds: 6)),
      bottomOffset: offset,
    );
    return;
  }
  showPrimaryToastWithAction(
    context,
    message,
    actionLabel: mergeRetryLabel,
    onAction: onRetry,
    duration: toastDurationFor(context, const Duration(seconds: 8)),
    bottomOffset: offset,
  );
}

/// How long the merge ask waits after a sign-in, and after a sheet on top
/// closes, before it shows.
const mergeAskDelay = Duration(milliseconds: 600);

const mergeViewLabel = 'View';
const mergeRetryLabel = 'Retry';

/// "Moved 3 cafes to your account", "Moved 2 of 3 cafes to your account",
/// or "Couldn't move your saves yet"; null when there was nothing to move.
String? mergeToastMessage(GuestMergeResult result) {
  if (result.isEmpty) return null;
  String cafes(int n) => n == 1 ? '1 cafe' : '$n cafes';
  if (result.failed == 0) return 'Moved ${cafes(result.moved)} to your account';
  if (result.moved == 0) return "Couldn't move your saves yet";
  return 'Moved ${result.moved} of ${cafes(result.total)} to your account';
}
