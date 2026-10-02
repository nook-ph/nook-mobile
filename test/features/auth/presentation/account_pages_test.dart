import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:nook/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:nook/features/auth/presentation/pages/change_email_page.dart';
import 'package:nook/features/auth/presentation/pages/change_password_page.dart';
import 'package:nook/features/auth/presentation/pages/forgot_password_page.dart';
import 'package:nook/features/auth/presentation/pages/username_setup_page.dart';
import 'package:nook/features/auth/presentation/widgets/auth_ui.dart';

import '../auth_test_host.dart';
import '../fake_auth_bloc.dart';

double _opacityOf(WidgetTester tester, String label) => tester
    .widget<Opacity>(
      find.ancestor(of: find.text(label), matching: find.byType(Opacity)),
    )
    .opacity;

Future<void> _pumpToast(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _drainToasts(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 4));
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  late FakeAuthBloc bloc;

  setUp(() => bloc = FakeAuthBloc());
  tearDown(() => bloc.close());

  group('username rules', () {
    test('suggestUsername turns a name into a handle', () {
      expect(suggestUsername('Maria Cruz'), 'maria_cruz');
      expect(suggestUsername('  José  P. Rizal '), 'jos_p_rizal');
      expect(suggestUsername('A' * 30).length, 20);
    });

    test('validateUsername reports the first broken rule', () {
      expect(validateUsername(''), isNull);
      expect(validateUsername('ma'), 'At least 3 characters');
      expect(validateUsername('a' * 21), 'Max 20 characters');
      expect(
        validateUsername('maria.cruz!'),
        'Only letters, numbers, and underscores',
      );
      expect(validateUsername('maria_cruz'), isNull);
    });
  });

  group('UsernameSetupScreen', () {
    Future<void> pumpUsername(
      WidgetTester tester, {
      required Future<bool> Function(String) check,
    }) async {
      await tester.pumpWidget(
        authTestHost(
          page: UsernameSetupScreen(
            fullName: 'Maria Cruz',
            checkAvailability: check,
          ),
          bloc: bloc,
        ),
      );
      await tester.pump();
      await tester.pump();
    }

    testWidgets('checks the suggestion, then unlocks on available (C11–C13)', (
      tester,
    ) async {
      final pending = Completer<bool>();
      await pumpUsername(tester, check: (_) => pending.future);

      expect(find.text('Pick a username'), findsOneWidget);
      expect(find.text('Welcome, Maria! Choose a unique handle.'), findsOne);
      expect(find.text('Checking availability…'), findsOneWidget);
      expect(_opacityOf(tester, 'Confirm username'), 0.4);

      await tester.pump(const Duration(milliseconds: 700));
      pending.complete(true);
      await tester.pump();

      expect(find.text('@maria_cruz is available!'), findsOneWidget);
      expect(find.byIcon(LucideIcons.circleCheck), findsNWidgets(2));
      expect(_opacityOf(tester, 'Confirm username'), 1);

      await tester.tap(find.text('Confirm username'));
      await tester.pump();
      expect(
        (bloc.events.single as AuthUsernameSetEvent).username,
        'maria_cruz',
      );

      bloc.push(AuthLoading());
      await tester.pump();
      expect(find.text('Saving…'), findsOneWidget);
    });

    testWidgets('a taken name is a red pill and keeps the button off (C14)', (
      tester,
    ) async {
      await pumpUsername(tester, check: (_) async => false);
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pump();

      expect(find.text('@maria_cruz is already taken.'), findsOneWidget);
      expect(_opacityOf(tester, 'Confirm username'), 0.4);
    });

    testWidgets('a format error replaces the helper, no pill (C15)', (
      tester,
    ) async {
      await pumpUsername(tester, check: (_) async => true);
      await tester.pump(const Duration(milliseconds: 700));
      await tester.enterText(find.byType(TextField), 'maria.cruz!');
      await tester.pump();

      expect(find.text('Only letters, numbers, and underscores'), findsOne);
      expect(find.byType(AuthStatusPill), findsNothing);
      expect(
        find.text('Letters, numbers, and underscores only. 3–20 characters.'),
        findsNothing,
      );
    });

    testWidgets('a failed save is a toast and keeps what was typed (F6)', (
      tester,
    ) async {
      await pumpUsername(tester, check: (_) async => true);
      await tester.pump(const Duration(milliseconds: 700));
      bloc.push(const AuthError('Failed to save username. Try again.'));
      await _pumpToast(tester);

      expect(find.text('Failed to save username. Try again.'), findsOne);
      expect(find.text('maria_cruz'), findsOneWidget);
      await _drainToasts(tester);
    });
  });

  group('ForgotPasswordScreen', () {
    testWidgets('an invalid email is inline (D2)', (tester) async {
      var sends = 0;
      await tester.pumpWidget(
        authTestHost(
          page: ForgotPasswordScreen(sendReset: (_) async => sends++),
          bloc: bloc,
        ),
      );
      await tester.pumpAndSettle();
      expect(_opacityOf(tester, 'Send reset link'), 0.4);

      await tester.enterText(find.byType(TextField), 'maria.cruz@');
      await tester.pump();
      await tester.tap(find.text('Send reset link'));
      await tester.pump();
      expect(find.text('This email is invalid'), findsOneWidget);
      expect(sends, 0);
    });

    testWidgets('sending ends on "Check your email" (D3, D4)', (tester) async {
      final pending = Completer<void>();
      final sentTo = <String>[];
      await tester.pumpWidget(
        authTestHost(
          page: ForgotPasswordScreen(
            sendReset: (email) {
              sentTo.add(email);
              return sentTo.length == 1 ? pending.future : Future.value();
            },
          ),
          bloc: bloc,
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'maria.cruz@gmail.com');
      await tester.pump();
      await tester.tap(find.text('Send reset link'));
      await tester.pump();
      expect(find.text('Sending…'), findsOneWidget);

      pending.complete();
      await tester.pump();
      expect(find.text('Check your email'), findsOneWidget);
      expect(
        find.textContaining('Password reset link sent to maria.cruz@gmail.com'),
        findsOneWidget,
      );
      expect(find.byIcon(LucideIcons.mail), findsOneWidget);
      expect(find.text('Back to log in'), findsOneWidget);

      await tester.tap(find.text("Didn't get it? Send again"));
      await _pumpToast(tester);
      expect(sentTo, ['maria.cruz@gmail.com', 'maria.cruz@gmail.com']);
      expect(find.byType(AuthToast), findsOneWidget);
      await _drainToasts(tester);
    });

    testWidgets('a failure stays on the form with a toast (D5)', (
      tester,
    ) async {
      await tester.pumpWidget(
        authTestHost(
          page: ForgotPasswordScreen(
            sendReset: (_) async => throw Exception('offline'),
          ),
          bloc: bloc,
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'maria.cruz@gmail.com');
      await tester.pump();
      await tester.tap(find.text('Send reset link'));
      await _pumpToast(tester);

      expect(find.text('Unable to send reset link. Try again.'), findsOne);
      expect(find.text('Forgot your password?'), findsOneWidget);
      await _drainToasts(tester);
    });
  });

  group('ChangePasswordScreen', () {
    testWidgets('both rules show inline (D6, D7)', (tester) async {
      var updates = 0;
      await tester.pumpWidget(
        authTestHost(
          page: ChangePasswordScreen(updatePassword: (_) async => updates++),
          bloc: bloc,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Change your password'), findsOneWidget);
      expect(find.text('At least 8 characters'), findsOneWidget);
      expect(_opacityOf(tester, 'Update password'), 0.4);

      await tester.enterText(find.byType(TextField).first, 'abcd');
      await tester.enterText(find.byType(TextField).last, 'abcdef');
      await tester.pump();
      await tester.tap(find.text('Update password'));
      await tester.pump();

      expect(find.text('Password must be at least 8 characters'), findsOne);
      expect(find.text('Passwords do not match'), findsOneWidget);
      expect(updates, 0);
    });

    testWidgets('success is a check toast and a session re-check (D9)', (
      tester,
    ) async {
      final saved = <String>[];
      await tester.pumpWidget(
        authTestHost(
          page: ChangePasswordScreen(
            updatePassword: (password) async => saved.add(password),
          ),
          bloc: bloc,
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'latte-at-nine');
      await tester.enterText(find.byType(TextField).last, 'latte-at-nine');
      await tester.pump();
      await tester.tap(find.text('Update password'));
      await _pumpToast(tester);

      expect(saved, ['latte-at-nine']);
      expect(find.text('Password updated successfully'), findsOneWidget);
      expect(bloc.events.last, isA<AuthSessionCheckEvent>());
      await _drainToasts(tester);
    });

    testWidgets('opened from Settings, success leaves the page', (
      tester,
    ) async {
      await tester.pumpWidget(
        authTestHost(
          page: ChangePasswordScreen(updatePassword: (_) async {}),
          bloc: bloc,
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'latte-at-nine');
      await tester.enterText(find.byType(TextField).last, 'latte-at-nine');
      await tester.pump();
      await tester.tap(find.text('Update password'));
      await _pumpToast(tester);
      await _drainToasts(tester);

      expect(find.text('Change your password'), findsNothing);
      expect(find.text('route:/'), findsOneWidget);
    });

    testWidgets('from the reset link, success waits for the redirect', (
      tester,
    ) async {
      bloc.push(AuthPasswordRecovery());
      await tester.pumpWidget(
        authTestHost(
          page: ChangePasswordScreen(updatePassword: (_) async {}),
          bloc: bloc,
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'latte-at-nine');
      await tester.enterText(find.byType(TextField).last, 'latte-at-nine');
      await tester.pump();
      await tester.tap(find.text('Update password'));
      await _pumpToast(tester);
      await _drainToasts(tester);

      expect(find.text('Change your password'), findsOneWidget);
    });
  });

  group('ChangeEmailScreen', () {
    testWidgets('an invalid email is inline (D11)', (tester) async {
      await tester.pumpWidget(
        authTestHost(
          page: ChangeEmailScreen(
            currentEmail: 'maria@nook',
            updateEmail: (_) async {},
          ),
          bloc: bloc,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Update your email'), findsOneWidget);
      expect(find.text('New email'), findsOneWidget);

      await tester.tap(find.text('Send verification'));
      await tester.pump();
      expect(find.text('This email is invalid'), findsOneWidget);
    });

    testWidgets('a failure keeps the form with a toast (F7)', (tester) async {
      await tester.pumpWidget(
        authTestHost(
          page: ChangeEmailScreen(
            currentEmail: 'maria@nookph.app',
            updateEmail: (_) async => throw Exception('offline'),
          ),
          bloc: bloc,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Send verification'));
      await _pumpToast(tester);

      expect(find.text('Unable to update email. Try again.'), findsOneWidget);
      expect(find.text('Update your email'), findsOneWidget);
      await _drainToasts(tester);
    });

    testWidgets('success sends, toasts and goes back (D12, D13)', (
      tester,
    ) async {
      final sentTo = <String>[];
      await tester.pumpWidget(
        authTestHost(
          page: ChangeEmailScreen(
            currentEmail: 'maria@nookph.app',
            updateEmail: (email) async => sentTo.add(email),
          ),
          bloc: bloc,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Send verification'));
      await _pumpToast(tester);

      expect(sentTo, ['maria@nookph.app']);
      expect(find.text('Verification sent to maria@nookph.app'), findsOne);
      await _drainToasts(tester);
      expect(find.text('route:/'), findsOneWidget);
    });
  });
}
