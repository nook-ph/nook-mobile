import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/core/presentation/bottom_nav.dart';
import 'package:nook/core/presentation/pages/main_screen.dart';
import 'package:nook/core/presentation/tab_back.dart';

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

  testWidgets('a tab that claims Back keeps it; the next Back goes Home', (
    tester,
  ) async {
    var cardOpen = true;
    bool closeCard() {
      if (!cardOpen) return false;
      cardOpen = false;
      return true;
    }

    TabBack.register(1, closeCard);
    addTearDown(() => TabBack.unregister(1, closeCard));
    await tester.pumpWidget(_app());
    await tester.tap(_tab('Map'));
    await tester.pumpAndSettle();

    expect(await tester.binding.handlePopRoute(), isTrue);
    await tester.pumpAndSettle();
    expect(cardOpen, isFalse);
    expect(_currentTab(tester), 1);

    expect(await tester.binding.handlePopRoute(), isTrue);
    await tester.pumpAndSettle();
    expect(_currentTab(tester), 0);
  });

  testWidgets('Back on Home is left to the system (closes the app)', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    final scope = find.byWidgetPredicate((w) => w is PopScope);
    expect(scope, findsOneWidget);
    expect(tester.widget<PopScope<Object?>>(scope).canPop, isTrue);
  });
}
