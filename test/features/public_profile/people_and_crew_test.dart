import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:nook/features/crawls/presentation/widgets/invite_crew_sheet.dart';
import 'package:nook/features/public_profile/domain/entities/public_profile.dart';
import 'package:nook/features/public_profile/domain/i_public_profile_repository.dart';
import 'package:nook/features/public_profile/presentation/pages/public_profile_page.dart';
import 'package:nook/features/public_profile/presentation/widgets/people_matches.dart';

import '../crawls/crawl_fixtures.dart';
import 'public_profile_fakes.dart';

void main() {
  late FakePublicProfileRepository repo;

  setUp(() {
    repo = FakePublicProfileRepository(profile: beaProfile());
    GetIt.instance.registerSingleton<IPublicProfileRepository>(repo);
  });
  tearDown(GetIt.instance.reset);

  test('only "@" plus username characters is a people search', () {
    expect(peopleQuery('@bea'), 'bea');
    expect(peopleQuery(' @bea_s '), 'bea_s');
    expect(peopleQuery('@'), isNull);
    expect(peopleQuery('bea'), isNull);
    expect(peopleQuery('@bea santos'), isNull);
  });

  testWidgets('"@bea" lists matching people; a row opens the profile', (
    tester,
  ) async {
    repo.people = const [
      PersonMatch(userId: 'bea-id', username: 'beasantos', fullName: 'Bea'),
    ];
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: PeopleMatches(prefix: 'bea')),
      ),
    );
    expect(find.text('People'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 300));
    expect(repo.searched, ['bea']);
    expect(find.text('@beasantos'), findsOneWidget);

    await tester.tap(find.text('@beasantos'));
    await tester.pumpAndSettle();
    expect(find.byType(PublicProfilePage), findsOneWidget);
    expect(repo.asked.single.username, 'beasantos');
  });

  testWidgets('no match says so', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: PeopleMatches(prefix: 'zz')),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('No one goes by @zz'), findsOneWidget);
  });

  testWidgets('a crew member opens their profile; you do not', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: InviteCrewSheet(run: run(stops: 5, stamped: 2, withCrew: true)),
        ),
      ),
    );
    expect(find.bySemanticsLabel('Open @cris’s profile'), findsNothing);
    await tester.tap(find.text('@mika'));
    await tester.pumpAndSettle();
    expect(find.byType(PublicProfilePage), findsOneWidget);
    expect(repo.asked.single.username, 'mika');
  });
}
