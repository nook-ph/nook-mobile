import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nook/core/analytics/log_app_event.dart';
import 'package:nook/core/analytics/saver_survey_events.dart';
import 'package:nook/core/bloc/features/navigation/bloc/navigation_bloc.dart';
import 'package:nook/core/utils/toast_helper.dart';
import 'package:nook/features/guest_saves/presentation/cubit/guest_saves_cubit.dart';
import 'package:nook/features/home_page/bloc/home_bloc.dart';
import 'package:nook/features/home_page/bloc/home_states.dart';
import 'package:nook/features/saver_survey/data/save_dates_source.dart';
import 'package:nook/features/saver_survey/data/saver_survey_store.dart';
import 'package:nook/features/saver_survey/domain/saver_survey_reasons.dart';
import 'package:nook/features/saver_survey/presentation/saver_survey_gate.dart';
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
  });

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

  Future<void> _maybeShow() async {
    if (!_onHome) return;
    final decision = await _gate.evaluate();
    if (decision == null || !decision.show || !mounted || !_onHome) return;

    logAppEvent(
      SaverSurveyEvents.shown,
      properties: {
        'saves_count': decision.savesCount,
        'days_since_first_save': decision.daysSinceFirstSave,
        'signed_in':
            widget.isSignedIn?.call() ??
            Supabase.instance.client.auth.currentSession != null,
      },
    );
    final answer = await showSaverSurveySheet(context);
    if (answer == null) {
      logAppEvent(SaverSurveyEvents.skipped);
      return;
    }
    logAppEvent(SaverSurveyEvents.answered, properties: answer.analytics());
    if (mounted) showPrimaryToast(context, SaverSurveyCopy.thanks);
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
