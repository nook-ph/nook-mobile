import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nook/core/analytics/log_app_event.dart';
import 'package:nook/core/analytics/saves_events.dart';
import 'package:nook/core/cafe/domain/entities/cafe_status.dart';
import 'package:nook/core/cafe/presentation/cafe_status_cubit.dart';
import 'package:nook/core/presentation/session_ask_budget.dart';
import 'package:nook/core/utils/toast_helper.dart';
import 'package:nook/features/guest_saves/domain/cafe_snapshot.dart';
import 'package:nook/features/guest_saves/presentation/save_actions.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Cafe ids whose directions just opened a maps app (see
/// `launchCafeDirections`). A broadcast, so nothing breaks when no cafe page
/// is listening.
abstract final class DirectionsLaunches {
  static final _controller = StreamController<String>.broadcast();

  static Stream<String> get stream => _controller.stream;

  static void notify(String cafeId) {
    if (cafeId.isNotEmpty) _controller.add(cafeId);
  }
}

/// After directions to a cafe that is not saved, offers "Save to Want to
/// try?" with one tap, when the person comes back from the maps app. Asked
/// at most once per cafe per app session, and never for a cafe that already
/// has a status (or whose status could not be read).
///
/// One ask at each end of a trip: the visit reminder's ask owns the
/// Directions tap (it shows before Maps opens), this nudge owns the return,
/// and only when the cafe is still unsaved. It never lands on a sheet, and
/// a save from it does not also trigger the sign-up ask.
///
/// Owned by the cafe page's [State] (made in `initState`, disposed with it)
/// rather than wrapped around its tree; toasts go through that state's
/// context, which only needs the app-wide status cubits.
class DirectionsSaveNudge {
  DirectionsSaveNudge({
    required this.cafeId,
    required State host,
    required this.cafe,
    required this.toastOffset,
    bool Function()? isSignedIn,
  }) : _host = host,
       _isSignedIn = isSignedIn {
    _launches = DirectionsLaunches.stream
        .where((id) => id == cafeId)
        .listen((_) => _awaitReturn());
  }

  final String cafeId;
  final State _host;

  /// The loaded cafe, read when the nudge would show; null while loading.
  final CafeSnapshot? Function() cafe;

  /// Height of the pinned bar, so the toast lands above it.
  final double Function() toastOffset;

  /// Defaults to the Supabase session; tests pass their own.
  final bool Function()? _isSignedIn;

  static const message = 'Save to Want to try?';
  static const actionLabel = 'Save';

  /// When no trip to another app is seen (a split screen, a maps app that
  /// opened over this one), the nudge shows after this long instead.
  static const fallbackDelay = Duration(milliseconds: 1500);

  /// After coming back, so the toast does not land mid-transition.
  static const settleDelay = Duration(milliseconds: 600);

  /// How long the toast stays; with a screen reader on it stays until
  /// closed ([toastDurationFor]).
  static const duration = Duration(seconds: 10);

  static final Set<String> _nudged = {};

  /// Cafes whose nudge was offered on an open page and not taken: their
  /// Want to try pill stays tinted for the rest of the visit, so the offer
  /// is still where the person looks once the toast has gone.
  static final ValueNotifier<Set<String>> offered = ValueNotifier(const {});

  @visibleForTesting
  static void resetForTest() {
    _nudged.clear();
    offered.value = const {};
  }

  StreamSubscription<String>? _launches;
  AppLifecycleListener? _lifecycle;
  Timer? _timer;

  bool get _signedIn =>
      _isSignedIn?.call() ??
      Supabase.instance.client.auth.currentSession != null;

  void _awaitReturn() {
    if (_nudged.contains(cafeId)) return;
    _stopWaiting();
    // The maps app may already be in front by the time the launch is
    // reported: the listener below would then never see the trip, and the
    // fallback would show the nudge (and use it up) in the background.
    bool away() {
      final state = WidgetsBinding.instance.lifecycleState;
      return state != null && state != AppLifecycleState.resumed;
    }

    var wentAway = away();
    _lifecycle = AppLifecycleListener(
      onHide: () => wentAway = true,
      onPause: () => wentAway = true,
      onResume: () {
        _stopWaiting();
        _timer = Timer(settleDelay, _show);
      },
    );
    _timer = Timer(fallbackDelay, () {
      if (wentAway || away()) return;
      _stopWaiting();
      _show();
    });
  }

  void _stopWaiting() {
    _timer?.cancel();
    _timer = null;
    _lifecycle?.dispose();
    _lifecycle = null;
  }

  void _show() {
    if (!_host.mounted) return;
    if (_nudged.contains(cafeId)) return;
    final snapshot = cafe();
    if (snapshot == null) return;
    final context = _host.context;
    final signedIn = _signedIn;
    final statuses = context.read<CafeStatusCubit>().state;
    // Signed in, an unread status may be Been: asking to save it would read
    // as if Nook forgot the visit.
    if (signedIn && !statuses.isKnown(cafeId)) return;
    if (statuses.statusFor(cafeId) != CafeStatus.none) return;
    // Never over a sheet (the reminder ask's, the sign-up ask's): one ask
    // at a time. The pill tint below still offers it.
    final onTop = ModalRoute.of(context)?.isCurrent ?? true;

    _nudged.add(cafeId);
    offered.value = {...offered.value, cafeId};
    if (!onTop) return;
    final props = {'cafe_id': cafeId};
    logAppEvent(SavesEvents.directionsSaveNudgeShown, properties: props);
    // The trip's offer: no score sheet after it this session (review N5).
    SessionAskBudget.instance.blockScoreAsks(SessionAskKind.directionsNudge);
    final offset = toastOffset();
    showPrimaryToastWithAction(
      context,
      message,
      actionLabel: actionLabel,
      duration: toastDurationFor(context, duration),
      onAction: () {
        logAppEvent(SavesEvents.directionsSaveNudgeTapped, properties: props);
        if (!_host.mounted) return;
        unawaited(
          saveWantToTry(
            _host.context,
            cafe: snapshot,
            signedIn: _signedIn,
            bottomOffset: offset,
            source: SavesSource.directionsNudge,
          ),
        );
      },
      bottomOffset: offset,
    );
  }

  void dispose() {
    if (offered.value.contains(cafeId)) {
      offered.value = {...offered.value}..remove(cafeId);
    }
    _launches?.cancel();
    _launches = null;
    _stopWaiting();
  }
}
