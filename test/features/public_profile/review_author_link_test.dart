import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:nook/features/cafe_details/domain/entities/cafe_details_entity.dart';
import 'package:nook/features/cafe_details/presentation/widgets/review_row.dart';
import 'package:nook/features/public_profile/domain/i_public_profile_repository.dart';
import 'package:nook/features/public_profile/presentation/pages/public_profile_page.dart';
import 'package:nook/features/public_profile/presentation/widgets/review_author_link.dart';

import 'public_profile_fakes.dart';

void main() {
  late FakePublicProfileRepository repo;

  setUp(() {
    repo = FakePublicProfileRepository(profile: beaProfile());
    GetIt.instance.registerSingleton<IPublicProfileRepository>(repo);
  });
  tearDown(GetIt.instance.reset);

  ReviewEntity review({String userId = 'bea-id'}) => ReviewEntity(
    id: 'r1',
    cafeId: 'cafe-1',
    userId: userId,
    rating: 5,
    content: 'Quiet upstairs.',
    createdAt: DateTime(2026, 9, 1),
    updatedAt: DateTime(2026, 9, 1),
    name: 'Bea Santos',
  );

  Future<void> pump(WidgetTester tester, Widget row) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: SingleChildScrollView(child: row)),
      ),
    );
  }

  testWidgets('tapping a reviewer’s name opens their public profile', (
    tester,
  ) async {
    await pump(tester, ReviewRow(review: review(), currentUserId: 'me'));
    await tester.tap(find.text('Bea Santos'));
    await tester.pumpAndSettle();

    expect(find.byType(PublicProfilePage), findsOneWidget);
    expect(repo.asked.single.userId, 'bea-id');
    expect(find.text('@beasantos'), findsOneWidget);
  });

  testWidgets('a linked name carries a chevron; your own does not', (
    tester,
  ) async {
    await pump(tester, ReviewRow(review: review(), currentUserId: 'me'));
    expect(
      find.descendant(
        of: find.byType(ReviewAuthorName),
        matching: find.byType(Icon),
      ),
      findsOneWidget,
    );
    await pump(
      tester,
      ReviewRow(
        review: review(userId: 'me'),
        currentUserId: 'me',
        isOwn: true,
      ),
    );
    expect(
      find.descendant(
        of: find.byType(ReviewAuthorName),
        matching: find.byType(Icon),
      ),
      findsNothing,
    );
  });

  testWidgets('your own review does not link to a profile', (tester) async {
    await pump(
      tester,
      ReviewRow(
        review: review(userId: 'me'),
        currentUserId: 'me',
        isOwn: true,
      ),
    );
    expect(find.bySemanticsLabel('Open Bea Santos’s profile'), findsNothing);
  });
}
