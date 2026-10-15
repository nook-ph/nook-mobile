import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:nook/core/analytics/auth_events.dart';
import 'package:nook/core/presentation/widgets/guest_sign_in_sheet.dart';
import 'package:nook/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:nook/features/auth/presentation/widgets/auth_ui.dart';

import '../../../features/auth/fake_auth_bloc.dart';

const _title = 'Sign in to save cafes';
const _reason = 'Keep lists, mark the places you have been, and rank them.';

/// A router with an opener page and a stand-in `/login`.
Widget _app() {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, _) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => GuestSignInSheet.show(
                context,
                icon: LucideIcons.bookmark,
                title: _title,
                reason: _reason,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
      GoRoute(
        path: '/login',
        builder: (_, _) => const Scaffold(body: Text('login page')),
      ),
    ],
  );
  return MaterialApp.router(routerConfig: router);
}

Future<void> _open(WidgetTester tester) async {
  await tester.pumpWidget(_app());
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows the icon, title, reason and both buttons', (tester) async {
    await _open(tester);

    expect(find.byType(GuestSignInSheet), findsOneWidget);
    expect(find.byIcon(LucideIcons.bookmark), findsOneWidget);
    expect(find.text(_title), findsOneWidget);
    expect(find.text(_reason), findsOneWidget);
    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.text('Continue with email'), findsOneWidget);
    expect(find.text('Not now'), findsOneWidget);
    // Apple is offered on iOS only; tests run as Android.
    expect(find.text('Continue with Apple'), findsNothing);
  });

  testWidgets('Google comes before email', (tester) async {
    await _open(tester);
    final google = tester.getTopLeft(find.text('Continue with Google'));
    final email = tester.getTopLeft(find.text('Continue with email'));
    expect(google.dy, lessThan(email.dy));
  });

  testWidgets('Google waits for the terms box, then signs in in place', (
    tester,
  ) async {
    final bloc = FakeAuthBloc(const AuthUnauthenticated());
    addTearDown(bloc.close);
    await tester.pumpWidget(
      BlocProvider<AuthBloc>.value(value: bloc, child: _app()),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Continue with Google'));
    await tester.pumpAndSettle();
    expect(find.byType(GuestSignInSheet), findsOneWidget);
    expect(bloc.events, isEmpty);

    await tester.tap(find.byType(AuthCheckbox));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue with Google'));
    await tester.pumpAndSettle();

    expect(find.byType(GuestSignInSheet), findsNothing);
    expect(find.text('login page'), findsNothing);
    expect(bloc.events, [
      const AuthSignInWithGoogleEvent(surface: AuthSurface.sheet),
    ]);

    // A closed Google sheet leaves the guest where they were.
    bloc.push(AuthLoading());
    bloc.push(const AuthUnauthenticated());
    await tester.pumpAndSettle();
    expect(find.text('open'), findsOneWidget);
  });

  testWidgets('a caller reason replaces the default copy', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => GuestSignInSheet.show(
                context,
                icon: LucideIcons.bookmark,
                title: 'Keep your saves',
                reason: 'Keep your saves on any phone',
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Keep your saves on any phone'), findsOneWidget);
  });

  testWidgets('matches the Figma sizes and colours', (tester) async {
    await _open(tester);

    final icon = tester.widget<Icon>(find.byIcon(LucideIcons.bookmark));
    expect(icon.size, 24);
    expect(icon.color, const Color(0xFF344E41));

    final title = tester.widget<Text>(find.text(_title));
    expect(title.style?.fontSize, 20);
    expect(title.style?.fontWeight, FontWeight.w600);
    expect(title.style?.color, const Color(0xFF0A0F0D));

    final reason = tester.widget<Text>(find.text(_reason));
    expect(reason.style?.fontSize, 14);
    expect(reason.style?.color, const Color(0xFF868584));
    expect(reason.textAlign, TextAlign.center);

    final sheet = tester.getRect(find.byType(GuestSignInSheet));
    final google = tester.getRect(
      find
          .ancestor(
            of: find.text('Continue with Google'),
            matching: find.byType(Container),
          )
          .first,
    );
    expect(google.height, 48);
    expect(google.left - sheet.left, 20);
    expect(sheet.right - google.right, 20);

    final primary = tester.getRect(
      find
          .ancestor(
            of: find.text('Continue with email'),
            matching: find.byType(Container),
          )
          .first,
    );
    expect(primary.height, 48);
    expect(primary.top - google.bottom, 8);

    final notNow = tester.getRect(
      find.ancestor(of: find.text('Not now'), matching: find.byType(Container)),
    );
    expect(notNow.height, 44);
    expect(notNow.top - primary.bottom, 8);
    expect(sheet.bottom - notNow.bottom, 34);
  });

  testWidgets('Continue with email closes the sheet and opens /login', (
    tester,
  ) async {
    await _open(tester);

    await tester.tap(find.text('Continue with email'));
    await tester.pumpAndSettle();

    expect(find.byType(GuestSignInSheet), findsNothing);
    expect(find.text('login page'), findsOneWidget);
  });

  testWidgets('Not now closes the sheet and stays on the page', (tester) async {
    await _open(tester);

    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();

    expect(find.byType(GuestSignInSheet), findsNothing);
    expect(find.text('login page'), findsNothing);
    expect(find.text('open'), findsOneWidget);
  });

  testWidgets('tapping the scrim closes the sheet without navigating', (
    tester,
  ) async {
    await _open(tester);

    await tester.tapAt(const Offset(20, 20));
    await tester.pumpAndSettle();

    expect(find.byType(GuestSignInSheet), findsNothing);
    expect(find.text('login page'), findsNothing);
  });
}
