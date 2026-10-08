import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:nook/core/auth/auth_return.dart';

/// Stands in for the login screen: records the page under it on open, as
/// EmailEntryScreen does.
class _FakeLogin extends StatefulWidget {
  const _FakeLogin();

  @override
  State<_FakeLogin> createState() => _FakeLoginState();
}

class _FakeLoginState extends State<_FakeLogin> {
  bool _recorded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_recorded) return;
    AuthReturn.rememberOrigin(GoRouter.of(context));
    _recorded = true;
  }

  @override
  Widget build(BuildContext context) => const Text('login');
}

GoRouter _router() => GoRouter(
  routes: [
    GoRoute(path: '/', builder: (_, _) => const Text('home')),
    GoRoute(
      path: '/cafe/:id',
      builder: (_, s) => Text('cafe ${s.pathParameters['id']}'),
    ),
    GoRoute(path: '/login', builder: (_, _) => const _FakeLogin()),
    GoRoute(path: '/signup-details', builder: (_, _) => const Text('details')),
  ],
);

Future<GoRouter> _pump(WidgetTester tester) async {
  final router = _router();
  await tester.pumpWidget(MaterialApp.router(routerConfig: router));
  await tester.pumpAndSettle();
  return router;
}

void main() {
  setUp(AuthReturn.take);

  testWidgets('login pushed from a cafe returns to that cafe', (tester) async {
    final router = await _pump(tester);
    router.push('/cafe/abc');
    await tester.pumpAndSettle();
    router.push('/login');
    await tester.pumpAndSettle();

    expect(AuthReturn.take(), '/cafe/abc');
    expect(AuthReturn.take(), isNull, reason: 'used once');
  });

  testWidgets('login pushed from the tabs records nothing', (tester) async {
    final router = await _pump(tester);
    router.push('/login');
    await tester.pumpAndSettle();

    expect(AuthReturn.take(), isNull);
  });

  testWidgets('a login reached with go keeps the recorded page', (
    tester,
  ) async {
    final router = await _pump(tester);
    router.push('/cafe/abc');
    await tester.pumpAndSettle();
    router.push('/login');
    await tester.pumpAndSettle();
    // A later step sending the user back to the email screen with go.
    router.go('/login');
    await tester.pumpAndSettle();

    expect(AuthReturn.take(), '/cafe/abc');
  });

  testWidgets('finishing sign-in lands on the cafe, with Home under it', (
    tester,
  ) async {
    final router = await _pump(tester);
    router.push('/cafe/abc');
    await tester.pumpAndSettle();
    router.push('/login');
    await tester.pumpAndSettle();

    finishSignIn(tester.element(find.text('login')));
    await tester.pumpAndSettle();
    expect(find.text('cafe abc'), findsOneWidget);

    router.pop();
    await tester.pumpAndSettle();
    expect(find.text('home'), findsOneWidget);
  });
}
