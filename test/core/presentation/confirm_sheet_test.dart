import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/core/presentation/widgets/confirm_sheet.dart';

void main() {
  /// Opens the sheet from a button and records what it resolves to.
  Future<List<bool>> open(
    WidgetTester tester, {
    bool destructive = true,
  }) async {
    final results = <bool>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                results.add(
                  await showConfirmSheet(
                    context,
                    title: 'Discard changes?',
                    message: 'Your edits will not be saved.',
                    confirmLabel: 'Discard',
                    cancelLabel: 'Keep editing',
                    destructive: destructive,
                  ),
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return results;
  }

  Finder pill(String label) => find.ancestor(
    of: find.text(label),
    matching: find.descendant(
      of: find.byType(ConfirmSheet),
      matching: find.byType(Container),
    ),
  );

  testWidgets('lays out the question, line and two 48 actions', (tester) async {
    await open(tester);

    final title = tester.widget<Text>(find.text('Discard changes?'));
    expect(title.style!.fontSize, 20);
    expect(title.style!.fontWeight, FontWeight.w600);
    final body = tester.widget<Text>(
      find.text('Your edits will not be saved.'),
    );
    expect(body.style!.fontSize, 14);
    expect(body.style!.color, const Color(0xFF868584));

    final confirm = pill('Discard').first;
    expect(tester.getSize(confirm).height, 48);
    expect(
      (tester.widget<Container>(confirm).decoration! as BoxDecoration).color,
      const Color(0xFFB3261E),
    );
    final cancel = pill('Keep editing').first;
    expect(tester.getSize(cancel).height, 48);
    expect(
      (tester.widget<Container>(cancel).decoration! as BoxDecoration).color,
      isNull,
    );
  });

  testWidgets('confirm resolves true', (tester) async {
    final results = await open(tester);
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();
    expect(results, [true]);
    expect(find.byType(ConfirmSheet), findsNothing);
  });

  testWidgets('cancel resolves false', (tester) async {
    final results = await open(tester);
    await tester.tap(find.text('Keep editing'));
    await tester.pumpAndSettle();
    expect(results, [false]);
  });

  testWidgets('tapping the scrim resolves false', (tester) async {
    final results = await open(tester);
    await tester.tapAt(const Offset(20, 20));
    await tester.pumpAndSettle();
    expect(results, [false]);
  });

  testWidgets('a non-destructive confirm uses the brand fill', (tester) async {
    await open(tester, destructive: false);
    expect(
      (tester.widget<Container>(pill('Discard').first).decoration!
              as BoxDecoration)
          .color,
      const Color(0xFF344E41),
    );
  });
}
