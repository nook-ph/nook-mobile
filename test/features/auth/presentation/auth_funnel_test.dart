import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/core/analytics/auth_events.dart';
import 'package:nook/features/auth/presentation/auth_funnel.dart';
import 'package:nook/features/auth/presentation/auth_step_tracker.dart';
import 'package:nook/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;

const _user = User(
  id: 'user-1',
  appMetadata: {},
  userMetadata: {},
  aud: 'authenticated',
  email: 'maria.cruz@gmail.com',
  createdAt: '2026-09-01T00:00:00Z',
);

typedef _Logged = Map<String, Object>;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AuthFunnel', () {
    late List<_Logged> logged;
    late AuthFunnel funnel;
    late AuthState state;

    setUp(() {
      logged = [];
      funnel = AuthFunnel(
        log: (name, props) => logged.add({'event': name, ...props}),
      );
      state = const AuthUnauthenticated();
    });

    void go(AuthState next) {
      funnel.onChange(state, next);
      state = next;
    }

    test('Google from a sheet: started, then completed', () {
      funnel.onEvent(
        const AuthSignInWithGoogleEvent(surface: AuthSurface.sheet),
      );
      go(AuthLoading());
      go(const AuthAuthenticated(_user));

      expect(logged, [
        {
          'event': AuthEvents.signinStarted,
          'method': 'google',
          'surface': 'sheet',
        },
        {
          'event': AuthEvents.signinCompleted,
          'method': 'google',
          'surface': 'sheet',
          'new_account': false,
        },
      ]);
      expect(funnel.method, isNull);
    });

    test('a new Apple account completes after the username step', () {
      funnel.onEvent(const AuthSignInWithAppleEvent());
      go(AuthLoading());
      go(const AuthNeedsUsername(user: _user));
      expect(funnel.method, AuthMethod.apple);
      go(AuthLoading());
      go(const AuthAuthenticated(_user));

      expect(logged.last, {
        'event': AuthEvents.signinCompleted,
        'method': 'apple',
        'surface': 'login',
        'new_account': true,
      });
    });

    test('email sign-up through the code counts as a new account', () {
      funnel.onEvent(const AuthCheckEmailEvent('maria.cruz@gmail.com'));
      go(AuthLoading());
      go(const AuthEmailChecked(exists: false, email: 'maria.cruz@gmail.com'));
      go(const AuthAwaitingEmailConfirmation(email: 'maria.cruz@gmail.com'));
      go(const AuthNeedsUsername(user: _user));
      go(const AuthAuthenticated(_user));

      expect(logged.map((e) => e['event']), [
        AuthEvents.signinStarted,
        AuthEvents.signinCompleted,
      ]);
      expect(logged.last['method'], 'email');
      expect(logged.last['new_account'], true);
    });

    test('a closed provider sheet is an abandoned provider step', () {
      funnel.onEvent(const AuthSignInWithGoogleEvent());
      go(AuthLoading());
      go(const AuthUnauthenticated());

      expect(logged.last, {
        'event': AuthEvents.signinStepAbandoned,
        'step': 'provider',
        'reason': 'cancelled',
        'method': 'google',
      });
      expect(funnel.method, isNull);
    });

    test('signing out from the username step is not a cancelled provider '
        'sheet', () {
      funnel.onEvent(const AuthSignInWithGoogleEvent());
      go(AuthLoading());
      go(const AuthNeedsUsername(user: _user));
      // "Use a different account".
      go(AuthLoading());
      go(const AuthLoggedOut());

      expect(logged.map((e) => e['event']), [AuthEvents.signinStarted]);
      expect(funnel.method, isNull);
    });

    test('a restored session is not an attempt', () {
      go(AuthLoading());
      go(const AuthAuthenticated(_user));
      expect(logged, isEmpty);
    });

    test('no email or name goes into the properties', () {
      funnel.onEvent(const AuthCheckEmailEvent('maria.cruz@gmail.com'));
      go(const AuthAuthenticated(_user));
      for (final props in logged) {
        expect(props.values, isNot(contains('maria.cruz@gmail.com')));
      }
    });
  });

  group('authStepFinished', () {
    test('details is done once the code is sent or the user is in', () {
      expect(authStepFinished(AuthStep.details, AuthLoading()), isFalse);
      expect(
        authStepFinished(
          AuthStep.details,
          const AuthAwaitingEmailConfirmation(email: 'a@b.co'),
        ),
        isTrue,
      );
      expect(
        authStepFinished(AuthStep.details, const AuthAuthenticated(_user)),
        isTrue,
      );
    });

    test('the code step is done only once signed in', () {
      expect(
        authStepFinished(
          AuthStep.otp,
          const AuthAwaitingEmailConfirmation(email: 'a@b.co'),
        ),
        isFalse,
      );
      expect(
        authStepFinished(AuthStep.otp, const AuthNeedsUsername(user: _user)),
        isTrue,
      );
    });

    test('the username step is done only once authenticated', () {
      expect(
        authStepFinished(
          AuthStep.username,
          const AuthNeedsUsername(user: _user),
        ),
        isFalse,
      );
      expect(
        authStepFinished(AuthStep.username, const AuthAuthenticated(_user)),
        isTrue,
      );
    });
  });

  group('AuthStepTracker', () {
    late List<_Logged> logged;
    late AuthState state;

    AuthStepTracker tracker(String step, {bool reportBackground = true}) =>
        AuthStepTracker(
          step: step,
          currentState: () => state,
          method: () => AuthMethod.email,
          reportBackground: reportBackground,
          log: (name, props) => logged.add({'event': name, ...props}),
        );

    setUp(() {
      logged = [];
      state = const AuthEmailChecked(exists: false, email: 'a@b.co');
    });

    test('leaving an unfinished step reports it once', () {
      final t = tracker(AuthStep.details);
      t.abandon(AuthAbandonReason.background);
      t.dispose();

      expect(logged, [
        {
          'event': AuthEvents.signinStepAbandoned,
          'step': 'details',
          'reason': 'background',
          'method': 'email',
        },
      ]);
    });

    test('a finished step reports nothing when its page closes', () {
      final t = tracker(AuthStep.details);
      state = const AuthAwaitingEmailConfirmation(email: 'a@b.co');
      t.dispose();
      expect(logged, isEmpty);
    });

    test('going to the background counts, except on the code step', () {
      final details = tracker(AuthStep.details);
      final otp = tracker(AuthStep.otp, reportBackground: false);
      state = const AuthAwaitingEmailConfirmation(email: 'a@b.co');

      details.didChangeAppLifecycleState(AppLifecycleState.paused);
      otp.didChangeAppLifecycleState(AppLifecycleState.paused);
      expect(logged, isEmpty); // details finished; the code step ignores it.

      otp.dispose();
      details.dispose();
      expect(logged.single['step'], 'otp');
      expect(logged.single['reason'], 'left');
    });
  });
}
