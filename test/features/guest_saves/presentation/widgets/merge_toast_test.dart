import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/core/presentation/pages/main_screen.dart';
import 'package:nook/core/presentation/tab_requests.dart';
import 'package:nook/features/guest_saves/presentation/guest_saves_merger.dart';
import 'package:nook/features/guest_saves/presentation/widgets/guest_saves_sync.dart';

void main() {
  group('mergeToastMessage', () {
    test('silent when nothing was on the phone', () {
      expect(mergeToastMessage(GuestMergeResult.none), isNull);
    });

    test('everything moved', () {
      expect(
        mergeToastMessage(
          const GuestMergeResult(added: 2, moved: 3, failed: 0),
        ),
        'Moved 3 cafes to your account',
      );
      expect(
        mergeToastMessage(
          const GuestMergeResult(added: 1, moved: 1, failed: 0),
        ),
        'Moved 1 cafe to your account',
      );
    });

    test('some moved', () {
      expect(
        mergeToastMessage(
          const GuestMergeResult(added: 2, moved: 2, failed: 1),
        ),
        'Moved 2 of 3 cafes to your account',
      );
    });

    test('none moved', () {
      expect(
        mergeToastMessage(
          const GuestMergeResult(added: 0, moved: 0, failed: 2),
        ),
        "Couldn't move your saves yet",
      );
    });
  });

  /// The toast overlay goes in after a frame and fades in.
  Future<void> showToast(WidgetTester tester) async {
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  group('showMergeToast', () {
    late BuildContext context;
    late int retries;

    Future<void> pump(WidgetTester tester) async {
      retries = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (c) {
              context = c;
              return const Scaffold(body: SizedBox());
            },
          ),
        ),
      );
    }

    testWidgets('all moved: View opens the Saved tab', (tester) async {
      await pump(tester);
      TabRequest? asked;
      void listen() => asked = TabRequests.requests.value;
      TabRequests.requests.addListener(listen);
      addTearDown(() => TabRequests.requests.removeListener(listen));

      showMergeToast(
        context,
        const GuestMergeResult(added: 3, moved: 3, failed: 0),
        onRetry: () => retries++,
      );
      await showToast(tester);

      expect(find.text('Moved 3 cafes to your account'), findsOneWidget);
      await tester.tap(find.text(mergeViewLabel));
      await showToast(tester);
      expect(asked?.tab, MainShell.savedTab);
      expect(retries, 0);
      await tester.pump(const Duration(seconds: 7));
    });

    testWidgets('partial failure offers Retry', (tester) async {
      await pump(tester);
      showMergeToast(
        context,
        const GuestMergeResult(added: 1, moved: 1, failed: 2),
        onRetry: () => retries++,
      );
      await showToast(tester);

      expect(find.text('Moved 1 of 3 cafes to your account'), findsOneWidget);
      expect(find.text(mergeViewLabel), findsNothing);
      await tester.tap(find.text(mergeRetryLabel));
      await showToast(tester);
      expect(retries, 1);
      await tester.pump(const Duration(seconds: 9));
    });

    testWidgets('nothing to move shows nothing', (tester) async {
      await pump(tester);
      showMergeToast(context, GuestMergeResult.none, onRetry: () {});
      await showToast(tester);
      expect(find.textContaining('Moved'), findsNothing);
      expect(find.textContaining("Couldn't"), findsNothing);
    });

    testWidgets('no timeout while a screen reader is on', (tester) async {
      retries = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(accessibleNavigation: true),
            child: Builder(
              builder: (c) {
                context = c;
                return const Scaffold(body: SizedBox());
              },
            ),
          ),
        ),
      );
      showMergeToast(
        context,
        const GuestMergeResult(added: 2, moved: 2, failed: 0),
        onRetry: () {},
      );
      await showToast(tester);
      await tester.pump(const Duration(seconds: 30));
      expect(find.text('Moved 2 cafes to your account'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.close));
      await showToast(tester);
      expect(find.text('Moved 2 cafes to your account'), findsNothing);
    });
  });
}
