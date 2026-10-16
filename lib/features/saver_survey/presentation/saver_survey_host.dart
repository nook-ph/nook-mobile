import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:nook/core/analytics/log_app_event.dart';
import 'package:nook/core/analytics/saver_survey_events.dart';
import 'package:nook/core/bloc/features/navigation/bloc/navigation_bloc.dart';
import 'package:nook/core/services/share_service.dart';
import 'package:nook/core/utils/toast_helper.dart';
import 'package:nook/features/guest_saves/domain/cafe_snapshot.dart';
import 'package:nook/features/guest_saves/presentation/cubit/guest_saves_cubit.dart';
import 'package:nook/features/home_page/bloc/home_bloc.dart';
import 'package:nook/features/home_page/bloc/home_event.dart';
import 'package:nook/features/home_page/bloc/home_states.dart';
import 'package:nook/features/saver_survey/data/save_dates_source.dart';
import 'package:nook/features/saver_survey/data/saver_survey_store.dart';
import 'package:nook/features/saver_survey/domain/saver_survey_follow_up.dart';
import 'package:nook/features/saver_survey/domain/saver_survey_reasons.dart';
import 'package:nook/features/saver_survey/domain/saver_survey_rules.dart';
import 'package:nook/features/saver_survey/presentation/saver_survey_gate.dart';
import 'package:nook/features/saver_survey/presentation/saver_survey_location.dart';
import 'package:nook/features/saver_survey/presentation/saver_survey_sheet.dart';
import 'package:nook/injection_container.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;

/// Opens the saver survey on Home at app open, when [SaverSurveyGate] says
/// so: once the feed has loaded and settled, and only while Home is the
/// screen on top. If the user has already moved on by then, this run skips
/// it rather than interrupting them.
class SaverSurveyHost extends StatefulWidget {
  const SaverSurveyHost({
    super.key,
    required this.child,
    this.gate,
    this.settle = const Duration(milliseconds: 1500),
    this.isSignedIn,
    this.location,
    this.openCafe,
    this.shareCafe,
  });

  /// Defaults to the device's; tests pass their own.
  final SaverSurveyLocation? location;

  /// "See cafe"; defaults to pushing the cafe page.
  final void Function(BuildContext context, CafeSnapshot cafe)? openCafe;

  /// "Share"; defaults to the cafe share sheet.
  final void Function(BuildContext context, CafeSnapshot cafe)? shareCafe;

  /// Defaults to the Supabase session; tests pass their own.
  final bool Function()? isSignedIn;

  final Widget child;

  /// Defaults to the app's; tests pass their own.
  final SaverSurveyGate? gate;

  /// How long Home sits loaded before the survey may open, so it never
  /// lands on top of the first frame or a prompt Home itself is showing.
  final Duration settle;

  @override
  State<SaverSurveyHost> createState() => _SaverSurveyHostState();
}

class _SaverSurveyHostState extends State<SaverSurveyHost> {
  late final SaverSurveyGate _gate = widget.gate ?? _appGate(context);
  bool _scheduled = false;
  Timer? _timer;

  static SaverSurveyGate _appGate(BuildContext context) {
    if (sl.isRegistered<SaverSurveyGate>()) return sl<SaverSurveyGate>();
    final guest = context.read<GuestSavesCubit>();
    return SaverSurveyGate(
      store: SaverSurveyStore(),
      saves: () => Supabase.instance.client.auth.currentSession != null
          ? AccountSaveDatesSource()
          : GuestSaveDatesSource(guest),
    );
  }

  @override
  void initState() {
    super.initState();
    unawaited(_gate.recordLaunch().catchError((_) => _noLaunch));
  }

  static const _noLaunch = LaunchRecord(openDays: 0, firstSession: true);

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _onHomeLoaded() {
    if (_scheduled) return;
    _scheduled = true;
    _timer = Timer(widget.settle, () => unawaited(_maybeShow()));
  }

  /// Home is the visible screen: the root route is on top and its tab is
  /// Home.
  bool get _onHome {
    if (!mounted) return false;
    if (ModalRoute.of(context)?.isCurrent == false) return false;
    try {
      return context.read<NavigationBloc>().state.tabIndex == 0;
    } catch (_) {
      return true; // Home on its own (tests).
    }
  }

  void _notShown(String? reason) {
    if (reason == null ||
        !SaverSurveyRules.reportedNoReasons.contains(reason)) {
      return;
    }
    if (!_gate.claimNotShownReport()) return;
    logAppEvent(SaverSurveyEvents.notShown, properties: {'reason': reason});
  }

