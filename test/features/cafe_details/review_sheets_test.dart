import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/core/cafe/domain/entities/report_reason.dart';
import 'package:nook/features/cafe_details/presentation/widgets/cafe_guest_sign_in_sheet.dart';
import 'package:nook/features/cafe_details/presentation/widgets/review_actions_sheet.dart';
import 'package:nook/features/cafe_details/presentation/widgets/review_sheet_shell.dart';
import 'package:nook/utils/theme/theme.dart';

/// A page with one button that opens [sheet] and records what it popped.
class _Opener<T> extends StatelessWidget {
  const _Opener({required this.sheet, required this.onResult});

  final Widget sheet;
  final ValueChanged<T?> onResult;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: TAppTheme.lightTheme,
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () async => onResult(
              await ReviewSheetShell.show<T>(context, builder: (_) => sheet),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
  }
}

Future<void> _open(WidgetTester tester) async {
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  group('ReviewOptionsSheet', () {
    testWidgets('another user: titled by author, report and block in words', (
      tester,
    ) async {
      ReviewOption? result;
      await tester.pumpWidget(
        _Opener<ReviewOption>(
          sheet: ReviewOptionsSheet.forOther(authorName: 'maria.c'),
          onResult: (value) => result = value,
        ),
      );
      await _open(tester);

      expect(find.text('Review by maria.c'), findsOneWidget);
      expect(find.text('Report review'), findsOneWidget);
      expect(
        find.text('Flag objectionable or abusive content'),
        findsOneWidget,
      );
      expect(
        find.text('Hide this user and report their content'),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel('Close'), findsOneWidget);
      // Text rows only: the old leading flag and block icons are gone.
      expect(find.byIcon(Icons.flag_outlined), findsNothing);
      expect(find.byIcon(Icons.block), findsNothing);

      final block = tester.widget<Text>(find.text('Block maria.c'));
      expect(block.style?.color, const Color(0xFFB3261E));

      await tester.tap(find.text('Block maria.c'));
      await tester.pumpAndSettle();
      expect(result, ReviewOption.block);
    });

    testWidgets('no author name falls back to neutral copy', (tester) async {
      await tester.pumpWidget(
        _Opener<ReviewOption>(
          sheet: ReviewOptionsSheet.forOther(authorName: '  '),
          onResult: (_) {},
        ),
      );
      await _open(tester);

      expect(find.text('Review options'), findsOneWidget);
      expect(find.text('Block this user'), findsOneWidget);
    });

    testWidgets('own review offers only Delete, naming the cafe', (
      tester,
    ) async {
      ReviewOption? result;
      await tester.pumpWidget(
        _Opener<ReviewOption>(
          sheet: ReviewOptionsSheet.forOwn(cafeName: 'Tadaima'),
          onResult: (value) => result = value,
        ),
      );
      await _open(tester);

      expect(find.text('Your review'), findsOneWidget);
      expect(
        find.text('Removes your rating, text and photos from Tadaima'),
        findsOneWidget,
      );
      expect(find.text('Report review'), findsNothing);

      await tester.tap(find.text('Delete review'));
      await tester.pumpAndSettle();
      expect(result, ReviewOption.delete);
    });
  });

  group('ReviewConfirmSheet', () {
    testWidgets('block: Figma copy, Block confirms', (tester) async {
      bool? result;
      await tester.pumpWidget(
        _Opener<bool>(
          sheet: ReviewConfirmSheet.blockUser(authorName: 'maria.c'),
          onResult: (value) => result = value,
        ),
      );
      await _open(tester);

      expect(find.text('Block maria.c?'), findsOneWidget);
      expect(
        find.text(
          'You will no longer see their reviews, and their content will be '
          'reported. You can unblock them in Settings.',
        ),
        findsOneWidget,
      );
      expect(find.byType(AlertDialog), findsNothing);

      await tester.tap(find.text('Block'));
      await tester.pumpAndSettle();
      expect(result, isTrue);
    });

    testWidgets('delete: Cancel returns false', (tester) async {
      bool? result;
      await tester.pumpWidget(
        _Opener<bool>(
          sheet: ReviewConfirmSheet.deleteReview(cafeName: 'Tadaima'),
          onResult: (value) => result = value,
        ),
      );
      await _open(tester);

      expect(find.text('Delete your review?'), findsOneWidget);
      expect(
        find.text(
          'Your rating, text and photos will be removed from Tadaima. '
          'This cannot be undone.',
        ),
        findsOneWidget,
      );

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(result, isFalse);
    });
  });

  group('ReviewReportSheet', () {
    testWidgets('submit is off until a reason is picked, then sends it', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      bool? result;
      (ReportReason, String)? sent;
      await tester.pumpWidget(
        _Opener<bool>(
          sheet: ReviewReportSheet(
            onSubmit: (reason, details) async => sent = (reason, details),
          ),
          onResult: (value) => result = value,
        ),
      );
      await _open(tester);

      expect(find.text('Why are you reporting this review?'), findsOneWidget);
      for (final reason in ReportReason.values) {
        expect(find.text(reason.label), findsOneWidget);
      }
      expect(find.byType(RadioListTile<ReportReason>), findsNothing);

      // Nothing picked: tapping the button does nothing.
      await tester.tap(find.text('Submit report'));
      await tester.pumpAndSettle();
      expect(sent, isNull);

      await tester.tap(find.text('Spam or advertising'));
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'Links to a shop');
      await tester.tap(find.text('Submit report'));
      await tester.pumpAndSettle();

      expect(sent, (ReportReason.spam, 'Links to a shop'));
      expect(result, isTrue);
      expect(tester.takeException(), isNull);
    });
  });

  group('ReviewPrimaryButton', () {
    Widget host(Widget child) => MaterialApp(
      theme: TAppTheme.lightTheme,
      home: Scaffold(body: child),
    );

    Color fill(WidgetTester tester) {
      final box = tester.widget<Container>(
        find.descendant(
          of: find.byType(ReviewPrimaryButton),
          matching: find.byType(Container),
        ),
      );
      return (box.decoration! as BoxDecoration).color!;
    }

    testWidgets('disabled is grey, not a faded green', (tester) async {
      await tester.pumpWidget(
        host(const ReviewPrimaryButton(label: 'Submit review', onTap: null)),
      );

      expect(fill(tester), const Color(0xFFEEEEEE));
      expect(
        tester.widget<Text>(find.text('Submit review')).style?.color,
        const Color(0xFF868584),
      );
    });

    testWidgets('busy with a label shows it beside the spinner', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          ReviewPrimaryButton(
            label: 'Submit review',
            busy: true,
            busyLabel: 'Posting…',
            onTap: () {},
          ),
        ),
      );

      expect(find.text('Posting…'), findsOneWidget);
      expect(find.text('Submit review'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(fill(tester), const Color(0xFFEEEEEE));
    });
  });

  group('CafeGuestSignInSheet review variants', () {
    test('each review action has its own title and reason', () {
      expect(
        CafeGuestSignInSheet.titleFor(CafeGuestAction.writeReview, ''),
        'Sign in to write a review',
      );
      expect(
        CafeGuestSignInSheet.messageFor(CafeGuestAction.writeReview),
        'Reviews are posted under your name. Signing in takes a minute.',
      );
      expect(
        CafeGuestSignInSheet.titleFor(CafeGuestAction.helpfulReview, ''),
        'Sign in to mark reviews helpful',
      );
      expect(
        CafeGuestSignInSheet.messageFor(CafeGuestAction.helpfulReview),
        'Helpful votes are tied to your account so each person counts once.',
      );
      expect(
        CafeGuestSignInSheet.titleFor(CafeGuestAction.reportReview, ''),
        'Sign in to report a review',
      );
      final icons = {
        for (final action in [
          CafeGuestAction.been,
          CafeGuestAction.writeReview,
          CafeGuestAction.reportReview,
          CafeGuestAction.helpfulReview,
        ])
          CafeGuestSignInSheet.iconFor(action),
      };
      expect(icons, hasLength(4));
    });
  });
}
