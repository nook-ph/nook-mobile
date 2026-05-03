import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:nook/core/cafe/domain/entities/cafe_bundle.dart';
import 'package:nook/core/cafe/domain/entities/cafe_details.dart';
import 'package:nook/core/cafe/domain/entities/cafe_list.dart';
import 'package:nook/core/cafe/domain/entities/cafe_query.dart';
import 'package:nook/core/cafe/domain/entities/cafe_summary.dart';
import 'package:nook/core/cafe/domain/repositories/i_cafe_repository.dart';
import 'package:nook/core/cafe/domain/use_cases/add_cafe_to_list_usecase.dart';
import 'package:nook/core/cafe/domain/use_cases/create_list_usecase.dart';
import 'package:nook/core/cafe/domain/use_cases/get_cafe_list_memberships_usecase.dart';
import 'package:nook/core/cafe/domain/use_cases/get_user_lists_usecase.dart';
import 'package:nook/core/cafe/domain/use_cases/remove_cafe_from_list_usecase.dart';
import 'package:nook/core/preferences/last_saved_list_store.dart';
import 'package:nook/features/lists/presentation/cubit/save_to_list_cubit.dart';

void main() {
  group('SaveToListCubit', () {
    test('loads regular lists with saved memberships', () async {
      final repository = _FakeCafeRepository(
        lists: [_defaultList(), _list(id: 'list-1')],
        memberships: {'list-1'},
      );
      final cubit = _buildCubit(repository);

      await cubit.load('cafe-1');

      final state = cubit.state as SaveToListLoaded;
      expect(state.lists.map((list) => list.id), ['favorites', 'list-1']);
      expect(state.savedListIds, {'list-1'});
      expect(state.pendingListIds, isEmpty);
    });

    test('optimistically adds cafe to a list', () async {
      final repository = _FakeCafeRepository(lists: [_list(id: 'list-1')]);
      final cubit = _buildCubit(repository);
      await cubit.load('cafe-1');

      repository.addCompleter = Completer<void>();
      final toggleFuture = cubit.toggleList(cafeId: 'cafe-1', listId: 'list-1');
      await pumpEventQueue();

      var state = cubit.state as SaveToListLoaded;
      expect(state.savedListIds, contains('list-1'));
      expect(state.pendingListIds, contains('list-1'));

      repository.addCompleter!.complete();
      await toggleFuture;

      state = cubit.state as SaveToListLoaded;
      expect(state.savedListIds, contains('list-1'));
      expect(state.pendingListIds, isEmpty);
      expect(state.refreshNonce, 1);
    });

    test('rolls back optimistic add when persistence fails', () async {
      final repository = _FakeCafeRepository(
        lists: [_list(id: 'list-1')],
        failNextAdd: true,
      );
      final cubit = _buildCubit(repository);
      await cubit.load('cafe-1');

      await cubit.toggleList(cafeId: 'cafe-1', listId: 'list-1');

      final state = cubit.state as SaveToListLoaded;
      expect(state.savedListIds, isNot(contains('list-1')));
      expect(state.pendingListIds, isEmpty);
      expect(state.errorMessage, 'Unable to save this cafe to the list.');
    });

    test('persists last saved list id after successful add toggle', () async {
      final store = _RecordingLastSavedListStore();
      final repository = _FakeCafeRepository(lists: [_list(id: 'list-1')]);
      final cubit = _buildCubit(
        repository,
        lastSavedListStore: store,
        currentUserId: () => 'user-1',
      );
      await cubit.load('cafe-1');

      await cubit.toggleList(cafeId: 'cafe-1', listId: 'list-1');

      expect(store.recordedUserId, 'user-1');
      expect(store.recordedListId, 'list-1');
    });

    test('does not persist last saved list when removing cafe from list', () async {
      final store = _RecordingLastSavedListStore();
      final repository = _FakeCafeRepository(
        lists: [_list(id: 'list-1')],
        memberships: {'list-1'},
      );
      final cubit = _buildCubit(
        repository,
        lastSavedListStore: store,
        currentUserId: () => 'user-1',
      );
      await cubit.load('cafe-1');

      await cubit.toggleList(cafeId: 'cafe-1', listId: 'list-1');

      expect(store.recordedUserId, isNull);
      expect(store.recordedListId, isNull);
    });

    test('persists last saved list id after createListAndSave', () async {
      final store = _RecordingLastSavedListStore();
      final repository = _FakeCafeRepository(lists: [_list(id: 'list-1')]);
      final cubit = _buildCubit(
        repository,
        lastSavedListStore: store,
        currentUserId: () => 'user-1',
      );
      await cubit.load('cafe-1');

      await cubit.createListAndSave(cafeId: 'cafe-1', name: 'Weekend Cafes');

      expect(store.recordedUserId, 'user-1');
      expect(store.recordedListId, 'created-list');
    });

    test('creates a list and saves the cafe into it', () async {
      final repository = _FakeCafeRepository(lists: [_list(id: 'list-1')]);
      final cubit = _buildCubit(repository);
      await cubit.load('cafe-1');

      await cubit.createListAndSave(cafeId: 'cafe-1', name: 'Weekend Cafes');

      final state = cubit.state as SaveToListLoaded;
      expect(state.lists.map((list) => list.id), contains('created-list'));
      expect(state.savedListIds, contains('created-list'));
      expect(state.isCreating, isFalse);
      expect(state.refreshNonce, 1);
    });

    test(
      'sortListsForSaveSheet pins default first; rest by lastSavedAt else updatedAt desc',
      () {
      final favorites = _list(
        id: 'fav',
        isDefault: true,
        lastSavedAt: DateTime(2000),
      );
      final old = _list(id: 'old', lastSavedAt: DateTime(2020));
      final recent = _list(id: 'recent', lastSavedAt: DateTime(2025));
      final unset = _list(
        id: 'unset',
        lastSavedAt: null,
        updatedAt: DateTime(2010),
      );
      final sorted = sortListsForSaveSheet([old, recent, favorites, unset]);
      expect(sorted.map((l) => l.id), ['fav', 'recent', 'old', 'unset']);
    },
    );
  });
}