  Future<void> _maybeShow() async {
    final decision = await _gate.evaluate();
    if (decision == null) return;
    if (!decision.show) return _notShown(decision.reason);
    // The user may have moved on while the saves were read: then this run
    // does not ask, and nothing is spent.
    if (!mounted || !_onHome) return _notShown('not_on_home');
    if (!_gate.commit()) return _notShown('session_prompt');

    logAppEvent(
      SaverSurveyEvents.shown,
      properties: {
        'saves_count': decision.savesCount,
        'days_since_first_save': decision.daysSinceFirstSave,
        'oldest_stale_days': decision.staleDays,
        'signed_in':
            widget.isSignedIn?.call() ??
            Supabase.instance.client.auth.currentSession != null,
      },
    );

    final location = widget.location ?? SaverSurveyLocation();
    var answered = false;
    var askedLocation = false;
    // The card on screen; set by the sheet only while it is still open.
    SaverSurveyFollowUp? shown;
    void showFollowUp(SaverSurveyFollowUp followUp) {
      shown = followUp;
      logAppEvent(
        SaverSurveyEvents.followUpShown,
        properties: {'kind': followUp.kind.wire},
      );
    }

    void tapped(SaverSurveyFollowUp followUp, String action) => logAppEvent(
      SaverSurveyEvents.followUpTapped,
      properties: {'kind': followUp.kind.wire, 'action': action},
    );

    final result = await showSaverSurveySheet(
      context,
      sheet: SaverSurveySheet(
        cafeName: decision.cafe?.name,
        days: decision.staleDays,
        onSend: (answer) async {
          answered = true;
          // The answer is recorded before anything else happens.
          logAppEvent(
            SaverSurveyEvents.answered,
            properties: answer.analytics(),
          );
          final far = answer.reasons.contains(SaverSurveyCopy.tooFar.id);
          final position = far ? await location.lastPosition() : null;
          final followUp = SaverSurveyFollowUps.pick(
            reasons: answer.reasons,
            cafe: decision.cafe,
            saves: decision.wantToTry,
            position: position,
            canAskLocation: far && position == null && await location.canAsk(),
          );
          return followUp;
        },
        onUseLocation: () async {
          askedLocation = true;
          final asked = shown;
          if (asked != null) tapped(asked, SaverSurveyActions.useLocation);
          final position = await location.ask();
          // Allowed from here: Home reloads so "Near you" shows behind the
          // sheet, as it does after Home's own ask.
          if (position != null && mounted) _reloadHome();
          final next = position == null
              ? null
              : SaverSurveyFollowUps.nearest(decision.wantToTry, position);
          return next;
        },
        onFollowUpShown: showFollowUp,
      ),
    );
    if (!mounted) return;
    if (!answered) {
      logAppEvent(SaverSurveyEvents.skipped);
      return;
    }
    if (result != null) {
      tapped(result.followUp, result.action);
      final cafe = result.followUp.cafe;
      if (cafe == null) return;
      if (result.action == SaverSurveyActions.seeCafe) {
        (widget.openCafe ?? _openCafe)(context, cafe);
      } else if (result.action == SaverSurveyActions.share) {
        (widget.shareCafe ?? _shareCafe)(context, cafe);
      }
      return;
    }
    final last = shown;
    if (last == null ||
        (last.kind == SaverSurveyFollowUpKind.locationAsk && askedLocation)) {
      // No card, or the location ask ended without a position.
      showPrimaryToast(context, SaverSurveyCopy.thanks);
      return;
    }
    // Closed with the close button, a swipe, the scrim or Back.
    tapped(last, SaverSurveyActions.close);
  }

  void _reloadHome() {
    try {
      context.read<HomeBloc>().add(LoadHomeDataEvent(refresh: true));
    } catch (_) {
      // No Home feed above (tests).
    }
  }

  static void _openCafe(BuildContext context, CafeSnapshot cafe) =>
      context.push('/cafe/${cafe.id}');

  static void _shareCafe(BuildContext context, CafeSnapshot cafe) {
    final box = context.findRenderObject() as RenderBox?;
    unawaited(
      sl<ShareService>().shareCafe(
        id: cafe.id,
        name: cafe.name,
        sharePositionOrigin: box == null
            ? null
            : box.localToGlobal(Offset.zero) & box.size,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<HomeBloc, HomeState>(
      listenWhen: (_, curr) => curr is HomeLoadedState,
      listener: (_, _) => _onHomeLoaded(),
      child: widget.child,
    );
  }
}
