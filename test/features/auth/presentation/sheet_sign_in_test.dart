import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:nook/core/auth/auth_return.dart';
import 'package:nook/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:nook/features/auth/presentation/sheet_sign_in.dart';
import 'package:nook/features/auth/presentation/widgets/sign_in_choices.dart';
import 'package:nook/features/cafe_details/presentation/guest_action_replay.dart';
import 'package:nook/features/cafe_details/presentation/widgets/cafe_guest_sign_in_sheet.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show User;

import '../fake_auth_bloc.dart';

const _user = User(
  id: 'u1',
  appMetadata: {},
  userMetadata: {},
  aud: 'authenticated',
  createdAt: '2026-10-01T00:00:00Z',
);

/// Counts how often it is built from scratch, as a cafe page that replays
/// the guest's action in initState.
class _CafeB extends StatefulWidget {
  const _CafeB();

  static int made = 0;

  @override
  State<_CafeB> createState() => _CafeBState();
}

class _CafeBState extends State<_CafeB> {
  @override
  void initState() {
    super.initState();
    _CafeB.made++;
  }

  @override
  Widget build(BuildContext context) => const Text('cafe B');
}

void main() {
  setUp(AuthReturn.take);

  Future<(GoRouter, FakeAuthBloc)> pump(WidgetTester tester) async {
    final bloc = FakeAuthBloc();
    addTearDown(bloc.close);
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => const Text('home')),
        GoRoute(
          path: '/cafe/:id',
          builder: (_, s) => Text('cafe ${s.pathParameters['id']}'),
        ),
      ],
    );
    await tester.pumpWidget(
      BlocProvider<AuthBloc>.value(
        value: bloc,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    return (router, bloc);
  }

  testWidgets('Google from a sheet on a cafe pushed straight on the '
      'Navigator stays on that cafe', (tester) async {
    final (router, bloc) = await pump(tester);
    router.push('/cafe/A');
    await tester.pumpAndSettle();
    // "If you like this…" opens cafe B with Navigator.push, outside the
    // router's stack.
    final navigator = router.routerDelegate.navigatorKey.currentState!;
    navigator.push(MaterialPageRoute<void>(builder: (_) => const _CafeB()));
    await tester.pumpAndSettle();
    final context = tester.element(find.text('cafe B'));
    _CafeB.made = 0;

    final done = continueSignInFromSheet(
      context,
      SignInChoice.google,
      beforeSignIn: () =>
          GuestActionReplay.remember(CafeGuestAction.saveToList, 'B'),
    );
    await tester.pump();
    bloc.push(const AuthAuthenticated(_user));
    await done;
    await tester.pumpAndSettle();

    expect(find.text('cafe B'), findsOneWidget);
    expect(find.text('cafe A'), findsNothing);
    // Not made again (an awaited push would resume early), and the action
    // it would have finished is dropped, not left to fire later.
    expect(_CafeB.made, 0);
    expect(GuestActionReplay.take(CafeGuestAction.saveToList, 'B'), isFalse);
    // Back still leads to cafe A, under it.
    router.routerDelegate.navigatorKey.currentState!.pop();
    await tester.pumpAndSettle();
    expect(find.text('cafe A'), findsOneWidget);
  });

  testWidgets('Google from a sheet on a router page comes back to it', (
    tester,
  ) async {
    final (router, bloc) = await pump(tester);
    router.push('/cafe/A');
    await tester.pumpAndSettle();
    final context = tester.element(find.text('cafe A'));

    final done = continueSignInFromSheet(context, SignInChoice.google);
    await tester.pump();
    bloc.push(const AuthAuthenticated(_user));
    await done;
    await tester.pumpAndSettle();

    expect(find.text('cafe A'), findsOneWidget);
    expect(router.state.uri.toString(), '/cafe/A');
  });

  testWidgets('a cancelled Google sign-in drops the action it would have '
      'finished', (tester) async {
    final (router, bloc) = await pump(tester);
    router.push('/cafe/A');
    await tester.pumpAndSettle();
    final context = tester.element(find.text('cafe A'));

    final done = continueSignInFromSheet(
      context,
      SignInChoice.google,
      beforeSignIn: () =>
          GuestActionReplay.remember(CafeGuestAction.saveToList, 'A'),
    );
    await tester.pump();
    bloc.push(AuthUnauthenticated());
    await done;

    expect(GuestActionReplay.take(CafeGuestAction.saveToList, 'A'), isFalse);
  });

  testWidgets('email from a page outside the router drops the action, which '
      'the trip through /login cannot bring back', (tester) async {
    final bloc = FakeAuthBloc();
    addTearDown(bloc.close);
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => const Text('home')),
        GoRoute(path: '/login', builder: (_, _) => const Text('login')),
      ],
    );
    await tester.pumpWidget(
      BlocProvider<AuthBloc>.value(
        value: bloc,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    router.routerDelegate.navigatorKey.currentState!.push(
      MaterialPageRoute<void>(builder: (_) => const Text('cafe B')),
    );
    await tester.pumpAndSettle();

    await continueSignInFromSheet(
      tester.element(find.text('cafe B')),
      SignInChoice.email,
      beforeSignIn: () =>
          GuestActionReplay.remember(CafeGuestAction.saveToList, 'B'),
    );

    expect(GuestActionReplay.take(CafeGuestAction.saveToList, 'B'), isFalse);
    await tester.pumpAndSettle();
  });
}
