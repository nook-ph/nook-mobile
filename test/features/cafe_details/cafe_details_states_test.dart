import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:nook/core/cafe/data/cafe_remote_data_source.dart';
import 'package:nook/core/presentation/widgets/review_photo_viewer.dart';
import 'package:nook/core/utils/error_info.dart';
import 'package:nook/features/cafe_details/presentation/utils/cafe_load_failure.dart';
import 'package:nook/features/cafe_details/presentation/utils/cafe_open_status.dart';
import 'package:nook/features/cafe_details/presentation/widgets/cafe_details_common.dart';
import 'package:nook/features/cafe_details/presentation/widgets/cafe_details_error_view.dart';
import 'package:nook/features/cafe_details/presentation/widgets/cafe_details_skeleton.dart';
import 'package:nook/features/cafe_details/presentation/widgets/cafe_guest_sign_in_sheet.dart';
import 'package:nook/utils/theme/theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Map<String, dynamic> _week(String open, String close) => {
  for (final day in CafeOpenStatus.orderedDays)
    day: {'open': open, 'close': close},
};

Widget _host(Widget child) =>
    MaterialApp(theme: TAppTheme.lightTheme, home: child);

void main() {
  group('CafeOpenStatus soon states', () {
    // 2026-10-01 is a Thursday. Hours are Manila wall-clock times (UTC+8),
    // so the instant is built from UTC and reads the same in any zone.
    DateTime at(int hour, int minute) => DateTime.utc(
      2026,
      10,
      1,
      hour,
      minute,
    ).subtract(const Duration(hours: 8));

    test('opens soon within 30 minutes of opening', () {
      final status = CafeOpenStatus.resolve(_week('07:00', '22:00'), at(6, 40));

      expect(status.isOpen, isFalse);
      expect(status.opensSoon, isTrue);
      expect(status.closesSoon, isFalse);
      expect(status.minutesUntilChange, 20);
      expect(status.label, 'Opens soon');
      expect(status.shortDetail, '7 AM');
      expect(status.rowDetail, '7:00 AM, in 20 min');
      expect(status.barText, 'Opens 7 AM · in 20 min');
    });

    test('is plain closed more than 30 minutes before opening', () {
      final status = CafeOpenStatus.resolve(_week('07:00', '22:00'), at(6, 0));

      expect(status.opensSoon, isFalse);
      expect(status.label, 'Closed');
      expect(status.barText, 'Closed · opens 7 AM');
    });

    test('closes soon within 30 minutes of closing', () {
      final status = CafeOpenStatus.resolve(
        _week('07:00', '22:00'),
        at(21, 35),
      );

      expect(status.isOpen, isTrue);
      expect(status.closesSoon, isTrue);
      expect(status.minutesUntilChange, 25);
      expect(status.label, 'Closes soon');
      expect(status.shortDetail, '10 PM');
      expect(status.rowDetail, '10:00 PM, in 25 min');
      expect(status.barText, 'Closes 10 PM · in 25 min');
    });

    test('the threshold is inclusive at 30 minutes', () {
      expect(
        CafeOpenStatus.resolve(_week('07:00', '22:00'), at(21, 30)).closesSoon,
        isTrue,
      );
      expect(
        CafeOpenStatus.resolve(_week('07:00', '22:00'), at(21, 29)).closesSoon,
        isFalse,
      );
    });

    test('is plain open earlier in the day', () {
      final status = CafeOpenStatus.resolve(_week('07:00', '22:00'), at(12, 0));

      expect(status.isSoon, isFalse);
      expect(status.label, 'Open');
      expect(status.barText, 'Open until 10 PM');
    });

    test('counts past midnight for overnight hours', () {
      final status = CafeOpenStatus.resolve(
        _week('18:00', '00:15'),
        at(23, 55),
      );

      expect(status.isOpen, isTrue);
      expect(status.closesSoon, isTrue);
      expect(status.minutesUntilChange, 20);
    });

    test('never closes soon when open round the clock', () {
      // 00:00-24:00 every day; 00:00-00:00 is a placeholder (see below).
      final status = CafeOpenStatus.resolve(
        _week('00:00', '24:00'),
        at(23, 50),
      );

      expect(status.isOpen, isTrue);
      expect(status.closesSoon, isFalse);
      expect(status.label, 'Open');
    });

    test('after closing it is closed, not opening soon', () {
      final status = CafeOpenStatus.resolve(_week('07:00', '22:00'), at(23, 0));

      expect(status.isOpen, isFalse);
      expect(status.opensSoon, isFalse);
      expect(status.minutesUntilChange, isNull);
    });

    test('soon states are amber', () {
      final soon = CafeOpenStatus.resolve(_week('07:00', '22:00'), at(21, 50));
      final open = CafeOpenStatus.resolve(_week('07:00', '22:00'), at(12, 0));

      expect(CafeDetailsTokens.statusLabel(soon), CafeDetailsTokens.soon);
      expect(CafeDetailsTokens.statusDot(soon), CafeDetailsTokens.soon);
      expect(CafeDetailsTokens.statusLabel(open), CafeDetailsTokens.brand);
      expect(CafeDetailsTokens.statusDot(open), CafeDetailsTokens.openDot);
    });
  });

  group('CafeLoadFailure', () {
    CafeFetchException wrap(Object cause) =>
        CafeFetchException('Failed to fetch cafe bundle.', cause: cause);

    test('a missing row is not found', () {
      final failure = CafeLoadFailure.from(
        wrap(
          const PostgrestException(
            message: 'JSON object requested, multiple (or no) rows returned',
            code: 'PGRST116',
          ),
        ),
      );

      expect(failure.isNotFound, isTrue);
    });

    test('a malformed id is not found', () {
      final failure = CafeLoadFailure.from(
        wrap(const PostgrestException(message: 'invalid input', code: '22P02')),
      );

      expect(failure.isNotFound, isTrue);
    });

    test('other database errors are server errors', () {
      final failure = CafeLoadFailure.from(
        wrap(const PostgrestException(message: 'boom', code: '500')),
      );

      expect(failure.isNotFound, isFalse);
      expect(failure.info.type, ErrorType.serverError);
    });

    test('a lapsed session is signed out', () {
      final failure = CafeLoadFailure.from(
        wrap(const PostgrestException(message: 'jwt expired', code: '401')),
      );

      expect(failure.info.type, ErrorType.sessionExpired);
    });

    test('a dropped connection is offline, through the wrapper', () {
      expect(
        CafeLoadFailure.from(wrap(const SocketException('no route'))).info.type,
        ErrorType.offline,
      );
      expect(
        CafeLoadFailure.from(
          wrap(http.ClientException('Connection failed')),
        ).info.type,
        ErrorType.offline,
      );
    });

    test('anything else keeps the generic copy', () {
      final failure = CafeLoadFailure.from(wrap(StateError('odd')));

      expect(failure.isNotFound, isFalse);
      expect(failure.info.type, ErrorType.unknown);
      expect(failure.info.title, "We couldn't complete that");
    });
  });

  group('CafeDetailsErrorView', () {
    testWidgets('offline offers Try again', (tester) async {
      var retried = 0;
      await tester.pumpWidget(
        _host(
          CafeDetailsErrorView.forError(
            info: CafeLoadFailure.from(const SocketException('x')).info,
            onRetry: () => retried++,
            onSignIn: () {},
            onBack: () {},
          ),
        ),
      );

      expect(find.text("You're offline"), findsOneWidget);
      expect(find.text('Check your connection and try again'), findsOneWidget);
      await tester.tap(find.text('Try again'));
      expect(retried, 1);
    });

    testWidgets('signed out offers Sign in', (tester) async {
      var signedIn = 0;
      await tester.pumpWidget(
        _host(
          CafeDetailsErrorView.forError(
            info: CafeLoadFailure.from(const AuthException('expired')).info,
            onRetry: () {},
            onSignIn: () => signedIn++,
            onBack: () {},
          ),
        ),
      );

      expect(find.text("You've been signed out"), findsOneWidget);
      expect(find.text('Try again'), findsNothing);
      await tester.tap(find.text('Sign in'));
      expect(signedIn, 1);
    });

    testWidgets('not found offers search and home', (tester) async {
      var searched = 0, home = 0, back = 0;
      await tester.pumpWidget(
        _host(
          CafeDetailsErrorView.notFound(
            onSearch: () => searched++,
            onHome: () => home++,
            onBack: () => back++,
          ),
        ),
      );

      expect(find.text('This cafe is no longer on Nook'), findsOneWidget);
      expect(find.text('It may have closed or been removed.'), findsOneWidget);
      await tester.tap(find.text('Search cafes'));
      await tester.tap(find.text('Back to home'));
      await tester.tap(find.bySemanticsLabel('Back'));
      expect((searched, home, back), (1, 1, 1));
      expect(tester.takeException(), isNull);
    });
  });

  group('CafeGuestSignInSheet', () {
    test('each guest action has its own reason', () {
      expect(
        CafeGuestSignInSheet.titleFor(CafeGuestAction.been, 'Tadaima'),
        'Sign in to keep a Been list',
      );
      expect(
        CafeGuestSignInSheet.titleFor(CafeGuestAction.wantToTry, 'Tadaima'),
        'Sign in to save Tadaima',
      );
      expect(
        CafeGuestSignInSheet.titleFor(CafeGuestAction.saveToList, 'Tadaima'),
        'Sign in to save to a list',
      );
      expect(
        CafeGuestSignInSheet.messageFor(CafeGuestAction.wantToTry),
        'Keep a Want to try list and come back to it later.',
      );
    });

    testWidgets('Not now closes the sheet without signing in', (tester) async {
      await tester.pumpWidget(
        _host(
          Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => CafeGuestSignInSheet.show(
                  context,
                  action: CafeGuestAction.been,
                  cafeName: 'Tadaima',
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('Sign in to keep a Been list'), findsOneWidget);
      expect(find.text('Sign in or create account'), findsOneWidget);

      await tester.tap(find.text('Not now'));
      await tester.pumpAndSettle();
      expect(find.text('Sign in to keep a Been list'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('Skeletons', () {
    testWidgets('sheet and bar skeletons lay out', (tester) async {
      await tester.pumpWidget(
        _host(
          const Scaffold(
            body: SingleChildScrollView(child: CafeDetailsSkeleton()),
            bottomNavigationBar: CafeActionsBarSkeleton(),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.bySemanticsLabel('Loading cafe details'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('Photo viewer', () {
    testWidgets('shows counter, close and pager dots', (tester) async {
      await tester.pumpWidget(
        _host(
          const ReviewPhotoViewer(
            imageUrls: [
              'https://example.com/a.jpg',
              'https://example.com/b.jpg',
            ],
            initialIndex: 1,
          ),
        ),
      );
      await tester.pump();

      expect(find.text('2 / 2'), findsOneWidget);
      expect(find.bySemanticsLabel('Close'), findsOneWidget);
      // Network images fail under the test binding (every request is a
      // 400), so this is also the failed-photo state: words, not a glyph.
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)),
      );
      await tester.pump();
      expect(find.text('Photo could not be loaded'), findsWidgets);
    });
  });
}
