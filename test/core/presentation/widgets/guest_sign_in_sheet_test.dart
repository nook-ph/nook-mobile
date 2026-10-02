import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:nook/core/presentation/widgets/guest_sign_in_sheet.dart';

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
    expect(find.text('Sign in or create account'), findsOneWidget);
    expect(find.text('Not now'), findsOneWidget);
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
    final primary = tester.getRect(
      find.ancestor(
        of: find.text('Sign in or create account'),
        matching: find.byType(Container),
      ),
    );
    expect(primary.height, 48);
    expect(primary.left - sheet.left, 20);
    expect(sheet.right - primary.right, 20);

    final notNow = tester.getRect(
      find.ancestor(of: find.text('Not now'), matching: find.byType(Container)),
    );
    expect(notNow.height, 44);
    expect(notNow.top - primary.bottom, 8);
    expect(sheet.bottom - notNow.bottom, 34);
  });

  testWidgets('the primary button closes the sheet and opens /login', (
    tester,
  ) async {
    await _open(tester);

    await tester.tap(find.text('Sign in or create account'));
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
