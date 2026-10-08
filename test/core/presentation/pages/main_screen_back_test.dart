import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/core/presentation/bottom_nav.dart';
import 'package:nook/core/presentation/pages/main_screen.dart';

Widget _app() => MaterialApp(
  home: MainShell(
    isAuthenticated: () => true,
    pagesBuilder: (_) => const [
      Center(child: Text('home page')),
      Center(child: Text('map page')),
      Center(child: Text('saved page')),
      Center(child: Text('profile page')),
    ],
  ),
);

Finder _tab(String label) => find.descendant(
  of: find.byType(BottomNav),
  matching: find.bySemanticsLabel(label),
);

int _currentTab(WidgetTester tester) =>
    tester.widget<BottomNav>(find.byType(BottomNav)).currentIndex;

void main() {
  for (final label in ['Map', 'Saved', 'Profile']) {
    testWidgets('system Back on $label goes to Home, not out of the app', (
      tester,
    ) async {
      await tester.pumpWidget(_app());
      await tester.tap(_tab(label));
      await tester.pumpAndSettle();
      expect(_currentTab(tester), isNot(0));

      final popped = await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      // handlePopRoute returns true when the app consumed Back itself.
      expect(popped, isTrue);
      expect(_currentTab(tester), 0);
      expect(find.byType(MainShell), findsOneWidget);
    });
  }

  testWidgets('Back on Home is left to the system (closes the app)', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    final scope = find.byWidgetPredicate((w) => w is PopScope);
    expect(scope, findsOneWidget);
    expect(tester.widget<PopScope<Object?>>(scope).canPop, isTrue);
  });
}
