import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/core/presentation/widgets/app_bar_circle_icon_button.dart';
import 'package:nook/core/presentation/widgets/bookmark_icon_button.dart';
import 'package:nook/features/lists/presentation/widgets/lists_ui.dart';
import 'package:nook/utils/theme/theme.dart';

void main() {
  Future<void> pump(WidgetTester tester, Widget child) => tester.pumpWidget(
    MaterialApp(
      theme: TAppTheme.lightTheme,
      home: Scaffold(body: Center(child: child)),
    ),
  );

  void expect44(WidgetTester tester, String label) {
    final size = tester.getSize(find.bySemanticsLabel(label));
    expect(size.width, greaterThanOrEqualTo(44), reason: label);
    expect(size.height, greaterThanOrEqualTo(44), reason: label);
  }

  testWidgets('the cafe header circles are labelled 44pt targets', (
    tester,
  ) async {
    await pump(
      tester,
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppBarCircleIconButton(
            icon: Icons.arrow_back,
            iconSize: 18,
            label: 'Back',
            onTap: () {},
          ),
          BookmarkIconButton(isSaved: false, onTap: () {}),
        ],
      ),
    );
    expect44(tester, 'Back');
    expect44(tester, 'Save');
  });

  testWidgets('a Lists sheet header has 44pt Back and Close', (tester) async {
    await pump(
      tester,
      ListsSheet(title: 'Save to…', onBack: () {}, children: const []),
    );
    expect44(tester, 'Back');
    expect44(tester, 'Close');
  });

  testWidgets('a Lists sheet header takes taps across its whole 44pt', (
    tester,
  ) async {
    var backs = 0;
    var closes = 0;
    await pump(
      tester,
      ListsSheet(
        title: 'Save to…',
        onBack: () => backs++,
        onClose: () => closes++,
        children: const [],
      ),
    );
    // The outer edge, past the drawn 32 box toward the sheet's side.
    final back = tester.getRect(find.bySemanticsLabel('Back'));
    final close = tester.getRect(find.bySemanticsLabel('Close'));
    await tester.tapAt(Offset(back.left + 2, back.center.dy));
    await tester.tapAt(Offset(close.right - 2, close.center.dy));
    expect(backs, 1);
    expect(closes, 1);
  });

  testWidgets('the circled bookmark can be pressed by a screen reader', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pump(tester, BookmarkIconButton(isSaved: false, onTap: () {}));
    final node = tester.getSemantics(find.bySemanticsLabel('Save'));
    expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
    handle.dispose();
  });

  testWidgets('a Lists sheet title without Back starts at the gutter', (
    tester,
  ) async {
    await pump(
      tester,
      const ListsSheet(title: 'Save to…', children: [Text('row')]),
    );
    expect(
      tester.getTopLeft(find.text('Save to…')).dx,
      tester.getTopLeft(find.text('row')).dx,
    );
  });
}
