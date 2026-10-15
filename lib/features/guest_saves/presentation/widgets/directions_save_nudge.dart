import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nook/core/analytics/log_app_event.dart';
import 'package:nook/core/analytics/saves_events.dart';
import 'package:nook/core/cafe/domain/entities/cafe_status.dart';
import 'package:nook/core/cafe/presentation/cafe_status_cubit.dart';
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
/// Try?" with one tap, when the person comes back from the maps app. Asked
/// at most once per cafe per app session, and never for a cafe that already
/// has a status (or whose status could not be read).
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

  static final Set<String> _nudged = {};

  @visibleForTesting
  static void resetForTest() => _nudged.clear();

  StreamSubscription<String>? _launches;
  AppLifecycleListener? _lifecycle;
  Timer? _timer;

  bool get _signedIn =>
      _isSignedIn?.call() ??
      Supabase.instance.client.auth.currentSession != null;

  void _awaitReturn() {
    if (_nudged.contains(cafeId)) return;
    _stopWaiting();
    var wentAway = false;
    _lifecycle = AppLifecycleListener(
      onHide: () => wentAway = true,
      onPause: () => wentAway = true,
      onResume: () {
        _stopWaiting();
        _timer = Timer(settleDelay, _show);
      },
    );
    _timer = Timer(fallbackDelay, () {
      if (wentAway) return;
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

    _nudged.add(cafeId);
    final props = {'cafe_id': cafeId};
    logAppEvent(SavesEvents.directionsSaveNudgeShown, properties: props);
    final offset = toastOffset();
    showPrimaryToastWithAction(
      context,
      message,
      actionLabel: actionLabel,
      duration: const Duration(seconds: 6),
      onAction: () {
        logAppEvent(SavesEvents.directionsSaveNudgeTapped, properties: props);
        if (!_host.mounted) return;
        unawaited(
          saveWantToTry(
            _host.context,
            cafe: snapshot,
            signedIn: _signedIn,
            bottomOffset: offset,
          ),
        );
      },
      bottomOffset: offset,
    );
  }

  void dispose() {
    _launches?.cancel();
    _launches = null;
    _stopWaiting();
  }
}
