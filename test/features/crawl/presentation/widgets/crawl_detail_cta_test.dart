import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/features/crawl/presentation/widgets/crawl_detail_cta.dart';

Widget _buildTestWidget({
  required bool isRegistered,
  bool allStopsClaimed = false,
  VoidCallback? onRegisterTap,
  VoidCallback? onClaimStopTap,
}) {
  return MaterialApp(
    home: Scaffold(
      bottomNavigationBar: CrawlDetailCta(
        isRegistered: isRegistered,
        allStopsClaimed: allStopsClaimed,
        onRegisterTap: onRegisterTap,
        onClaimStopTap: onClaimStopTap,
      ),
    ),
  );
}

void main() {
  group('CrawlDetailCta', () {
    testWidgets('shows Register for Crawl when not registered',
        (WidgetTester tester) async {
      await tester.pumpWidget(_buildTestWidget(isRegistered: false));

      expect(find.text('Register for Crawl'), findsOneWidget);
      expect(find.text('Claim a Stop'), findsNothing);
      expect(find.text('All Stops Claimed'), findsNothing);
    });

    testWidgets('shows Claim a Stop when registered with unclaimed stops',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _buildTestWidget(isRegistered: true, allStopsClaimed: false),
      );

      expect(find.text('Claim a Stop'), findsOneWidget);
      expect(find.text('Register for Crawl'), findsNothing);
      expect(find.text('All Stops Claimed'), findsNothing);
    });

    testWidgets('shows All Stops Claimed disabled when all claimed',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _buildTestWidget(isRegistered: true, allStopsClaimed: true),
      );

      expect(find.text('All Stops Claimed'), findsOneWidget);
      expect(find.text('Register for Crawl'), findsNothing);
      expect(find.text('Claim a Stop'), findsNothing);
    });

    testWidgets('calls onRegisterTap when register button tapped',
        (WidgetTester tester) async {
      var tapped = false;
      await tester.pumpWidget(
        _buildTestWidget(
          isRegistered: false,
          onRegisterTap: () => tapped = true,
        ),
      );

      await tester.tap(find.text('Register for Crawl'));
      expect(tapped, isTrue);
    });

    testWidgets('calls onClaimStopTap when claim button tapped',
        (WidgetTester tester) async {
      var tapped = false;
      await tester.pumpWidget(
        _buildTestWidget(
          isRegistered: true,
          allStopsClaimed: false,
          onClaimStopTap: () => tapped = true,
        ),
      );

      await tester.tap(find.text('Claim a Stop'));
      expect(tapped, isTrue);
    });

    testWidgets('does not call onClaimStopTap when all stops claimed',
        (WidgetTester tester) async {
      var tapped = false;
      await tester.pumpWidget(
        _buildTestWidget(
          isRegistered: true,
          allStopsClaimed: true,
          onClaimStopTap: () => tapped = true,
        ),
      );

      await tester.tap(find.text('All Stops Claimed'));
      expect(tapped, isFalse);
    });
  });
}
