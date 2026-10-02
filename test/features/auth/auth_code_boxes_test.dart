import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/features/auth/presentation/widgets/auth_code_boxes.dart';
import 'package:nook/features/auth/presentation/widgets/auth_ui.dart';

void main() {
  group('sanitizeAuthCode', () {
    test('keeps digits only', () {
      expect(sanitizeAuthCode('48 29-13'), '482913');
      expect(sanitizeAuthCode('Your code is 482913.'), '482913');
    });

    test('truncates to the code length', () {
      expect(sanitizeAuthCode('4829137788'), '482913');
      expect(sanitizeAuthCode('12345678', length: 4), '1234');
    });

    test('leaves a short code alone', () {
      expect(sanitizeAuthCode('48'), '48');
      expect(sanitizeAuthCode(''), '');
    });
  });

  group('AuthCodeBoxes', () {
    Future<TextEditingController> pump(
      WidgetTester tester, {
      bool hasError = false,
      ValueChanged<String>? onCompleted,
    }) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(24),
              child: AuthCodeBoxes(
                controller: controller,
                hasError: hasError,
                onCompleted: onCompleted,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      return controller;
    }

    Border borderOf(WidgetTester tester, int index) {
      final box = tester.widget<Container>(
        find
            .descendant(
              of: find.byKey(ValueKey('auth-code-box-$index')),
              matching: find.byType(Container),
            )
            .first,
      );
      return (box.decoration! as BoxDecoration).border! as Border;
    }

    testWidgets('draws one box per digit', (tester) async {
      await pump(tester);
      for (var i = 0; i < kSignupOtpLength; i++) {
        expect(find.byKey(ValueKey('auth-code-box-$i')), findsOneWidget);
      }
    });

    testWidgets('typing fills the boxes in order', (tester) async {
      final controller = await pump(tester);
      await tester.enterText(find.byType(TextField), '482');
      await tester.pump();
      expect(controller.text, '482');
      expect(find.text('4'), findsOneWidget);
      expect(find.text('8'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      // The next empty box carries the focus stroke.
      expect(borderOf(tester, 3).top.color, AuthColors.ink);
      expect(borderOf(tester, 4).top.color, AuthColors.border);
    });

    testWidgets('backspace empties the last box', (tester) async {
      final controller = await pump(tester);
      await tester.enterText(find.byType(TextField), '482');
      await tester.enterText(find.byType(TextField), '48');
      await tester.pump();
      expect(controller.text, '48');
      expect(find.text('2'), findsNothing);
      expect(borderOf(tester, 2).top.color, AuthColors.ink);
    });

    testWidgets('a long paste keeps the digits and truncates', (tester) async {
      String? completed;
      final controller = await pump(tester, onCompleted: (c) => completed = c);
      await tester.enterText(find.byType(TextField), 'Code: 482 913 77');
      await tester.pump();
      expect(controller.text, '482913');
      expect(completed, '482913');
    });

    testWidgets('error turns every box red', (tester) async {
      await pump(tester, hasError: true);
      for (var i = 0; i < kSignupOtpLength; i++) {
        expect(borderOf(tester, i).top.color, AuthColors.danger);
      }
    });
  });
}
