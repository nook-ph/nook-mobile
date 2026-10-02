import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/core/cafe/domain/repositories/i_cafe_repository.dart';
import 'package:nook/core/cafe/domain/use_cases/add_cafe_to_list_usecase.dart';
import 'package:nook/core/cafe/domain/use_cases/create_list_usecase.dart';
import 'package:nook/core/cafe/domain/use_cases/get_cafe_list_memberships_usecase.dart';
import 'package:nook/core/cafe/domain/use_cases/get_cafe_note_usecase.dart';
import 'package:nook/core/cafe/domain/use_cases/get_user_lists_usecase.dart';
import 'package:nook/core/cafe/domain/use_cases/remove_cafe_from_list_usecase.dart';
import 'package:nook/core/cafe/domain/use_cases/set_cafe_note_usecase.dart';
import 'package:nook/core/preferences/last_saved_list_store.dart';
import 'package:nook/features/cafe_details/presentation/widgets/cafe_note_sheet.dart';
import 'package:nook/features/lists/presentation/cubit/save_to_list_cubit.dart';
import 'package:nook/features/lists/presentation/widgets/save_to_list_bottom_sheet.dart';
import 'package:nook/features/lists/presentation/widgets/lists_ui.dart';
import 'package:nook/injection_container.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'lists_fixtures.dart';

class _NoRepository implements ICafeRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

/// The sheet only reads the cubit's state, so the states are fed in directly
/// and the calls it makes are recorded.
class _SaveCubit extends SaveToListCubit {
  _SaveCubit(ICafeRepository repo)
    : super(
        getUserListsUseCase: GetUserListsUseCase(repo),
        getCafeListMembershipsUseCase: GetCafeListMembershipsUseCase(repo),
        addCafeToListUseCase: AddCafeToListUseCase(repo),
        removeCafeFromListUseCase: RemoveCafeFromListUseCase(repo),
        createListUseCase: CreateListUseCase(repo),
        lastSavedListStore: LastSavedListStore(),
        currentUserId: () => 'user',
      );

  SaveToListState next = SaveToListLoading();
  int loads = 0;
  final toggled = <String>[];

  @override
  Future<void> load(String cafeId) async {
    loads++;
    emit(next);
  }

  @override
  Future<void> toggleList({
    required String cafeId,
    required String listId,
  }) async => toggled.add(listId);

  void show(SaveToListState state) => emit(state);
}

class _NoteRepository implements ICafeRepository {
  String? stored;
  bool failSave = false;
  bool failLoad = false;

  @override
  Future<String?> getCafeNote(String cafeId) async {
    if (failLoad) throw Exception('offline');
    return stored;
  }

