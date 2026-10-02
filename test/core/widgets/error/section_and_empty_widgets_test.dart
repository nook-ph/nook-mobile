import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/core/utils/error_info.dart';
import 'package:nook/core/widgets/error/full_page_empty_widget.dart';
import 'package:nook/core/widgets/error/section_empty_widget.dart';
import 'package:nook/core/widgets/error/section_error_widget.dart';

void main() {
  Future<void> pump(WidgetTester tester, Widget child) {
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Padding(padding: const EdgeInsets.all(20), child: child),
        ),
      ),
    );
  }

  const serverError = ErrorInfo(
    type: ErrorType.serverError,
    title: 'Something went wrong',
    subtitle: 'Try again in a moment',
  );

  BoxDecoration blockDecoration(WidgetTester tester, Type type) {
    final container = tester.widget<Container>(
      find.descendant(of: find.byType(type), matching: find.byType(Container)),
    );
    return container.decoration! as BoxDecoration;
  }

  group('SectionErrorWidget', () {
    testWidgets('is a tinted row with the action on the right', (tester) async {
      var retries = 0;
      await pump(
        tester,
        SectionErrorWidget(error: serverError, onRetry: () => retries++),
      );

      final decoration = blockDecoration(tester, SectionErrorWidget);
      expect(decoration.color, const Color(0xFFEEEEEE));
      expect(decoration.borderRadius, BorderRadius.circular(12));
      expect(find.byType(Icon), findsNothing);

      final title = tester.widget<Text>(find.text('Something went wrong'));
      expect(title.style!.fontSize, 14);
      expect(title.style!.fontWeight, FontWeight.w500);
      final subtitle = tester.widget<Text>(find.text('Try again in a moment'));
      expect(subtitle.style!.fontSize, 12);
      expect(subtitle.style!.color, const Color(0xFF868584));

      final action = tester.widget<Text>(find.text('Try again'));
      expect(action.style!.fontSize, 12);
      expect(action.style!.fontWeight, FontWeight.w600);
      expect(action.style!.color, const Color(0xFF344E41));
      expect(
        tester.getTopLeft(find.text('Try again')).dx,
        greaterThan(tester.getTopRight(find.text('Something went wrong')).dx),
      );

      await tester.tap(find.text('Try again'));
      expect(retries, 1);
    });

    testWidgets('signed out asks to sign in', (tester) async {
      await pump(
        tester,
        SectionErrorWidget(
          error: const ErrorInfo(
            type: ErrorType.sessionExpired,
            title: "You've been signed out",
            subtitle: 'Sign in to continue',
          ),
          onRetry: () {},
        ),
      );
      expect(find.text('Sign in'), findsOneWidget);
    });

    testWidgets('has no action without onRetry', (tester) async {
      await pump(tester, const SectionErrorWidget(error: serverError));
      expect(find.text('Try again'), findsNothing);
    });

    testWidgets('long copy wraps in a narrow column', (tester) async {
      await pump(
        tester,
        SizedBox(
          width: 220,
          child: SectionErrorWidget(
            error: const ErrorInfo(
              type: ErrorType.offline,
              title: 'A title long enough that it has to wrap',
              subtitle: 'A subtitle long enough that it has to wrap as well',
            ),
            onRetry: () {},
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('SectionEmptyWidget', () {
    testWidgets('is a tinted, left aligned block with no icon', (tester) async {
      await pump(
        tester,
        const SectionEmptyWidget(
          title: 'No reviews yet',
          subtitle: 'Be the first to leave a review',
          icon: Icons.chat_bubble_outline,
        ),
      );

      final decoration = blockDecoration(tester, SectionEmptyWidget);
      expect(decoration.color, const Color(0xFFEEEEEE));
      expect(decoration.borderRadius, BorderRadius.circular(12));
      expect(find.byType(Icon), findsNothing);

      final title = tester.widget<Text>(find.text('No reviews yet'));
      expect(title.style!.fontSize, 14);
      expect(title.style!.fontWeight, FontWeight.w500);

      final block = tester.getTopLeft(find.byType(SectionEmptyWidget));
      final text = tester.getTopLeft(find.text('No reviews yet'));
      expect(text.dx - block.dx, 14);
      expect(text.dy - block.dy, 14);
    });
  });

  group('FullPageEmptyWidget', () {
    testWidgets('shows copy only when it has no action', (tester) async {
      await pump(
        tester,
        const FullPageEmptyWidget(
          title: 'Nothing here yet',
          subtitle: 'Cafes you save will show up on this page.',
          icon: Icons.inbox_outlined,
        ),
      );
      expect(find.byType(Icon), findsNothing);
      final title = tester.widget<Text>(find.text('Nothing here yet'));
      expect(title.style!.fontSize, 16);
      expect(title.style!.fontWeight, FontWeight.w600);
      final subtitle = tester.widget<Text>(
        find.text('Cafes you save will show up on this page.'),
      );
      expect(subtitle.style!.fontSize, 14);
      expect(find.byType(Container), findsNothing);
    });

    testWidgets('offers a filled pill action', (tester) async {
      var taps = 0;
      await pump(
        tester,
        FullPageEmptyWidget(
          title: 'Nothing here yet',
          subtitle: 'Cafes you save will show up on this page.',
          actionLabel: 'Find cafes',
          onAction: () => taps++,
        ),
      );
      final pill = find.ancestor(
        of: find.text('Find cafes'),
        matching: find.byType(Container),
      );
      expect(
        (tester.widget<Container>(pill).decoration! as BoxDecoration).color,
        const Color(0xFF344E41),
      );
      expect(tester.getSize(pill).height, 44);
      await tester.tap(find.text('Find cafes'));
      expect(taps, 1);
    });
  });
}
