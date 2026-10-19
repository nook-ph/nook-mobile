import 'package:flutter/material.dart';
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
}
