import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/features/cafe_details/presentation/widgets/cafe_claim_link.dart';

Widget _host(bool? isClaimed) => MaterialApp(
  home: Scaffold(
    body: CafeClaimLink(cafeId: 'cafe-1', isClaimed: isClaimed),
  ),
);

void main() {
  testWidgets('shows the claim row for an unclaimed cafe', (tester) async {
    await tester.pumpWidget(_host(false));
    expect(find.text('Own this café?'), findsOneWidget);
    expect(find.text('Claim this café'), findsOneWidget);
  });

  testWidgets('hides for a claimed cafe', (tester) async {
    await tester.pumpWidget(_host(true));
    expect(find.text('Claim this café'), findsNothing);
  });

  testWidgets('opens the claim page; a launcher that throws is caught', (
    tester,
  ) async {
    final opened = <Uri>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CafeClaimLink(
            cafeId: 'cafe-1',
            isClaimed: false,
            launch: (uri) async {
              opened.add(uri);
              throw PlatformException(code: 'ACTIVITY_NOT_FOUND');
            },
          ),
        ),
      ),
    );
    await tester.tap(find.text('Claim this café'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      opened.single.toString(),
      'https://business.nookph.app/claim/cafe-1',
    );
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('hides while the claim state is unknown', (tester) async {
    await tester.pumpWidget(_host(null));
    expect(find.text('Claim this café'), findsNothing);
  });
}
