import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/features/guest_saves/presentation/widgets/merge_ask_sheet.dart';

void main() {
  test('copy counts the saves and names up to two', () {
    expect(MergeAskSheet.titleFor(1), 'Add 1 saved cafe?');
    expect(MergeAskSheet.titleFor(3), 'Add 3 saved cafes?');
    expect(MergeAskSheet.addLabelFor(1), 'Add it');
    expect(MergeAskSheet.addLabelFor(3), 'Add them');
    expect(
      MergeAskSheet.reasonFor(1, ['Flavour Coffee']),
      'Flavour Coffee was saved on this phone before. Add it to your '
      'account?',
    );
    expect(
      MergeAskSheet.reasonFor(2, ['Flavour Coffee', 'Kiosk']),
      'Flavour Coffee and Kiosk were saved on this phone before. Add them '
      'to your account?',
    );
    expect(
      MergeAskSheet.reasonFor(3, ['Flavour Coffee', 'Kiosk', 'Brew']),
      'Flavour Coffee, Kiosk and 1 more were saved on this phone before. '
      'Add them to your account?',
    );
    expect(
      MergeAskSheet.reasonFor(3),
      'These were saved on this phone before. Add them to your account?',
    );
    expect(
      MergeAskSheet.reasonFor(1, ['  ']),
      'This was saved on this phone before. Add it to your account?',
    );
  });

  for (final (label, expected) in [
    (MergeAskSheet.addLabel, MergeAskAnswer.add),
    (MergeAskSheet.notNowLabel, MergeAskAnswer.notNow),
  ]) {
    testWidgets('$label answers ${expected.wire}', (tester) async {
      MergeAskAnswer? answer;
      late BuildContext context;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (c) {
              context = c;
              return const Scaffold(body: SizedBox());
            },
          ),
        ),
      );
      MergeAskSheet.show(context, count: 2).then((a) => answer = a);
      await tester.pumpAndSettle();
      expect(find.text(MergeAskSheet.titleFor(2)), findsOneWidget);

      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
      expect(answer, expected);
    });
  }

  testWidgets('a tap on the scrim keeps them, as dismissed', (tester) async {
    MergeAskAnswer? answer;
    late BuildContext context;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (c) {
            context = c;
            return const Scaffold(body: SizedBox());
          },
        ),
      ),
    );
    MergeAskSheet.show(context, count: 2).then((a) => answer = a);
    await tester.pumpAndSettle();

    await tester.tapAt(const Offset(20, 20));
    await tester.pumpAndSettle();
    expect(answer, MergeAskAnswer.dismissed);
  });

  testWidgets('targets are at least 48 high', (tester) async {
    late BuildContext context;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (c) {
            context = c;
            return const Scaffold(body: SizedBox());
          },
        ),
      ),
    );
    MergeAskSheet.show(context, count: 2);
    await tester.pumpAndSettle();
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
  });
}
