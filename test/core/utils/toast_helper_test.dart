import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/core/utils/toast_helper.dart';
import 'package:nook/utils/theme/theme.dart';

void main() {
  test('the saved message names the list, and survives a blank name', () {
    expect(savedToListMessage('Favorites'), 'Saved to Favorites');
    expect(savedToListMessage('  Study spots '), 'Saved to Study spots');
    expect(savedToListMessage('   '), 'Saved');
  });

  testWidgets('the saved toast is the dark bar with a Change action', (
    tester,
  ) async {
    var changed = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: TAppTheme.lightTheme,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showSavedToListToast(
                context,
                listDisplayName: 'Favorites',
                onChange: () => changed++,
              ),
              child: const Text('save'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('save'));
    // The toast enters the overlay over a few frames.
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }

    expect(find.text('Saved to Favorites'), findsOneWidget);
    // No "recent list" wording, and no second line with the cafe's name.
    expect(find.textContaining('recent list'), findsNothing);
    final action = tester.widget<Text>(find.text('Change'));
    expect(action.style?.color, const Color(0xFFA3B18A));
    expect(action.style?.fontWeight, FontWeight.w600);

    await tester.tap(find.text('Change'));
    await tester.pump();
    expect(changed, 1);

    // Let the toast finish so no timer outlives the test.
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
    expect(find.text('Saved to Favorites'), findsNothing);
  });

  testWidgets('an action toast with the default timeout waits under a '
      'screen reader', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: TAppTheme.lightTheme,
        home: MediaQuery(
          data: const MediaQueryData(accessibleNavigation: true),
          child: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showPrimaryToastWithAction(
                  context,
                  'Allow location',
                  actionLabel: 'Settings',
                  onAction: () {},
                ),
                child: const Text('go'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('go'));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    await tester.pump(const Duration(seconds: 30));
    expect(find.text('Allow location'), findsOneWidget);
    dismissToasts();
    await tester.pumpAndSettle();
  });
}
