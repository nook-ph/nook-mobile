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
import 'package:nook/features/lists/bloc/lists_bloc.dart';
import 'package:nook/features/lists/bloc/lists_event.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;

/// Keeps a guest's on-phone saves in step with the session, app-wide:
///
/// - while signed out, they are the statuses every badge and pill shows;
/// - on sign-in (and on any launch that is signed in with saves left over
///   from a failed attempt) they are moved to the account, in the
///   background: signing in never waits for it;
/// - on signing out of an account, saves a merge left behind are dropped.
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
  /// account" toast (this widget sits above it). No toast when null.
  final BuildContext? Function()? toastContext;

  @override
  State<GuestSavesSync> createState() => _GuestSavesSyncState();
}

class _GuestSavesSyncState extends State<GuestSavesSync> {
  late final GuestSavesMerger _merger = GuestSavesMerger(
    saves: context.read<GuestSavesCubit>(),
    statuses: context.read<CafeStatusCubit>(),
  );

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
      _confirm(
        preview == 'partial'
            ? const GuestMergeResult(added: 2, moved: 2, failed: 1)
            : const GuestMergeResult(added: 3, moved: 3, failed: 0),
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
          _merge();
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

  Future<void> _merge() async {
    final lists = context.read<ListsBloc>();
    final result = await _merger.merge();
    // Saved-tab counts and previews come from the lists.
    if (result.added > 0 && mounted) lists.add(LoadUserLists());
    if (mounted) _confirm(result);
  }

  void _confirm(GuestMergeResult result) {
    final toast = widget.toastContext?.call();
    if (toast == null || !toast.mounted) return;
    showMergeToast(toast, result, onRetry: () => unawaited(_merge()));
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
          listener: (_, _) => unawaited(_merge()),
        ),
        BlocListener<AuthBloc, AuthState>(
          listenWhen: (_, current) =>
              current is AuthLoggedOut ||
              current is AuthUnauthenticated ||
              current is AuthAccountDeleted,
          listener: (context, state) {
            if (state is AuthLoggedOut || state is AuthAccountDeleted) {
              context.read<RecentlyViewedCubit>().clear();
              // Saves that failed to reach the account that just left are
              // not the next guest's, nor the next account's.
              unawaited(_merger.discardLeftovers().whenComplete(_mirror));
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
