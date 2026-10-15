import 'package:flutter/widgets.dart';
import 'package:nook/core/analytics/auth_events.dart';
import 'package:nook/features/auth/presentation/auth_funnel.dart';
import 'package:nook/core/analytics/log_app_event.dart';
import 'package:nook/features/auth/presentation/bloc/auth_bloc.dart';

/// Whether [state] means [step] is behind the user: the flow moved on to
/// the next step or finished.
bool authStepFinished(String step, AuthState state) {
  final signedIn = state is AuthAuthenticated || state is AuthNeedsUsername;
  return switch (step) {
    AuthStep.details ||
    AuthStep.password => signedIn || state is AuthAwaitingEmailConfirmation,
    AuthStep.otp => signedIn,
    AuthStep.username => state is AuthAuthenticated,
    _ => signedIn,
  };
}

/// Reports [AuthEvents.signinStepAbandoned] when a sign-in step's page is
/// left, or the app goes to the background, before the step is done.
///
/// A step's page owns one: create it in `initState`, call [dispose] from the
/// page's `dispose`. Whether the step finished is read from the bloc's state
/// at that moment ([authStepFinished]), so a page does not have to mark
/// success itself. Reports once per visit.
class AuthStepTracker with WidgetsBindingObserver {
  AuthStepTracker({
    required this.step,
    required AuthState Function() currentState,
    String? Function()? method,
    this.reportBackground = true,
    AuthEventLogger? log,
  }) : _currentState = currentState,
       _method = method,
       _log = log ?? _logToPostHog {
    WidgetsBinding.instance.addObserver(this);
  }

  /// One of [AuthStep].
  final String step;

  /// False on the code step: people leave the app there to read the email,
  /// so going to the background is the expected path, not an exit.
  final bool reportBackground;

  final AuthState Function() _currentState;
  final String? Function()? _method;
  final AuthEventLogger _log;
  bool _settled = false;

  static void _logToPostHog(String name, Map<String, Object> properties) =>
      logAppEvent(name, properties: properties);

  /// Reports the step abandoned for [reason] unless it is done or already
  /// reported.
  void abandon(String reason) {
    if (_settled) return;
    if (authStepFinished(step, _currentState())) {
      _settled = true;
      return;
    }
    _settled = true;
    final method = _method?.call();
    _log(AuthEvents.signinStepAbandoned, {
      'step': step,
      'reason': reason,
      'method': ?method,
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (reportBackground && state == AppLifecycleState.paused) {
      abandon(AuthAbandonReason.background);
    }
  }

  /// Stops listening; a step that is still open counts as left.
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    abandon(AuthAbandonReason.left);
  }
}
