import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:nook/features/crawl/presentation/widgets/stamp_awarded_overlay.dart';

void main() {
  group('StampAwardedOverlay', () {
    testWidgets('renders correct stop number text',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                Positioned.fill(child: Container(color: Colors.white)),
                const StampAwardedOverlay(stopOrder: 5),
              ],
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(StampAwardedOverlay), findsOneWidget);
      expect(find.byIcon(LucideIcons.stamp), findsOneWidget);
      expect(find.byIcon(LucideIcons.x), findsOneWidget);
      expect(find.byIcon(LucideIcons.share2), findsOneWidget);
      expect(find.text('Stop 5 claimed!'), findsOneWidget);
    });

    testWidgets('animates without error', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                Positioned.fill(child: Container(color: Colors.white)),
                const StampAwardedOverlay(stopOrder: 3),
              ],
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      expect(tester.takeException(), isNull);
      expect(find.text('Stop 3 claimed!'), findsOneWidget);
    });

    testWidgets('calls onShare when share button is tapped',
        (WidgetTester tester) async {
      bool called = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                Positioned.fill(child: Container(color: Colors.white)),
                StampAwardedOverlay(
                  stopOrder: 5,
                  onShare: () => called = true,
                ),
              ],
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.tap(find.byIcon(LucideIcons.share2));
      await tester.pumpAndSettle();

      expect(called, isTrue);
    });

    testWidgets('calls onClose when X button is tapped',
        (WidgetTester tester) async {
      bool called = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                Positioned.fill(child: Container(color: Colors.white)),
                StampAwardedOverlay(
                  stopOrder: 5,
                  onClose: () => called = true,
                ),
              ],
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.tap(find.byIcon(LucideIcons.x));
      await tester.pumpAndSettle();

      expect(called, isTrue);
    });
  });
}
