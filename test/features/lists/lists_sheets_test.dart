import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/features/lists/presentation/widgets/cafe_actions_bottom_sheet.dart';
import 'package:nook/features/lists/presentation/widgets/list_form_sheet.dart';
import 'package:nook/features/lists/presentation/widgets/list_options_bottom_sheet.dart';
import 'package:nook/features/lists/presentation/widgets/list_tokens.dart';
import 'package:nook/utils/theme/theme.dart';

import 'lists_fixtures.dart';

void main() {
  group('New list sheet', () {
    testWidgets('Create is dimmed until a name is typed', (tester) async {
      usePhone(tester);
      ListFormInput? result;
      await tester.pumpWidget(
        SheetOpener<ListFormInput>(
          sheet: const ListFormSheet(),
          onResult: (value) => result = value,
        ),
      );
      await openSheet(tester);

      expect(find.text('New list'), findsOneWidget);
      expect(find.text('0 / 50'), findsOneWidget);
      expect(pill(tester, 'Create').onTap, isNull);

      // Spaces alone are not a name.
      await tester.enterText(find.byType(TextField).first, '   ');
      await tester.pump();
      expect(pill(tester, 'Create').onTap, isNull);

      await tester.enterText(find.byType(TextField).first, ' Study spots ');
      await tester.enterText(find.byType(TextField).last, ' Quiet. ');
      await tester.pump();
      expect(pill(tester, 'Create').onTap, isNotNull);

      await tester.tap(find.text('Create'));
      await tester.pumpAndSettle();
      expect(result?.name, 'Study spots');
      expect(result?.description, 'Quiet.');
    });

    testWidgets('an empty description resolves as null', (tester) async {
      usePhone(tester);
      ListFormInput? result;
      await tester.pumpWidget(
        SheetOpener<ListFormInput>(
          sheet: const ListFormSheet(),
          onResult: (value) => result = value,
        ),
      );
      await openSheet(tester);
      await tester.enterText(find.byType(TextField).first, 'Matcha');
      await tester.pump();
      await tester.tap(find.text('Create'));
      await tester.pumpAndSettle();

      expect(result?.name, 'Matcha');
      expect(result?.description, isNull);
    });

    testWidgets('the name stops at 50 and the count turns red', (tester) async {
      usePhone(tester);
      await tester.pumpWidget(
        SheetOpener<ListFormInput>(
          sheet: const ListFormSheet(),
          onResult: (_) {},
        ),
      );
      await openSheet(tester);

      await tester.enterText(find.byType(TextField).first, 'a' * 44);
      await tester.pump();
      expect(
        tester.widget<Text>(find.text('44 / 50')).style?.color,
        ListsTokens.muted,
      );

      await tester.enterText(find.byType(TextField).first, 'a' * 60);
      await tester.pump();
      expect(
        tester.widget<Text>(find.text('50 / 50')).style?.color,
        ListsTokens.danger,
      );
      final field = tester.widget<TextField>(find.byType(TextField).first);
      expect(field.controller?.text.length, 50);
      // Still a valid name: Create stays usable at the limit.
      expect(pill(tester, 'Create').onTap, isNotNull);
    });

    testWidgets('closing resolves null', (tester) async {
      usePhone(tester);
      ListFormInput? result = const ListFormInput(name: 'unset');
      await tester.pumpWidget(
        SheetOpener<ListFormInput>(
          sheet: const ListFormSheet(),
          onResult: (value) => result = value,
        ),
      );
      await openSheet(tester);
      await tester.tap(find.bySemanticsLabel('Close'));
      await tester.pumpAndSettle();
      expect(result, isNull);
    });
  });

  group('Edit list sheet', () {
    testWidgets('prefills, and Save waits for a change', (tester) async {
      usePhone(tester);
      ListFormInput? result;
      await tester.pumpWidget(
        SheetOpener<ListFormInput>(
          sheet: const ListFormSheet(
            initialName: 'Study spots',
            initialDescription: 'Quiet, outlets.',
          ),
          onResult: (value) => result = value,
        ),
      );
      await openSheet(tester);

      expect(find.text('Edit list'), findsOneWidget);
      expect(find.text('11 / 50'), findsOneWidget);
      expect(find.text('Quiet, outlets.'), findsOneWidget);
      expect(pill(tester, 'Save').onTap, isNull);

      // Clearing the name is not a savable change.
      await tester.enterText(find.byType(TextField).first, '');
      await tester.pump();
      expect(pill(tester, 'Save').onTap, isNull);

      await tester.enterText(find.byType(TextField).first, 'Thesis spots');
      await tester.pump();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(result?.name, 'Thesis spots');
      expect(result?.description, 'Quiet, outlets.');
    });
  });

  group('Delete list dialog', () {
    Future<bool?> ask(WidgetTester tester, String button) async {
      bool? result;
      await tester.pumpWidget(
        MaterialApp(
          theme: TAppTheme.lightTheme,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async => result = await showDeleteListConfirm(
                  context,
                  listName: 'Study spots',
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('Delete list?'), findsOneWidget);
      expect(
        find.text(
          '"Study spots" will be permanently deleted. '
          "Cafes won't be deleted.",
        ),
        findsOneWidget,
      );
      await tester.tap(find.text(button));
      await tester.pumpAndSettle();
      return result;
    }

    testWidgets('Delete confirms', (tester) async {
      usePhone(tester);
      expect(await ask(tester, 'Delete'), isTrue);
    });

    testWidgets('Cancel does not', (tester) async {
      usePhone(tester);
      expect(await ask(tester, 'Cancel'), isFalse);
    });
  });

  group('List options sheet', () {
    testWidgets('says what each row does and runs it after closing', (
      tester,
    ) async {
      usePhone(tester);
      final taps = <String>[];
      await tester.pumpWidget(
        SheetOpener<void>(
          sheet: ListOptionsBottomSheet(
            listId: 'l1',
            listName: 'Study spots',
            onMakeCrawl: () => taps.add('crawl'),
            onEdit: () => taps.add('edit'),
            onDelete: () => taps.add('delete'),
          ),
          onResult: (_) {},
        ),
      );
      await openSheet(tester);

      expect(find.text('Study spots'), findsOneWidget);
      expect(find.text('Turn into a crawl'), findsOneWidget);
      expect(find.text('Name and description'), findsOneWidget);
      expect(find.text('Cafes are not deleted'), findsOneWidget);
      expect(
        tester.widget<Text>(find.text('Delete')).style?.color,
        ListsTokens.danger,
      );

      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();
      expect(taps, ['edit']);
      expect(find.text('Name and description'), findsNothing);
    });

    testWidgets('a system list only offers the crawl', (tester) async {
      usePhone(tester);
      await tester.pumpWidget(
        SheetOpener<void>(
          sheet: ListOptionsBottomSheet(
            listId: 'been',
            listName: 'Been',
            onMakeCrawl: () {},
          ),
          onResult: (_) {},
        ),
      );
      await openSheet(tester);

      expect(find.text('Turn into a crawl'), findsOneWidget);
      expect(find.text('Edit'), findsNothing);
      expect(find.text('Delete'), findsNothing);
    });
  });

  group('Cafe actions sheet', () {
    testWidgets('names the list the cafe leaves', (tester) async {
      usePhone(tester);
      final taps = <String>[];
      await tester.pumpWidget(
        SheetOpener<void>(
          sheet: CafeActionsBottomSheet(
            cafeName: 'Coffee Bear',
            listName: 'Study spots',
            onViewDetails: () => taps.add('view'),
            onRemove: () => taps.add('remove'),
          ),
          onResult: (_) {},
        ),
      );
      await openSheet(tester);

      expect(find.text('Coffee Bear'), findsOneWidget);
      expect(find.text('View details'), findsOneWidget);
      expect(find.text('Only removes it from Study spots'), findsOneWidget);
      expect(
        tester.widget<Text>(find.text('Remove from list')).style?.color,
        ListsTokens.danger,
      );

      await tester.tap(find.text('Remove from list'));
      await tester.pumpAndSettle();
      expect(taps, ['remove']);
    });
  });
}
