import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/features/profile/presentation/cubit/profile_cubit.dart';
import 'package:nook/features/profile/presentation/pages/reviews_page.dart';

import 'profile_test_support.dart';

void main() {
  final reviews = [
    review('a', cafe: 'Tadaima', rating: 5, at: DateTime(2026, 5, 23)),
    review('b', cafe: 'Coffee Bear', rating: 4, at: DateTime(2026, 5, 12)),
    review('c', cafe: 'Brew Szn', rating: 5, at: DateTime(2026, 4, 11)),
  ];

  Future<FakeProfileCubit> pump(WidgetTester tester, ProfileState state) async {
    final cubit = FakeProfileCubit(state);
    await tester.pumpWidget(
      profileHost(page: const ReviewsPage(), cubit: cubit),
    );
    await tester.pump();
    return cubit;
  }

  /// The cafe names on screen, top to bottom.
  List<String> cafesInOrder(WidgetTester tester) {
    final names = [
      'Tadaima',
      'Coffee Bear',
      'Brew Szn',
    ].where((name) => find.text(name).evaluate().isNotEmpty).toList();
    names.sort(
      (a, b) => tester
          .getTopLeft(find.text(a))
          .dy
          .compareTo(tester.getTopLeft(find.text(b)).dy),
    );
    return names;
  }

  testWidgets('list: title with the total, filters, count and newest first', (
    tester,
  ) async {
    await pump(tester, profile(reviews: reviews));

    expect(find.text('Your reviews'), findsOneWidget);
    // Once under the title, once over the list.
    expect(find.text('3 reviews'), findsNWidgets(2));
    expect(find.text('All'), findsOneWidget);
    expect(find.bySemanticsLabel('5 stars'), findsOneWidget);
    expect(find.text('Most recent'), findsOneWidget);
    expect(cafesInOrder(tester), ['Tadaima', 'Coffee Bear', 'Brew Szn']);
  });

  testWidgets('a rating chip narrows the list and its count', (tester) async {
    await pump(tester, profile(reviews: reviews));

    await tester.tap(find.bySemanticsLabel('4 stars'));
    await tester.pump();

    expect(cafesInOrder(tester), ['Coffee Bear']);
    expect(find.text('1 review'), findsOneWidget);
    // The title keeps the total.
    expect(find.text('3 reviews'), findsOneWidget);
  });

  testWidgets('no match says which rating and offers Show all', (tester) async {
    await pump(tester, profile(reviews: reviews));

    await tester.tap(find.bySemanticsLabel('2 stars'));
    await tester.pump();

    expect(find.text('0 reviews'), findsOneWidget);
    expect(find.text('No reviews found.'), findsOneWidget);
    expect(find.text('You have no 2-star reviews.'), findsOneWidget);

    await tester.tap(find.text('Show all'));
    await tester.pump();
    expect(cafesInOrder(tester), hasLength(3));
  });

  testWidgets('the sort sheet ticks the current order and applies a new one', (
    tester,
  ) async {
    await pump(tester, profile(reviews: reviews));

    await tester.tap(find.text('Most recent'));
    await tester.pumpAndSettle();

    expect(find.text('Sort by'), findsOneWidget);
    expect(find.text('Highest rated'), findsOneWidget);
    expect(find.text('Lowest rated'), findsOneWidget);
    expect(find.byType(DropdownButton<String>), findsNothing);

    await tester.tap(find.text('Oldest'));
    await tester.pumpAndSettle();

    expect(find.text('Sort by'), findsNothing);
    expect(find.text('Oldest'), findsOneWidget);
    expect(cafesInOrder(tester), ['Brew Szn', 'Coffee Bear', 'Tadaima']);
  });

  testWidgets('deleting here goes through the same two sheets', (tester) async {
    final cubit = await pump(tester, profile(reviews: reviews));

    await tester.tap(find.bySemanticsLabel('Review options').first);
    await tester.pumpAndSettle();
    expect(find.text('Your review of Tadaima'), findsOneWidget);
    await tester.tap(find.text('Delete review'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(cubit.deleted, ['a']);
    expect(find.text('Review deleted'), findsOneWidget);
    expect(find.text('2 reviews'), findsNWidgets(2));
    expect(cafesInOrder(tester), ['Coffee Bear', 'Brew Szn']);
    await letToastExpire(tester);
  });

  testWidgets('loading: skeleton rows, no spinner, no count yet', (
    tester,
  ) async {
    await pump(tester, const ProfileLoading());

    expect(find.text('Loading…'), findsOneWidget);
    expect(find.bySemanticsLabel('Loading reviews'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.textContaining('reviews'), findsOneWidget);
  });

  testWidgets('error: one message, Retry reloads, no filters', (tester) async {
    final cubit = await pump(
      tester,
      const ProfileError(SocketException('offline')),
    );

    expect(find.text('Could not load reviews.'), findsOneWidget);
    expect(find.text('Check your connection and try again.'), findsOneWidget);
    expect(find.text('All'), findsNothing);

    await tester.tap(find.text('Retry'));
    await tester.pump();
    expect(cubit.loads, 1);
  });

  testWidgets('no reviews at all is not a filter miss', (tester) async {
    await pump(tester, profile());

    expect(find.text('No reviews yet'), findsOneWidget);
    expect(find.text('Show all'), findsNothing);
  });
}
