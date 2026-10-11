import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/core/cafe/data/cafe_listing_status_source.dart';
import 'package:nook/features/cafe_details/presentation/widgets/cafe_unverified_note.dart';

Widget _host({
  required bool? isClaimed,
  required Future<CafeListingStatus?> Function(String) loader,
}) => MaterialApp(
  home: Scaffold(
    body: CafeUnverifiedNote(
      cafeId: 'cafe-1',
      isClaimed: isClaimed,
      statusLoader: loader,
    ),
  ),
);

const _unverified = CafeListingStatus(isImported: true, isVerified: false);

void main() {
  test('only an imported, unchecked listing is unverified', () {
    expect(_unverified.isUnverified, isTrue);
    expect(
      const CafeListingStatus(isImported: true, isVerified: true).isUnverified,
      isFalse,
    );
    expect(
      const CafeListingStatus(
        isImported: false,
        isVerified: false,
      ).isUnverified,
      isFalse,
    );
    expect(
      CafeListingStatus.fromJson(const {
        'cafe_id': 'x',
        'is_imported': true,
        'is_verified': false,
      }).isUnverified,
      isTrue,
    );
  });

  testWidgets('shows the pill for an unverified import', (tester) async {
    await tester.pumpWidget(
      _host(isClaimed: false, loader: (_) async => _unverified),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Unverified listing'), findsOneWidget);
    expect(find.textContaining('Info from public sources'), findsOneWidget);
  });

  testWidgets('tapping explains and offers the claim page', (tester) async {
    await tester.pumpWidget(
      _host(isClaimed: false, loader: (_) async => _unverified),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Unverified listing'));
    await tester.pumpAndSettle();
    expect(find.text('Own this café? Claim it'), findsOneWidget);
    expect(find.text('Got it'), findsOneWidget);
  });

  testWidgets('hides for a claimed cafe', (tester) async {
    await tester.pumpWidget(
      _host(isClaimed: true, loader: (_) async => _unverified),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Unverified listing'), findsNothing);
  });

  testWidgets('hides when the status is unavailable', (tester) async {
    await tester.pumpWidget(_host(isClaimed: false, loader: (_) async => null));
    await tester.pumpAndSettle();
    expect(find.textContaining('Unverified listing'), findsNothing);
  });

  testWidgets('hides for a verified import', (tester) async {
    await tester.pumpWidget(
      _host(
        isClaimed: false,
        loader: (_) async =>
            const CafeListingStatus(isImported: true, isVerified: true),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Unverified listing'), findsNothing);
  });
}
