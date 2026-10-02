import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:nook/features/lists/bloc/lists_event.dart';
import 'package:nook/features/lists/bloc/lists_state.dart';
import 'package:nook/features/profile/presentation/cubit/profile_cubit.dart';
import 'package:nook/features/profile/presentation/pages/profile_pagev2.dart';
import 'package:nook/features/profile/presentation/widgets/profile_ui.dart';

import 'profile_test_support.dart';

void main() {
  final lists = [
    cafeList('1', 'Favorites'),
    cafeList('2', 'Been', places: 2),
    cafeList('3', 'Want to Try', places: 1),
  ];

  Future<void> pump(
    WidgetTester tester, {
    required FakeProfileCubit cubit,
    FakeListsBloc? listsBloc,
  }) async {
    await tester.pumpWidget(
      profileHost(page: const ProfileView(), cubit: cubit, lists: listsBloc),
    );
    await tester.pump();
  }

  testWidgets('loading shows the skeleton, the bare tabs and "@…"', (
    tester,
  ) async {
    final listsBloc = FakeListsBloc();
    await pump(
      tester,
      cubit: FakeProfileCubit(const ProfileLoading()),
      listsBloc: listsBloc,
    );

    expect(find.text('@…'), findsOneWidget);
    expect(find.bySemanticsLabel('Loading profile'), findsOneWidget);
    expect(find.bySemanticsLabel('Loading reviews'), findsOneWidget);
    expect(find.text('Reviews'), findsOneWidget);
    expect(find.text('Lists'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    // The header needs the list count, so the lists load with the profile.
    expect(listsBloc.events.whereType<LoadUserLists>(), hasLength(1));
  });

  testWidgets('loaded: handle, name, counts under the name and on the tabs', (
    tester,
  ) async {
    await pump(
      tester,
      cubit: FakeProfileCubit(
        profile(
          reviews: [
            review('a'),
            review('b', cafe: 'Coffee Bear', rating: 4),
          ],
        ),
      ),
      listsBloc: FakeListsBloc(ListsLoaded(lists)),
    );

    expect(find.text('@saiimonn_'), findsOneWidget);
    expect(find.text('Sai'), findsOneWidget);
    // The app says "lists" where the design file says "collections".
    expect(find.text('2 reviews · 3 lists'), findsOneWidget);
    expect(find.text('Cebu. Remote most days.'), findsOneWidget);
    expect(find.text('Edit profile'), findsOneWidget);
    // No photo: the initial stands in.
    expect(find.text('S'), findsOneWidget);
    // Tab pills.
    expect(find.text('2'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);

    // Reviews are led by the cafe, dated in words.
    expect(find.text('Tadaima'), findsOneWidget);
    expect(find.text('Coffee Bear'), findsOneWidget);
    expect(find.text('May 23, 2026'), findsNWidgets(2));
    expect(find.bySemanticsLabel('4 out of 5 stars'), findsOneWidget);
  });

  testWidgets('more than four reviews link through to Your reviews', (
    tester,
  ) async {
    await pump(
      tester,
      cubit: FakeProfileCubit(
        profile(
          reviews: [
            for (var i = 0; i < 6; i++)
              review('$i', cafe: 'Cafe $i', at: DateTime(2026, 5, 20 - i)),
          ],
        ),
      ),
    );

    expect(find.text('Cafe 3'), findsOneWidget);
    expect(find.text('Cafe 4'), findsNothing);

    await tester.scrollUntilVisible(
      find.text('See all 6 reviews'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('See all 6 reviews'));
    await tester.pumpAndSettle();

    expect(find.text('Your reviews'), findsOneWidget);
    expect(find.text('Cafe 5'), findsOneWidget);
  });

  testWidgets('no reviews: the empty message, no rows', (tester) async {
    await pump(tester, cubit: FakeProfileCubit(profile()));

    expect(find.text('No reviews yet'), findsOneWidget);
    expect(
      find.text('When you share reviews, they will appear here.'),
      findsOneWidget,
    );
    expect(find.text('0'), findsOneWidget);
  });

  testWidgets('a review is deleted through options, then a confirm sheet', (
    tester,
  ) async {
    final cubit = FakeProfileCubit(profile(reviews: [review('a')]));
    await pump(tester, cubit: cubit);

    await tester.tap(find.bySemanticsLabel('Review options'));
    await tester.pumpAndSettle();
    expect(find.text('Your review of Tadaima'), findsOneWidget);
    expect(
      find.text('Removes it from the cafe page and your profile'),
      findsOneWidget,
    );

    await tester.tap(find.text('Delete review'));
    await tester.pumpAndSettle();
    expect(find.text('Delete this review?'), findsOneWidget);
    expect(find.text('This cannot be undone.'), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
    expect(cubit.deleted, isEmpty);

    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(cubit.deleted, ['a']);
    expect(find.text('Review deleted'), findsOneWidget);
    expect(find.text('No reviews yet'), findsOneWidget);
    await letToastExpire(tester);
  });

  testWidgets('cancelling the confirm sheet keeps the review', (tester) async {
    final cubit = FakeProfileCubit(profile(reviews: [review('a')]));
    await pump(tester, cubit: cubit);

    await tester.tap(find.bySemanticsLabel('Review options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete review'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(cubit.deleted, isEmpty);
    expect(find.text('Tadaima'), findsOneWidget);
  });

  testWidgets('a failed delete says so and keeps the review', (tester) async {
    final cubit = FakeProfileCubit(profile(reviews: [review('a')]))
      ..failure = const SocketException('offline');
    await pump(tester, cubit: cubit);

    await tester.tap(find.bySemanticsLabel('Review options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete review'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(
      find.text('Could not delete the review. Please try again.'),
      findsOneWidget,
    );
    expect(find.text('Tadaima'), findsOneWidget);
    await letToastExpire(tester);
  });

  group('Lists tab', () {
    Future<void> openLists(WidgetTester tester) async {
      await tester.tap(find.text('Lists'));
      await tester.pumpAndSettle();
    }

    testWidgets('tiles name each list and how many places it holds', (
      tester,
    ) async {
      await pump(
        tester,
        cubit: FakeProfileCubit(profile()),
        listsBloc: FakeListsBloc(ListsLoaded(lists)),
      );
      await openLists(tester);

      expect(find.text('Create new list'), findsOneWidget);
      expect(find.text('Favorites'), findsOneWidget);
      expect(find.text('0 places'), findsOneWidget);
      expect(find.text('Been'), findsOneWidget);
      expect(find.text('2 places'), findsOneWidget);
      expect(find.text('1 place'), findsOneWidget);
    });

    testWidgets('loading shows skeleton tiles under the create row', (
      tester,
    ) async {
      await pump(
        tester,
        cubit: FakeProfileCubit(profile()),
        listsBloc: FakeListsBloc(ListsLoading()),
      );
      await openLists(tester);

      expect(find.text('Create new list'), findsOneWidget);
      expect(find.byType(ProfileSkeleton), findsWidgets);
      expect(find.text('No lists yet'), findsNothing);
      // The count is unknown, so the header does not guess one.
      expect(find.text('0 reviews'), findsOneWidget);
    });

    testWidgets('empty keeps the create row over the message', (tester) async {
      await pump(
        tester,
        cubit: FakeProfileCubit(profile()),
        listsBloc: FakeListsBloc(ListsLoaded(const [])),
      );
      await openLists(tester);

      expect(find.text('Create new list'), findsOneWidget);
      expect(find.text('No lists yet'), findsOneWidget);
      expect(
        find.text('Save your favourite cafes into lists.'),
        findsOneWidget,
      );
    });

    testWidgets('error offers Retry, which reloads the lists', (tester) async {
      final listsBloc = FakeListsBloc(
        ListsError(const SocketException('offline')),
      );
      await pump(
        tester,
        cubit: FakeProfileCubit(profile()),
        listsBloc: listsBloc,
      );
      await openLists(tester);

      expect(find.text('Could not load lists.'), findsOneWidget);
      expect(find.text('Create new list'), findsNothing);
      final before = listsBloc.events.whereType<LoadUserLists>().length;

      await tester.tap(find.text('Retry'));
      await tester.pump();
      expect(
        listsBloc.events.whereType<LoadUserLists>(),
        hasLength(before + 1),
      );
    });
  });

  testWidgets('page error: plain title, one message, Retry reloads', (
    tester,
  ) async {
    final cubit = FakeProfileCubit(
      const ProfileError(SocketException('offline')),
    );
    await pump(tester, cubit: cubit);

    expect(find.text('Profile'), findsOneWidget);
    expect(find.text('Something went wrong'), findsOneWidget);
    expect(
      find.text(
        'We could not load your profile. Check your connection and try again.',
      ),
      findsOneWidget,
    );
    expect(find.byIcon(LucideIcons.triangleAlert), findsOneWidget);
    expect(find.bySemanticsLabel('Settings'), findsOneWidget);

    await tester.tap(find.text('Retry'));
    await tester.pump();
    expect(cubit.loads, 1);
  });

  testWidgets('signed out: says why and links to sign-in', (tester) async {
    final listsBloc = FakeListsBloc();
    await pump(
      tester,
      cubit: FakeProfileCubit(const ProfileUnauthenticated()),
      listsBloc: listsBloc,
    );

    expect(find.text('Profile'), findsOneWidget);
    expect(find.text('Sign in to see your profile'), findsOneWidget);
    expect(
      find.text(
        'Keep your reviews, lists and the places you have been in one place.',
      ),
      findsOneWidget,
    );
    // Nothing to configure and nothing to load for a guest.
    expect(find.bySemanticsLabel('Settings'), findsNothing);
    expect(listsBloc.events, isEmpty);

    await tester.tap(find.text('Sign in or create account'));
    await tester.pumpAndSettle();
    expect(find.text('route:/login'), findsOneWidget);
  });
}
