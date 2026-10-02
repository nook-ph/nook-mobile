import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:nook/core/preferences/terms_acceptance_store.dart';
import 'package:nook/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:nook/features/auth/presentation/pages/email_entry_page.dart';
import 'package:nook/features/auth/presentation/pages/login_page.dart';
import 'package:nook/features/auth/presentation/pages/signup_details_page.dart';
import 'package:nook/features/auth/presentation/widgets/auth_ui.dart';
import 'package:nook/injection_container.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../auth_test_host.dart';
import '../fake_auth_bloc.dart';

double _opacityOf(WidgetTester tester, String label) => tester
    .widget<Opacity>(
      find.ancestor(of: find.text(label), matching: find.byType(Opacity)),
    )
    .opacity;

/// A toast lands a frame after it is asked for, then animates in.
Future<void> _pumpToast(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Lets a toast's auto-close timer run out so no timer outlives the test.
Future<void> _drainToasts(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 4));
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  late FakeAuthBloc bloc;

  setUp(() {
    bloc = FakeAuthBloc();
  });

  tearDown(() => bloc.close());

  group('EmailEntryScreen', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      if (!sl.isRegistered<TermsAcceptanceStore>()) {
        sl.registerLazySingleton<TermsAcceptanceStore>(
          TermsAcceptanceStore.new,
        );
      }
    });

    Future<void> pumpEntry(WidgetTester tester) async {
      await tester.pumpWidget(
        authTestHost(page: const EmailEntryScreen(), bloc: bloc),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('everything waits for the terms box (B1, B2)', (tester) async {
      await pumpEntry(tester);
      expect(find.text('Log in or sign up'), findsOneWidget);
      expect(find.text('Email'), findsOneWidget);
      expect(_opacityOf(tester, 'Continue'), 0.4);
      expect(_opacityOf(tester, 'Continue with Google'), 0.4);

      await tester.enterText(find.byType(TextField), 'maria.cruz@gmail.com');
      await tester.pump();
      expect(_opacityOf(tester, 'Continue'), 0.4);

      await tester.tap(find.byType(AuthCheckbox));
      await tester.pump();
      expect(_opacityOf(tester, 'Continue'), 1);
      expect(_opacityOf(tester, 'Continue with Google'), 1);
      // A typed email can be cleared from inside the field.
      expect(find.byIcon(LucideIcons.x), findsOneWidget);
    });

    testWidgets('an invalid email is an inline error (B3)', (tester) async {
      await pumpEntry(tester);
      await tester.tap(find.byType(AuthCheckbox));
      await tester.enterText(find.byType(TextField), 'maria.cruz@gmail');
      await tester.pump();
      await tester.tap(find.text('Continue'));
      await tester.pump();

      expect(find.text('This email is invalid'), findsOneWidget);
      expect(_opacityOf(tester, 'Continue'), 0.4);
      expect(bloc.events, isEmpty);

      await tester.enterText(find.byType(TextField), 'maria.cruz@gmail.com');
      await tester.pump();
      expect(find.text('This email is invalid'), findsNothing);
    });

    testWidgets('checking spins Continue and locks the providers (B4)', (
      tester,
    ) async {
      await pumpEntry(tester);
      await tester.tap(find.byType(AuthCheckbox));
      await tester.enterText(find.byType(TextField), 'maria.cruz@gmail.com');
      await tester.pump();
      await tester.tap(find.text('Continue'));
      await tester.pump();
      expect(bloc.events.single, isA<AuthCheckEmailEvent>());

      bloc.push(AuthLoading());
      await tester.pump();
      expect(find.text('Checking…'), findsOneWidget);
      expect(_opacityOf(tester, 'Continue with Google'), 0.4);

      bloc.push(const AuthError('Connection failed. Check your internet.'));
      await _pumpToast(tester);
      expect(find.text('Connection failed. Check your internet.'), findsOne);
      expect(find.text('Continue'), findsOneWidget);
      await _drainToasts(tester);
    });

    testWidgets('a provider spins its own button only (B9)', (tester) async {
      await pumpEntry(tester);
      await tester.tap(find.byType(AuthCheckbox));
      await tester.pump();
      await tester.tap(find.text('Continue with Google'));
      await tester.pump();
      expect(bloc.events.single, isA<AuthSignInWithGoogleEvent>());

      bloc.push(AuthLoading());
      await tester.pump();
      expect(find.text('Checking…'), findsNothing);
      expect(find.byType(AuthSpinner), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(AuthOutlineButton),
          matching: find.byType(AuthSpinner),
        ),
        findsOneWidget,
      );
    });
  });

  group('LoginPasswordScreen', () {
    Future<void> pumpLogin(WidgetTester tester) async {
      await tester.pumpWidget(
        authTestHost(
          page: const LoginPasswordScreen(email: 'maria.cruz@gmail.com'),
          bloc: bloc,
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('shows the email back and waits for a password (B6)', (
      tester,
    ) async {
      await pumpLogin(tester);
      expect(find.text('Log in'), findsWidgets);
      expect(
        find.textContaining('maria.cruz@gmail.com', findRichText: true),
        findsOneWidget,
      );
      expect(_opacityOf(tester, 'Log in'), 0.4);

      await tester.enterText(find.byType(TextField), 'latte-at-nine');
      await tester.pump();
      await tester.tap(find.text('Log in').last);
      await tester.pump();
      final event = bloc.events.single as AuthSignInEvent;
      expect(event.email, 'maria.cruz@gmail.com');
      expect(event.password, 'latte-at-nine');

      bloc.push(AuthLoading());
      await tester.pump();
      expect(find.text('Logging in…'), findsOneWidget);
    });

    testWidgets('a wrong password is inline, not a toast (B7)', (tester) async {
      await pumpLogin(tester);
      await tester.enterText(find.byType(TextField), 'wrong-one');
      await tester.pump();
      bloc.push(const AuthError('Email or password is incorrect'));
      await tester.pump();

      expect(find.text('Incorrect password. Please try again.'), findsOne);
      expect(find.text('Email or password is incorrect'), findsNothing);

      await tester.enterText(find.byType(TextField), 'wrong-one!');
      await tester.pump();
      expect(find.text('Incorrect password. Please try again.'), findsNothing);
    });

    testWidgets('other server errors are toasts (F8, F9)', (tester) async {
      await pumpLogin(tester);
      bloc.push(const AuthError('Please verify your email before logging in'));
      await _pumpToast(tester);
      expect(
        find.text('Please verify your email before logging in'),
        findsOneWidget,
      );
      expect(find.byType(AuthToast), findsOneWidget);
      await _drainToasts(tester);
    });
  });

  group('SignupDetailsScreen', () {
    Future<void> pumpSignup(WidgetTester tester) async {
      await tester.pumpWidget(
        authTestHost(
          page: const SignupDetailsScreen(email: 'maria.cruz@gmail.com'),
          bloc: bloc,
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('both rules show inline (C1, C2)', (tester) async {
      await pumpSignup(tester);
      expect(find.text('Create your account'), findsOneWidget);
      expect(find.text('At least 8 characters'), findsOneWidget);
      expect(_opacityOf(tester, 'Continue'), 0.4);

      await tester.enterText(find.byType(TextField).last, 'abcdef');
      await tester.pump();
      await tester.tap(find.text('Continue'));
      await tester.pump();

      expect(find.text('Name is required'), findsOneWidget);
      expect(
        find.text('Password must contain at least 8 characters'),
        findsOneWidget,
      );
      expect(bloc.events, isEmpty);
    });

    testWidgets('valid details sign up and show progress (C3, C4)', (
      tester,
    ) async {
      await pumpSignup(tester);
      await tester.enterText(find.byType(TextField).first, 'Maria Cruz');
      await tester.enterText(find.byType(TextField).last, 'latte-at-nine');
      await tester.pump();
      expect(
        tester.widget<Text>(find.text('At least 8 characters')).style?.color,
        AuthColors.success,
      );

      await tester.tap(find.text('Continue'));
      await tester.pump();
      final event = bloc.events.single as AuthSignUpEvent;
      expect(event.name, 'Maria Cruz');
      expect(event.email, 'maria.cruz@gmail.com');

      bloc.push(AuthLoading());
      await tester.pump();
      expect(find.text('Creating account…'), findsOneWidget);
    });
  });
}
