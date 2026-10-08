import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:nook/features/cafe_details/presentation/guest_action_replay.dart';
import 'package:nook/features/cafe_details/presentation/widgets/cafe_guest_sign_in_sheet.dart';

void main() {
  var clock = DateTime(2026, 10, 9, 12);

  setUp(() {
    clock = DateTime(2026, 10, 9, 12);
    GuestActionReplay.now = () => clock;
    GuestActionReplay.clear();
  });
  tearDown(() => GuestActionReplay.now = DateTime.now);

  test('a remembered Save is taken once, for its own cafe only', () {
    GuestActionReplay.remember(CafeGuestAction.saveToList, 'cafe-1');
    expect(GuestActionReplay.take(CafeGuestAction.been, 'cafe-1'), isFalse);
    expect(
      GuestActionReplay.take(CafeGuestAction.saveToList, 'cafe-2'),
      isFalse,
    );
    expect(
      GuestActionReplay.take(CafeGuestAction.saveToList, 'cafe-1'),
      isTrue,
    );
    expect(
      GuestActionReplay.take(CafeGuestAction.saveToList, 'cafe-1'),
      isFalse,
    );
  });

  test('a stale action is dropped', () {
    GuestActionReplay.remember(CafeGuestAction.been, 'cafe-1');
    clock = clock.add(const Duration(minutes: 31));
    expect(GuestActionReplay.take(CafeGuestAction.been, 'cafe-1'), isFalse);
  });

  test('report and helpful are not replayed', () {
    GuestActionReplay.remember(CafeGuestAction.reportReview, 'cafe-1');
    expect(
      GuestActionReplay.take(CafeGuestAction.reportReview, 'cafe-1'),
      isFalse,
    );
  });

  test('takeAny finds Been or Want to try', () {
    GuestActionReplay.remember(CafeGuestAction.wantToTry, 'cafe-1');
    expect(
      GuestActionReplay.takeAny(const [
        CafeGuestAction.been,
        CafeGuestAction.wantToTry,
      ], 'cafe-1'),
      CafeGuestAction.wantToTry,
    );
  });

  Widget host() => MaterialApp.router(
    routerConfig: GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => CafeGuestSignInSheet.show(
                  context,
                  action: CafeGuestAction.been,
                  cafeName: 'Tadaima',
                  cafeId: 'cafe-1',
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
    ),
  );

  testWidgets('choosing to sign in remembers the action', (tester) async {
    await tester.pumpWidget(host());
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sign in or create account'));
    await tester.pumpAndSettle();
    expect(find.text('login page'), findsOneWidget);
    expect(GuestActionReplay.take(CafeGuestAction.been, 'cafe-1'), isTrue);
  });

  testWidgets('Not now remembers nothing', (tester) async {
    await tester.pumpWidget(host());
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();
    expect(GuestActionReplay.take(CafeGuestAction.been, 'cafe-1'), isFalse);
  });
}
