import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:nook/core/auth/auth_return.dart';
import 'package:nook/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:nook/features/auth/presentation/sheet_sign_in.dart';
import 'package:nook/features/auth/presentation/widgets/sign_in_choices.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show User;

import '../fake_auth_bloc.dart';

const _user = User(
  id: 'u1',
  appMetadata: {},
  userMetadata: {},
  aud: 'authenticated',
  createdAt: '2026-10-01T00:00:00Z',
);

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
    navigator.push(
      MaterialPageRoute<void>(builder: (_) => const Text('cafe B')),
    );
    await tester.pumpAndSettle();
    final context = tester.element(find.text('cafe B'));

    final done = continueSignInFromSheet(context, SignInChoice.google);
    await tester.pump();
    bloc.push(const AuthAuthenticated(_user));
    await done;
    await tester.pumpAndSettle();

    expect(find.text('cafe B'), findsOneWidget);
    expect(find.text('cafe A'), findsNothing);
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
}
