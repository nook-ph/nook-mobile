import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/core/block/domain/entities/blocked_user.dart';
import 'package:nook/features/profile/presentation/pages/blocked_users_page.dart';
import 'package:nook/features/profile/presentation/widgets/profile_ui.dart';

import 'profile_test_support.dart';

BlockedUser blocked(String id, String username) {
  return BlockedUser(
    userId: id,
    username: username,
    blockedAt: DateTime(2026, 5, 1),
  );
}

void main() {
  final users = [blocked('1', 'maria.c'), blocked('2', 'jp_dev')];

  Future<FakeBlockCubit> pump(
    WidgetTester tester,
    Future<List<BlockedUser>> Function() loadUsers,
  ) async {
    final block = FakeBlockCubit();
    await tester.pumpWidget(
      profileHost(
        block: block,
        page: BlockedUsersPage(loadUsers: loadUsers),
      ),
    );
    await tester.pump();
    return block;
  }

  testWidgets('loading shows skeleton rows, not a spinner', (tester) async {
    final answer = Completer<List<BlockedUser>>();
    await pump(tester, () => answer.future);

    expect(find.bySemanticsLabel('Loading blocked users'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    answer.complete(users);
    await tester.pump();
    await tester.pump();
    expect(find.text('maria.c'), findsOneWidget);
  });

  testWidgets('list: the hint, each person by handle, an Unblock pill each', (
    tester,
  ) async {
    await pump(tester, () async => users);

    expect(find.text('Blocked users'), findsOneWidget);
    expect(
      find.text('You do not see reviews from people you block.'),
      findsOneWidget,
    );
    // The handle without its "@", and its initial in the avatar.
    expect(find.text('maria.c'), findsOneWidget);
    expect(find.text('M'), findsOneWidget);
    expect(find.text('jp_dev'), findsOneWidget);
    expect(find.text('Unblock'), findsNWidgets(2));
  });

  testWidgets('Unblock asks first, then removes the row', (tester) async {
    final block = await pump(tester, () async => users);

    await tester.tap(find.text('Unblock').first);
    await tester.pumpAndSettle();

    expect(find.text('Unblock maria.c?'), findsOneWidget);
    expect(find.text('You will see their reviews again.'), findsOneWidget);
    expect(block.unblocked, isEmpty);

    await tester.tap(find.widgetWithText(ProfilePillButton, 'Unblock').last);
    await tester.pumpAndSettle();

    expect(block.unblocked, ['1']);
    expect(find.text('maria.c'), findsNothing);
    expect(find.text('jp_dev'), findsOneWidget);
    expect(find.text('maria.c unblocked.'), findsOneWidget);
    await letToastExpire(tester);
  });

  testWidgets('cancelling the confirm keeps them blocked', (tester) async {
    final block = await pump(tester, () async => users);

    await tester.tap(find.text('Unblock').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(block.unblocked, isEmpty);
    expect(find.text('maria.c'), findsOneWidget);
  });

  testWidgets('a failed unblock keeps the row and says so', (tester) async {
    final block = await pump(tester, () async => users);
    block.failure = Exception('offline');

    await tester.tap(find.text('Unblock').first);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ProfilePillButton, 'Unblock').last);
    await tester.pumpAndSettle();

    expect(find.text('maria.c'), findsOneWidget);
    expect(find.text('Could not unblock. Please try again.'), findsOneWidget);
    await letToastExpire(tester);
  });

  testWidgets('empty: nobody blocked', (tester) async {
    await pump(tester, () async => const []);

    expect(find.text("You haven't blocked anyone."), findsOneWidget);
    expect(find.text('Blocked users appear here.'), findsOneWidget);
  });

  testWidgets('error: Retry loads again', (tester) async {
    var calls = 0;
    await pump(tester, () async {
      calls++;
      if (calls == 1) throw Exception('offline');
      return users;
    });

    expect(find.text('Could not load blocked users.'), findsOneWidget);

    await tester.tap(find.text('Retry'));
    await tester.pump();
    await tester.pump();
    expect(find.text('maria.c'), findsOneWidget);
  });
}
