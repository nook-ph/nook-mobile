import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:nook/core/analytics/retention_tracking_events.dart';
import 'package:nook/core/presentation/widgets/guest_sign_in_sheet.dart';
import 'package:nook/features/auth/presentation/widgets/sign_in_choices.dart';
import 'package:nook/features/cafe_details/presentation/widgets/cafe_guest_sign_in_sheet.dart';

import '../../analytics/recording_analytics.dart';

/// An opener page whose button runs [open], and a stand-in `/login`.
Widget _app(Future<void> Function(BuildContext) open) {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, _) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => open(context),
              child: const Text('open'),
            ),
          ),
        ),
      ),
      GoRoute(
        path: '/login',
        builder: (_, _) => const Scaffold(body: Text('login page')),
      ),
    ],
  );
  return MaterialApp.router(routerConfig: router);
}

Future<void> _guest(BuildContext context) => GuestSignInSheet.show(
  context,
  icon: LucideIcons.bookmark,
  title: 'Sign in to save cafes',
  reason: 'Keep lists.',
  trigger: 'saved_tab',
);

Future<void> _cafe(BuildContext context) => CafeGuestSignInSheet.show(
  context,
  action: CafeGuestAction.wantToTry,
  cafeName: 'Kape',
);

Future<void> _open(
  WidgetTester tester,
  Future<void> Function(BuildContext) open,
) async {
  await tester.pumpWidget(_app(open));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  late RecordingAnalytics analytics;

  setUp(() => analytics = RecordingAnalytics.install(addTearDown));

  group('GuestSignInSheet', () {
    testWidgets('Not now logs shown then dismissed with the trigger', (
      tester,
    ) async {
      await _open(tester, _guest);
      expect(analytics.names, [SignInPromptEvents.shown]);

      await tester.tap(find.text('Not now'));
      await tester.pumpAndSettle();

      expect(analytics.flat, [
        [
          SignInPromptEvents.shown,
          {'trigger': 'saved_tab'},
        ],
        [
          SignInPromptEvents.dismissed,
          {'trigger': 'saved_tab'},
        ],
      ]);
    });

    testWidgets('a scrim tap is a dismissal', (tester) async {
      await _open(tester, _guest);
      await tester.tapAt(const Offset(20, 20));
      await tester.pumpAndSettle();

      expect(analytics.names.last, SignInPromptEvents.dismissed);
    });

    testWidgets('choosing email sign-in is not a dismissal', (tester) async {
      await _open(tester, _guest);
      await tester.tap(find.text(SheetSignInChoices.emailLabel));
      await tester.pumpAndSettle();

      expect(analytics.names, [SignInPromptEvents.shown]);
      expect(find.text('login page'), findsOneWidget);
    });
  });

  group('CafeGuestSignInSheet', () {
    test('every action has a trigger', () {
      expect(
        {
          for (final a in CafeGuestAction.values)
            CafeGuestSignInSheet.triggerFor(a),
        },
        {
          'been',
          'want_to_try',
          'save_to_list',
          'write_review',
          'report_review',
          'helpful_review',
        },
      );
    });

    testWidgets('Not now logs shown then dismissed with the action', (
      tester,
    ) async {
      await _open(tester, _cafe);
      await tester.tap(find.text('Not now'));
      await tester.pumpAndSettle();

      expect(analytics.flat, [
        [
          SignInPromptEvents.shown,
          {'trigger': 'want_to_try'},
        ],
        [
          SignInPromptEvents.dismissed,
          {'trigger': 'want_to_try'},
        ],
      ]);
    });

    testWidgets('choosing email sign-in is not a dismissal', (tester) async {
      await _open(tester, _cafe);
      await tester.tap(find.text(SheetSignInChoices.emailLabel));
      await tester.pumpAndSettle();

      expect(analytics.names, [SignInPromptEvents.shown]);
    });
  });
}
