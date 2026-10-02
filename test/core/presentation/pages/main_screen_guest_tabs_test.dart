import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:nook/core/presentation/bottom_nav.dart';
import 'package:nook/core/presentation/pages/main_screen.dart';
import 'package:nook/core/presentation/widgets/guest_sign_in_sheet.dart';

/// [MainShell] with placeholder pages, behind a router that has `/login`.
Widget _app({required bool signedIn}) {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => MainShell(
          isAuthenticated: () => signedIn,
          pagesBuilder: (_) => const [
            Center(child: Text('home page')),
            Center(child: Text('map page')),
            Center(child: Text('saved page')),
            Center(child: Text('profile page')),
          ],
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

Finder _tab(String label) => find.descendant(
  of: find.byType(BottomNav),
  matching: find.bySemanticsLabel(label),
);

int _currentTab(WidgetTester tester) =>
    tester.widget<BottomNav>(find.byType(BottomNav)).currentIndex;

void main() {
  testWidgets('a guest tapping Saved gets the save sheet and stays on Home', (
    tester,
  ) async {
    await tester.pumpWidget(_app(signedIn: false));

    await tester.tap(_tab('Saved'));
    await tester.pumpAndSettle();

    expect(find.byType(GuestSignInSheet), findsOneWidget);
    expect(find.text('Sign in to save cafes'), findsOneWidget);
    expect(
      find.text('Keep lists, mark the places you have been, and rank them.'),
      findsOneWidget,
    );
    // The tab bar draws the same glyph, so look inside the sheet.
    expect(
      find.descendant(
        of: find.byType(GuestSignInSheet),
        matching: find.byIcon(LucideIcons.bookmark),
      ),
      findsOneWidget,
    );
    expect(_currentTab(tester), 0);
    expect(find.text('login page'), findsNothing);
  });

  testWidgets('a guest tapping Profile gets the profile sheet', (tester) async {
    await tester.pumpWidget(_app(signedIn: false));

    await tester.tap(_tab('Profile'));
    await tester.pumpAndSettle();

    expect(find.text('Sign in to see your profile'), findsOneWidget);
    expect(
      find.text(
        'Your reviews, lists and rankings live in one place once you have an '
        'account.',
      ),
      findsOneWidget,
    );
    // The tab bar draws the same glyph, so look inside the sheet.
    expect(
      find.descendant(
        of: find.byType(GuestSignInSheet),
        matching: find.byIcon(LucideIcons.userRound),
      ),
      findsOneWidget,
    );
    expect(_currentTab(tester), 0);
  });

  testWidgets('the guest stays on the tab they were on, not just Home', (
    tester,
  ) async {
    await tester.pumpWidget(_app(signedIn: false));

    await tester.tap(_tab('Map'));
    await tester.pumpAndSettle();
    expect(_currentTab(tester), 1);

    await tester.tap(_tab('Saved'));
    await tester.pumpAndSettle();

    expect(find.byType(GuestSignInSheet), findsOneWidget);
    expect(_currentTab(tester), 1);
  });

  testWidgets('the primary button opens /login', (tester) async {
    await tester.pumpWidget(_app(signedIn: false));

    await tester.tap(_tab('Saved'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sign in or create account'));
    await tester.pumpAndSettle();

    expect(find.byType(GuestSignInSheet), findsNothing);
    expect(find.text('login page'), findsOneWidget);
  });

  testWidgets('Not now closes the sheet and leaves the tab alone', (
    tester,
  ) async {
    await tester.pumpWidget(_app(signedIn: false));

    await tester.tap(_tab('Profile'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();

    expect(find.byType(GuestSignInSheet), findsNothing);
    expect(find.text('login page'), findsNothing);
    expect(_currentTab(tester), 0);
  });

  testWidgets('a guest can still switch to Map', (tester) async {
    await tester.pumpWidget(_app(signedIn: false));

    await tester.tap(_tab('Map'));
    await tester.pumpAndSettle();

    expect(find.byType(GuestSignInSheet), findsNothing);
    expect(_currentTab(tester), 1);
  });

  testWidgets('a signed-in user switches to Saved and Profile, no sheet', (
    tester,
  ) async {
    await tester.pumpWidget(_app(signedIn: true));

    await tester.tap(_tab('Saved'));
    await tester.pumpAndSettle();
    expect(find.byType(GuestSignInSheet), findsNothing);
    expect(_currentTab(tester), 2);

    await tester.tap(_tab('Profile'));
    await tester.pumpAndSettle();
    expect(find.byType(GuestSignInSheet), findsNothing);
    expect(_currentTab(tester), 3);
  });

  testWidgets('a tab is built on its first visit and kept afterwards', (
    tester,
  ) async {
    await tester.pumpWidget(_app(signedIn: true));

    expect(find.text('home page'), findsOneWidget);
    for (final other in ['map page', 'saved page', 'profile page']) {
      expect(find.text(other, skipOffstage: false), findsNothing);
    }

    await tester.tap(_tab('Map'));
    await tester.pumpAndSettle();
    expect(find.text('map page'), findsOneWidget);
    expect(find.text('saved page', skipOffstage: false), findsNothing);

    await tester.tap(_tab('Home'));
    await tester.pumpAndSettle();
    // Still in the tree, only off stage.
    expect(find.text('map page', skipOffstage: false), findsOneWidget);
    expect(find.text('map page'), findsNothing);
  });
}
