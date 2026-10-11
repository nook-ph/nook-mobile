import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/utils/theme/theme.dart';

void main() {
  testWidgets('the date picker draws on white, not the clear surface', (
    t,
  ) async {
    await t.pumpWidget(
      MaterialApp(
        theme: TAppTheme.lightTheme,
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showDatePicker(
              context: context,
              initialDate: DateTime(2026, 9, 27),
              firstDate: DateTime(2023),
              lastDate: DateTime(2026, 10, 11),
            ),
            child: const Text('Pick'),
          ),
        ),
      ),
    );
    await t.tap(find.text('Pick'));
    await t.pumpAndSettle();

    final dialog = t.widget<Dialog>(find.byType(Dialog));
    expect(dialog.backgroundColor?.a, 1.0);
  });
}
