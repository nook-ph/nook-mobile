import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/features/crawls/domain/use_cases/update_crawl_title_usecase.dart';
import 'package:nook/features/crawls/presentation/cubit/edit_crawl_title_cubit.dart';
import 'package:nook/features/crawls/presentation/widgets/crawl_ui.dart';
import 'package:nook/features/crawls/presentation/widgets/crawl_widgets.dart';
import 'package:nook/features/crawls/presentation/widgets/edit_crawl_title_sheet.dart';
import 'package:nook/utils/theme/theme.dart';

import 'crawl_fixtures.dart';

/// A title the content filter refuses (same term as content_filter_test).
const _blocked = 'retard crawl';

void main() {
  group('EditCrawlTitleCubit rules', () {
    test('check: length first, then the content filter', () {
      expect(EditCrawlTitleCubit.check('IT'), EditTitleProblem.length);
      expect(EditCrawlTitleCubit.check('   ab   '), EditTitleProblem.length);
      expect(EditCrawlTitleCubit.check('a' * 61), EditTitleProblem.length);
      expect(EditCrawlTitleCubit.check(_blocked), EditTitleProblem.rejected);
      expect(EditCrawlTitleCubit.check('IT Park Study Crawl'), isNull);
      expect(EditCrawlTitleCubit.check('a' * 60), isNull);
    });

    test('canSave: off until the title changes, and under 3 characters', () {
      const original = 'IT Park Study Crawl';
      expect(
        EditCrawlTitleCubit.canSave(original: original, current: original),
        isFalse,
      );
      expect(
        EditCrawlTitleCubit.canSave(original: original, current: ' $original '),
        isFalse,
      );
      expect(
        EditCrawlTitleCubit.canSave(original: original, current: 'IT'),
        isFalse,
      );
      expect(
        EditCrawlTitleCubit.canSave(original: original, current: ''),
        isFalse,
      );
      expect(
        EditCrawlTitleCubit.canSave(original: original, current: 'Lahug'),
        isTrue,
      );
      // The filter is reported on Save, so the button stays on.
      expect(
        EditCrawlTitleCubit.canSave(original: original, current: _blocked),
        isTrue,
      );
    });

    test('atLimit is true only at 60 characters', () {
      expect(EditCrawlTitleCubit.atLimit('a' * 59), isFalse);
      expect(EditCrawlTitleCubit.atLimit('a' * 60), isTrue);
    });

    test('a filtered title is refused without calling the server', () async {
      final repository = FakeCrawlRepository();
      final cubit = EditCrawlTitleCubit(
        updateCrawlTitleUseCase: UpdateCrawlTitleUseCase(repository),
      );
      addTearDown(cubit.close);

      await cubit.save('crawl-1', _blocked);

      expect(cubit.state.problem, EditTitleProblem.rejected);
      expect(cubit.state.saved, isNull);
      expect(repository.updatedTitle, isNull);
    });

    test('a clean title is sent trimmed', () async {
      final repository = FakeCrawlRepository();
      final cubit = EditCrawlTitleCubit(
        updateCrawlTitleUseCase: UpdateCrawlTitleUseCase(repository),
      );
      addTearDown(cubit.close);

      await cubit.save('crawl-1', '  Lahug Matcha Run ');

      expect(repository.updatedTitle, 'Lahug Matcha Run');
      expect(cubit.state.saved, isNotNull);
    });
  });

  group('CrawlTextField.counterText', () {
    test('has no spaces round the slash', () {
      expect(CrawlTextField.counterText(19, 60), '19/60');
    });
  });

  group('EditCrawlTitleSheet', () {
    late FakeCrawlRepository repository;

    Future<void> pump(WidgetTester tester) async {
      repository = FakeCrawlRepository();
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: TAppTheme.lightTheme,
          home: Scaffold(
            body: Align(
              alignment: Alignment.bottomCenter,
              child: BlocProvider(
                create: (_) => EditCrawlTitleCubit(
                  updateCrawlTitleUseCase: UpdateCrawlTitleUseCase(repository),
                ),
                child: EditCrawlTitleSheet(crawl: crawl()),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    bool saveEnabled(WidgetTester tester) =>
        tester
            .widget<CrawlPrimaryButton>(find.byType(CrawlPrimaryButton))
            .onTap !=
        null;

    testWidgets('opens with Save off, the helper line and an n/60 count', (
      tester,
    ) async {
      await pump(tester);

      final title = crawl().title;
      expect(find.text('${title.length}/60'), findsOneWidget);
      expect(
        find.text('3–60 characters. Stops and order cannot be changed.'),
        findsOneWidget,
      );
      expect(saveEnabled(tester), isFalse);
      expect(tester.takeException(), isNull);
    });

    testWidgets('under 3 characters says so and keeps Save off', (
      tester,
    ) async {
      await pump(tester);

      await tester.enterText(find.byType(TextField), 'IT');
      await tester.pump();

      expect(find.text('2/60'), findsOneWidget);
      expect(find.text('Title must be 3–60 characters.'), findsOneWidget);
      expect(saveEnabled(tester), isFalse);
    });

    testWidgets('at 60 the helper says it is the limit and Save stays on', (
      tester,
    ) async {
      await pump(tester);

      // The field itself stops at 60, so a longer paste is cut.
      await tester.enterText(find.byType(TextField), 'a' * 70);
      await tester.pump();

      expect(find.text('60/60'), findsOneWidget);
      expect(
        find.text(
          'That is the limit. The field stops taking characters at 60.',
        ),
        findsOneWidget,
      );
      expect(find.text('Title must be 3–60 characters.'), findsNothing);
      expect(saveEnabled(tester), isTrue);
      // Ink, not the error red, at the limit.
      final counter = tester.widget<Text>(find.text('60/60'));
      expect(counter.style?.color, const Color(0xFF0A0F0D));
      expect(tester.takeException(), isNull);
    });

    testWidgets('a filtered title shows the builder line under the field', (
      tester,
    ) async {
      await pump(tester);

      await tester.enterText(find.byType(TextField), _blocked);
      await tester.pump();
      expect(saveEnabled(tester), isTrue);

      await tester.tap(find.text('Save'));
      await tester.pump();

      expect(find.text('Please pick a different title.'), findsOneWidget);
      expect(repository.updatedTitle, isNull);

      // Typing again clears it.
      await tester.enterText(find.byType(TextField), 'Lahug Matcha Run');
      await tester.pump();
      expect(find.text('Please pick a different title.'), findsNothing);
    });
  });
}
