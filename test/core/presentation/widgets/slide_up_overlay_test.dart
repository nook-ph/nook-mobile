import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/core/presentation/widgets/slide_up_overlay.dart';

Widget _buildTestWidget({required bool visible, Widget? child}) {
  return MaterialApp(
    home: Scaffold(
      body: Stack(
        children: [
          SlideUpOverlay(
            visible: visible,
            child: child ?? const Text('Overlay Content'),
          ),
        ],
      ),
    ),
  );
}

void main() {
  group('SlideUpOverlay', () {
    testWidgets('renders child when visible is true',
        (WidgetTester tester) async {
      await tester.pumpWidget(_buildTestWidget(visible: true));

      expect(find.text('Overlay Content'), findsOneWidget);
    });

    testWidgets('hides child when visible is false',
        (WidgetTester tester) async {
      await tester.pumpWidget(_buildTestWidget(visible: false));

      expect(find.text('Overlay Content'), findsNothing);
    });

    testWidgets('animates child when visible changes from false to true',
        (WidgetTester tester) async {
      await tester.pumpWidget(_buildTestWidget(visible: false));

      expect(find.text('Overlay Content'), findsNothing);

      await tester.pumpWidget(_buildTestWidget(visible: true));
      await tester.pumpAndSettle();

      expect(find.text('Overlay Content'), findsOneWidget);
    });

    testWidgets('animates child when visible changes from true to false',
        (WidgetTester tester) async {
      await tester.pumpWidget(_buildTestWidget(visible: true));

      expect(find.text('Overlay Content'), findsOneWidget);

      await tester.pumpWidget(_buildTestWidget(visible: false));
      await tester.pumpAndSettle();

      expect(find.text('Overlay Content'), findsNothing);
    });

    testWidgets('renders custom child widget', (WidgetTester tester) async {
      await tester.pumpWidget(
        _buildTestWidget(
          visible: true,
          child: const SizedBox(
            width: 200,
            height: 100,
            child: Center(child: Text('Custom Widget')),
          ),
        ),
      );

      expect(find.text('Custom Widget'), findsOneWidget);
    });

    testWidgets('renders without overflow on narrow screen',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        Builder(
          builder: (context) => MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 320,
                child: Stack(
                  children: [
                    SlideUpOverlay(
                      visible: true,
                      child: Container(
                        height: 300,
                        color: Colors.white,
                        child: const Column(
                          children: [
                            Text('Title'),
                            Text('Subtitle'),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });
}