SaveToListCubit _buildCubit(
  _FakeCafeRepository repository, {
  LastSavedListStore? lastSavedListStore,
  CurrentUserIdGetter? currentUserId,
}) {
  return SaveToListCubit(
    getUserListsUseCase: GetUserListsUseCase(repository),
    getCafeListMembershipsUseCase: GetCafeListMembershipsUseCase(repository),
    addCafeToListUseCase: AddCafeToListUseCase(repository),
    removeCafeFromListUseCase: RemoveCafeFromListUseCase(repository),
    createListUseCase: CreateListUseCase(repository),
    lastSavedListStore: lastSavedListStore ?? _NoopLastSavedListStore(),
    currentUserId: currentUserId ?? () => null,
  );
}

/// Does not touch SharedPreferences in tests.
class _NoopLastSavedListStore extends LastSavedListStore {
  @override
  Future<void> setLastSavedListId(String userId, String listId) async {}
}

class _RecordingLastSavedListStore extends LastSavedListStore {
  String? recordedUserId;
  String? recordedListId;

  @override
  Future<void> setLastSavedListId(String userId, String listId) async {
    recordedUserId = userId;
    recordedListId = listId;
  }
}

CafeList _defaultList() => _list(id: 'favorites', isDefault: true);

CafeList _list({
  required String id,
  bool isDefault = false,
  DateTime? lastSavedAt,
  DateTime? updatedAt,
}) {
  return CafeList(
    id: id,
    name: id,
    description: null,
    coverImageUrl: null,
    isDefault: isDefault,
    isPublic: false,
    cafeCount: 0,
    createdAt: DateTime(2024),
    updatedAt: updatedAt ?? DateTime(2024),
    lastSavedAt: lastSavedAt,
  );
}

class _FakeCafeRepository implements ICafeRepository {
  _FakeCafeRepository({
    required this.lists,
    Set<String> memberships = const {},
    this.failNextAdd = false,
    this.failNextRemove = false,
  }) : memberships = Set<String>.from(memberships);

  final List<CafeList> lists;
  final Set<String> memberships;
  bool failNextAdd;
  bool failNextRemove;
  Completer<void>? addCompleter;

  @override
  Future<bool> isCafeSavedToAnyUserList(String cafeId) async {
    final memberships = await getCafeListMemberships(
      cafeId,
      lists.map((list) => list.id).toList(growable: false),
    );
    return memberships.isNotEmpty;
  }

  @override
  Future<void> removeCafeFromAllUserLists(String cafeId) async {
    memberships.clear();
  }

  @override
  Future<void> addCafeToList(String listId, String cafeId) async {
    if (failNextAdd) {
      failNextAdd = false;
      throw StateError('add failed');
    }
    await addCompleter?.future;
    memberships.add(listId);
  }

  @override
  Future<String> createList({required String name, String? description}) async {
    const listId = 'created-list';
    lists.add(_list(id: listId));
    return listId;
  }

  @override
  Future<Set<String>> getCafeListMemberships(
    String cafeId,
    List<String> listIds,
  ) async {
    return memberships.intersection(listIds.toSet());
  }

  @override
  Future<List<CafeList>> getUserLists() async => lists;

  @override
  Future<void> removeCafeFromList(String listId, String cafeId) async {
    if (failNextRemove) {
      failNextRemove = false;
      throw StateError('remove failed');
    }
    memberships.remove(listId);
  }

  @override
  Future<Review> addCafeReview({
    required String cafeId,
    required String userId,
    required int rating,
    required String content,
    List<String> imageUrls = const [],
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> deleteList(String listId) {
    throw UnimplementedError();
  }

  @override
  Future<CafeBundle> getCafeBundleById(
    String cafeId, {
    bool includeMenu = true,
    bool includeReviews = true,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<CafeDetails> getCafeDetailsById(String cafeId) {
    throw UnimplementedError();
  }

  @override
  Future<List<Review>> getCafeReviewsById(
    String cafeId, {
    String sort = 'recommended',
    int? ratingFilter,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<List<CafeSummary>> getCafes(CafeQuery query) {
    throw UnimplementedError();
  }

  @override
  Future<String> getDefaultListId() {
    throw UnimplementedError();
  }

  @override
  Future<List<CafeSummary>> getListCafes(String listId) {
    throw UnimplementedError();
  }

  @override
  Future<bool> isCafeInList(String listId, String cafeId) {
    throw UnimplementedError();
  }

  @override
  Future<void> renameList(String listId, String name) {
    throw UnimplementedError();
  }

  @override
  Future<void> toggleHelpfulVote(
    String reviewId,
    String userId,
    bool currentlyVoted,
  ) {
    throw UnimplementedError();
  }

  @override
  Future<void> warmCache(List<CafeSummary> summaries) {
    throw UnimplementedError();
  }
}
