import 'package:nook/core/analytics/auth_events.dart';
import 'package:nook/core/analytics/log_app_event.dart';
import 'package:nook/features/auth/presentation/bloc/auth_bloc.dart';

/// Sends a funnel event. Swappable in tests.
typedef AuthEventLogger =
    void Function(String name, Map<String, Object> properties);

void _logToPostHog(String name, Map<String, Object> properties) =>
    logAppEvent(name, properties: properties);

/// Follows one sign-in attempt through [AuthBloc] and reports where it began
/// and whether it ended signed in ([AuthEvents.signinStarted],
/// [AuthEvents.signinCompleted]), plus a closed Google or Apple sheet.
///
/// Fed by the bloc's own `onEvent` and `onChange`, so every page and sheet is
/// covered without each one logging. A session restored at launch is not an
/// attempt and reports nothing.
class AuthFunnel {
  AuthFunnel({AuthEventLogger? log}) : _log = log ?? _logToPostHog;

  final AuthEventLogger _log;

  String? _method;
  String _surface = AuthSurface.login;
  bool _newAccount = false;

  /// The method of the attempt in progress, if any.
  String? get method => _method;

  void onEvent(AuthEvent event) {
    switch (event) {
      case AuthSignInWithGoogleEvent(:final surface):
        _start(AuthMethod.google, surface);
      case AuthSignInWithAppleEvent(:final surface):
        _start(AuthMethod.apple, surface);
      case AuthCheckEmailEvent(:final surface):
        _start(AuthMethod.email, surface);
      default:
        break;
    }
  }

  void onChange(AuthState current, AuthState next) {
    final method = _method;
    if (method == null) return;

    if ((next is AuthEmailChecked && !next.exists) ||
        next is AuthAwaitingEmailConfirmation ||
        next is AuthNeedsUsername) {
      _newAccount = true;
      return;
    }

    if (next is AuthAuthenticated) {
      _log(AuthEvents.signinCompleted, {
        'method': method,
        'surface': _surface,
        'new_account': _newAccount,
      });
      _reset();
      return;
    }

    if (next is AuthUnauthenticated || next is AuthLoggedOut) {
      // Google and Apple report a closed sheet by going straight back to
      // signed out; nothing else ends a provider attempt that way. Once the
      // provider has answered with a new account (the username step), a
      // sign-out is that step's to report (AuthStepTracker), not a cancel.
      final provider =
          method == AuthMethod.google || method == AuthMethod.apple;
      if (provider && current is AuthLoading && !_newAccount) {
        _log(AuthEvents.signinStepAbandoned, {
          'step': AuthStep.provider,
          'reason': AuthAbandonReason.cancelled,
          'method': method,
        });
      }
      _reset();
    }
  }

  void _start(String method, String surface) {
    _method = method;
    _surface = surface;
    _newAccount = false;
    _log(AuthEvents.signinStarted, {'method': method, 'surface': surface});
  }

  void _reset() {
    _method = null;
    _surface = AuthSurface.login;
    _newAccount = false;
  }
}