  @override
  Future<String?> setCafeNote(String cafeId, String? note) async {
    if (failSave) throw const AuthException('expired');
    final trimmed = note?.trim() ?? '';
    return stored = trimmed.isEmpty ? null : trimmed;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

void main() {
  group('Save to list sheet', () {
    late _SaveCubit cubit;

    setUp(() => cubit = _SaveCubit(_NoRepository()));
    tearDown(() => cubit.close());

    Future<void> pump(WidgetTester tester, SaveToListState state) async {
      usePhone(tester);
      cubit.next = state;
      await tester.pumpWidget(
        BlocProvider<SaveToListCubit>.value(
          value: cubit,
          child: SheetOpener<void>(
            sheet: const SaveToListBottomSheet(cafeId: 'cafe'),
            onResult: (_) {},
          ),
        ),
      );
      await openSheet(tester);
    }

    SaveToListLoaded loaded({Set<String> saved = const {}}) => SaveToListLoaded(
      lists: [
        cafeList(id: 'fav', name: 'Favorites', isDefault: true),
        cafeList(id: 'study', name: 'Study spots'),
        cafeList(id: 'matcha', name: 'Best matcha', isPublic: true),
      ],
      savedListIds: saved,
      pendingListIds: const {},
    );

    testWidgets('loading shows four skeleton rows and no Done', (tester) async {
      await pump(tester, SaveToListLoading());

      expect(find.text('Save to…'), findsOneWidget);
      expect(find.byType(ListsSkeleton), findsNWidgets(12));
      expect(find.text('Done'), findsNothing);
      expect(pill(tester, 'New list').onTap, isNull);
    });

    testWidgets('rows are checkboxes; a tap saves at once; Done closes', (
      tester,
    ) async {
      await pump(tester, loaded(saved: {'fav'}));

      expect(find.text('Favorites'), findsOneWidget);
      expect(find.text('Private'), findsNWidgets(2));
      expect(find.text('Public'), findsOneWidget);

      final handle = tester.ensureSemantics();
      expect(
        tester.getSemantics(find.bySemanticsLabel('Favorites')),
        isSemantics(hasCheckedState: true, isChecked: true),
      );
      expect(
        tester.getSemantics(find.bySemanticsLabel('Study spots')),
        isSemantics(hasCheckedState: true, isChecked: false),
      );
      handle.dispose();

      await tester.tap(find.text('Study spots'));
      expect(cubit.toggled, ['study']);
      // Saving does not close the sheet.
      expect(find.text('Save to…'), findsOneWidget);

      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      expect(find.text('Save to…'), findsNothing);
    });

    testWidgets('a row with a write in flight ignores taps', (tester) async {
      await pump(
        tester,
        SaveToListLoaded(
          lists: [cafeList(id: 'study', name: 'Study spots')],
          savedListIds: const {},
          pendingListIds: const {'study'},
        ),
      );
      await tester.tap(find.text('Study spots'));
      expect(cubit.toggled, isEmpty);
    });

    testWidgets('no lists: one line and one New list button', (tester) async {
      await pump(
        tester,
        SaveToListLoaded(
          lists: const [],
          savedListIds: const {},
          pendingListIds: const {},
        ),
      );

      expect(
        find.text('Create a list to choose where this cafe should be saved.'),
        findsOneWidget,
      );
      expect(find.text('New list'), findsOneWidget);
      expect(find.text('Done'), findsNothing);

      await tester.tap(find.text('New list'));
      await tester.pumpAndSettle();
      // The create sheet opens over this one.
      expect(find.text('List name'), findsOneWidget);
    });

    testWidgets('an error keeps the app copy and retries the load', (
      tester,
    ) async {
      await pump(tester, SaveToListError(Exception('boom')));

      expect(find.text('Try again'), findsOneWidget);
      expect(find.text('Done'), findsNothing);
      final before = cubit.loads;
      cubit.next = loaded();
      await tester.tap(find.text('Try again'));
      await tester.pump();
      expect(cubit.loads, before + 1);
      expect(find.text('Favorites'), findsOneWidget);
    });
  });

  group('Note sheet', () {
    late _NoteRepository repo;

    setUp(() async {
      await sl.reset();
      repo = _NoteRepository();
      sl.registerSingleton(GetCafeNoteUseCase(repo));
      sl.registerSingleton(SetCafeNoteUseCase(repo));
    });

    tearDown(() => sl.reset());

    Future<void> pump(WidgetTester tester) async {
      usePhone(tester);
      await tester.pumpWidget(
        SheetOpener<void>(
          sheet: const CafeNoteSheet(cafeId: 'a', cafeName: 'Tadaima'),
          onResult: (_) {},
        ),
      );
      await openSheet(tester);
    }

    testWidgets('empty: the prompt, a zero count, and Save', (tester) async {
      await pump(tester);

      expect(find.text('Your note'), findsOneWidget);
      expect(find.text('Private to you · Tadaima'), findsOneWidget);
      expect(
        find.text('What do you want to remember about this place?'),
        findsOneWidget,
      );
      expect(find.text('0 / 500'), findsOneWidget);
      expect(pill(tester, 'Save note').onTap, isNotNull);
      expect(tester.takeException(), isNull);
    });

    testWidgets('prefills the saved note and counts as it is edited', (
      tester,
    ) async {
      repo.stored = 'Quiet upstairs.';
      await pump(tester);

      expect(find.text('Quiet upstairs.'), findsOneWidget);
      expect(find.text('15 / 500'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'x' * 600);
      await tester.pump();
      expect(find.text('500 / 500'), findsOneWidget);
    });

    testWidgets('saving stores the note and closes the sheet', (tester) async {
      await pump(tester);
      await tester.enterText(find.byType(TextField), 'Go before lunch.');
      await tester.pump();
      await tester.tap(find.text('Save note'));
      await tester.pumpAndSettle();

      expect(repo.stored, 'Go before lunch.');
      expect(find.text('Your note'), findsNothing);
    });

    testWidgets('a failed save keeps the sheet and what was typed', (
      tester,
    ) async {
      repo.failSave = true;
      await pump(tester);
      await tester.enterText(find.byType(TextField), 'Go before lunch.');
      await tester.pump();
      await tester.tap(find.text('Save note'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Your note'), findsOneWidget);
      expect(find.text('Go before lunch.'), findsOneWidget);
      expect(pill(tester, 'Save note').busy, isFalse);
      // Let the toast run out so no timer outlives the test.
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
    });

    testWidgets('a note that fails to load cannot be saved over', (
      tester,
    ) async {
      repo.stored = 'Quiet upstairs.';
      repo.failLoad = true;
      await pump(tester);

      // No editable empty field, no Save: only a way to read it again.
      expect(find.text('Couldn’t load your note.'), findsOneWidget);
      expect(find.text('Save note'), findsNothing);
      expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);

      repo.failLoad = false;
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();

      expect(find.text('Quiet upstairs.'), findsOneWidget);
      expect(pill(tester, 'Save note').onTap, isNotNull);
      expect(repo.stored, 'Quiet upstairs.');
    });

    testWidgets('a saved note is announced to whoever shows it', (
      tester,
    ) async {
      final before = cafeNoteChanges.value;
      await pump(tester);
      await tester.enterText(find.byType(TextField), 'Go before lunch.');
      await tester.pump();
      await tester.tap(find.text('Save note'));
      await tester.pumpAndSettle();

      expect(cafeNoteChanges.value, before + 1);
    });
  });
}
