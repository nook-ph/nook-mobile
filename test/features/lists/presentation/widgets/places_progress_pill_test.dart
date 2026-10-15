import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:nook/core/cafe/domain/places_progress.dart';
import 'package:nook/features/home_page/presentation/widgets/home_card_section.dart';
import 'package:nook/features/lists/presentation/widgets/places_progress_pill.dart';
import 'package:nook/utils/theme/theme.dart';

void main() {
  Future<void> pump(WidgetTester tester, Widget child, {double scale = 1}) {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    return tester.pumpWidget(
      MaterialApp(
        theme: TAppTheme.lightTheme,
        home: MediaQuery(
          data: MediaQueryData(
            size: const Size(360, 800),
            textScaler: TextScaler.linear(scale),
          ),
          child: Scaffold(
            body: Padding(padding: const EdgeInsets.all(20), child: child),
          ),
        ),
      ),
    );
  }

  testWidgets('nothing Been yet: a bookmark and what is left, no zero', (
    tester,
  ) async {
    await pump(
      tester,
      const PlacesProgressPill(progress: PlacesProgress(been: 0, wantToTry: 3)),
    );
    expect(find.text('3 to try'), findsOneWidget);
    expect(find.byIcon(LucideIcons.bookmark), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('some Been: a pie, not a spinner-shaped ring', (tester) async {
    await pump(
      tester,
      const PlacesProgressPill(progress: PlacesProgress(been: 1, wantToTry: 2)),
    );
    expect(find.text('1 been · 2 to try'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(
      find.descendant(
        of: find.byType(PlacesProgressPill),
        matching: find.byType(CustomPaint),
      ),
      findsWidgets,
    );
  });

  testWidgets('a button to Want to try while something is left', (
    tester,
  ) async {
    var taps = 0;
    await pump(
      tester,
      ListsTitleRow(
        title: 'Your lists',
        progress: const PlacesProgress(been: 1, wantToTry: 2),
        onProgressTap: () => taps++,
      ),
    );
    final button = find.bySemanticsLabel(
      '1 cafe been, 2 to try, open Want to try',
    );
    expect(button, findsOneWidget);
    expect(tester.getSize(button).height, greaterThanOrEqualTo(48));
    await tester.tap(button);
    expect(taps, 1);

    // Nothing left to try: nothing to open.
    await pump(
      tester,
      ListsTitleRow(
        title: 'Your lists',
        progress: const PlacesProgress(been: 3, wantToTry: 0),
        onProgressTap: () => taps++,
      ),
    );
    expect(find.text('All 3 been'), findsOneWidget);
    await tester.tap(find.text('All 3 been'));
    expect(taps, 1);
  });

  group('at text x2', () {
    for (final progress in const [
      PlacesProgress(been: 0, wantToTry: 3),
      PlacesProgress(been: 48, wantToTry: 132),
      PlacesProgress(been: 12, wantToTry: 0),
    ]) {
      testWidgets('the pill sits under the title: ${progress.label}', (
        tester,
      ) async {
        await pump(
          tester,
          ListsTitleRow(
            title: 'Your lists',
            progress: progress,
            onProgressTap: () {},
          ),
          scale: 2,
        );
        expect(tester.takeException(), isNull);
        final title = tester.getRect(find.text('Your lists'));
        final pill = tester.getRect(find.byType(PlacesProgressPill));
        expect(pill.top, greaterThanOrEqualTo(title.bottom));
        // The title gets the row's full width, not what the pill leaves.
        expect(
          tester.getSize(find.byType(ListsTitleRow)).width,
          tester.getRect(find.text('Your lists')).width,
        );
      });
    }

    testWidgets('the glyph grows with the text', (tester) async {
      await pump(
        tester,
        const PlacesProgressPill(
          progress: PlacesProgress(been: 1, wantToTry: 2),
        ),
        scale: 2,
      );
      final glyph = tester.getSize(
        find
            .descendant(
              of: find.byType(PlacesProgressPill),
              matching: find.byType(CustomPaint),
            )
            .last,
      );
      expect(glyph.width, closeTo(12 * 2 * 1.15, 0.01));
    });

    testWidgets('Home: Your places title and pill stack too', (tester) async {
      await pump(
        tester,
        const HomeSectionTitle(
          'Your places',
          trailing: PlacesProgressPill(
            progress: PlacesProgress(been: 48, wantToTry: 132),
          ),
        ),
        scale: 2,
      );
      expect(tester.takeException(), isNull);
      final title = tester.getRect(find.text('Your places'));
      final pill = tester.getRect(find.byType(PlacesProgressPill));
      expect(pill.top, greaterThanOrEqualTo(title.bottom));
    });
  });

  testWidgets('at text x1 the pill shares the title line', (tester) async {
    await pump(
      tester,
      ListsTitleRow(
        title: 'Your lists',
        progress: const PlacesProgress(been: 1, wantToTry: 2),
        onProgressTap: () {},
      ),
    );
    final title = tester.getRect(find.text('Your lists'));
    final pill = tester.getRect(find.byType(PlacesProgressPill));
    expect(pill.left, greaterThan(title.right));
    expect(pill.center.dy, closeTo(title.center.dy, 2));
  });
}
