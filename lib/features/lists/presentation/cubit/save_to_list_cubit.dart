import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nook/core/cafe/domain/entities/cafe_list.dart';
import 'package:nook/core/cafe/domain/use_cases/add_cafe_to_list_usecase.dart';
import 'package:nook/core/cafe/domain/use_cases/create_list_usecase.dart';
import 'package:nook/core/cafe/domain/use_cases/get_cafe_list_memberships_usecase.dart';
import 'package:nook/core/cafe/domain/use_cases/get_user_lists_usecase.dart';
import 'package:nook/core/cafe/domain/use_cases/remove_cafe_from_list_usecase.dart';
import 'package:nook/core/preferences/last_saved_list_store.dart';

typedef CurrentUserIdGetter = String? Function();

/// Default list (Favorites) first; remaining lists by "recency" descending:
/// [CafeList.lastSavedAt] when set, else [CafeList.updatedAt] (until DB has
/// `last_saved_at`).
List<CafeList> sortListsForSaveSheet(List<CafeList> lists) {
  final out = List<CafeList>.from(lists);
  DateTime sortKey(CafeList l) => l.lastSavedAt ?? l.updatedAt;

  out.sort((a, b) {
    if (a.isDefault != b.isDefault) {
      return a.isDefault ? -1 : 1;
    }
    final byTime = sortKey(b).compareTo(sortKey(a));
    if (byTime != 0) return byTime;
    return a.name.compareTo(b.name);
  });
  return out;
}

class SaveToListCubit extends Cubit<SaveToListState> {
  SaveToListCubit({
    required this.getUserListsUseCase,
    required this.getCafeListMembershipsUseCase,
    required this.addCafeToListUseCase,
    required this.removeCafeFromListUseCase,
    required this.createListUseCase,
    required this.lastSavedListStore,
    required this.currentUserId,
  }) : super(SaveToListInitial());

  final GetUserListsUseCase getUserListsUseCase;
  final GetCafeListMembershipsUseCase getCafeListMembershipsUseCase;
  final AddCafeToListUseCase addCafeToListUseCase;
  final RemoveCafeFromListUseCase removeCafeFromListUseCase;
  final CreateListUseCase createListUseCase;
  final LastSavedListStore lastSavedListStore;
  final CurrentUserIdGetter currentUserId;

  void acknowledgeListActionError() {
    final s = state;
    if (s is SaveToListLoaded && s.listActionError != null) {
      emit(s.copyWith(clearListActionError: true));
    }
  }

  Future<void> load(String cafeId) async {
    emit(SaveToListLoading());

    try {
      final lists = await _loadListsForPicker();
      final savedListIds = await getCafeListMembershipsUseCase(
        cafeId,
        lists.map((list) => list.id).toList(growable: false),
      );

      emit(
        SaveToListLoaded(
          lists: lists,
          savedListIds: savedListIds,
          pendingListIds: const {},
        ),
      );
    } catch (e) {
      emit(SaveToListError(e));
    }
  }

  Future<void> toggleList({
    required String cafeId,
    required String listId,
  }) async {
    final current = state;
    if (current is! SaveToListLoaded ||
        current.pendingListIds.contains(listId)) {
      return;
    }

    final wasSaved = current.savedListIds.contains(listId);
    final previousSavedListIds = current.savedListIds;
    final optimisticSavedListIds = Set<String>.from(current.savedListIds);
    if (wasSaved) {
      optimisticSavedListIds.remove(listId);
    } else {
      optimisticSavedListIds.add(listId);
    }

    emit(
      current.copyWith(
        savedListIds: optimisticSavedListIds,
        pendingListIds: {...current.pendingListIds, listId},
        clearListActionError: true,
      ),
    );

    try {
      if (wasSaved) {
        await removeCafeFromListUseCase(listId, cafeId);
      } else {
        await addCafeToListUseCase(listId, cafeId);
        await _persistLastSavedList(listId);
      }

      final refreshedLists = await _loadListsForPicker();
      final latest = state;
      if (latest is! SaveToListLoaded) return;
      final pending = Set<String>.from(latest.pendingListIds)..remove(listId);
      emit(
        latest.copyWith(
          lists: refreshedLists,
          pendingListIds: pending,
          refreshNonce: latest.refreshNonce + 1,
          clearListActionError: true,
        ),
      );
    } catch (e) {
      final latest = state;
      if (latest is! SaveToListLoaded) return;
      final pending = Set<String>.from(latest.pendingListIds)..remove(listId);
      emit(
        latest.copyWith(
          savedListIds: previousSavedListIds,
          pendingListIds: pending,
          listActionError: e,
        ),
      );
    }
  }

  Future<void> createListAndSave({
    required String cafeId,
    required String name,
    String? description,
  }) async {
    final current = state;
    if (current is! SaveToListLoaded || current.isCreating) return;

    emit(current.copyWith(isCreating: true, clearListActionError: true));

    try {
      final listId = await createListUseCase(
        name: name,
        description: description,
        isPublic: false,
      );
      await addCafeToListUseCase(listId, cafeId);

      await _persistLastSavedList(listId);

      final lists = await _loadListsForPicker();
      final savedListIds = Set<String>.from(current.savedListIds)..add(listId);

      emit(
        current.copyWith(
          lists: lists,
          savedListIds: savedListIds,
          isCreating: false,
          refreshNonce: current.refreshNonce + 1,
          clearListActionError: true,
        ),
      );
    } catch (e) {
      final latest = state;
      if (latest is! SaveToListLoaded) return;
      emit(latest.copyWith(isCreating: false, listActionError: e));
    }
  }

  /// Includes the default (Favorites) list so it matches the details-page bookmark.
  /// Excludes Been / Want to Try system lists — adding to those directly would
  /// bypass the mutual exclusion in `set_cafe_status`; they have their own
  /// control on the details page. Order: see [sortListsForSaveSheet].
  Future<List<CafeList>> _loadListsForPicker() async {
    final lists = await getUserListsUseCase();
    return sortListsForSaveSheet(
      lists.where((list) => !list.isSystem).toList(),
    );
  }

  Future<void> _persistLastSavedList(String listId) async {
    final uid = currentUserId();
    if (uid == null || uid.isEmpty) return;
    await lastSavedListStore.setLastSavedListId(uid, listId);
  }
}

abstract class SaveToListState {}

class SaveToListInitial extends SaveToListState {}

class SaveToListLoading extends SaveToListState {}

class SaveToListLoaded extends SaveToListState {
  SaveToListLoaded({
    required this.lists,
    required Set<String> savedListIds,
    required Set<String> pendingListIds,
    this.isCreating = false,
    this.listActionError,
    this.refreshNonce = 0,
  }) : savedListIds = Set.unmodifiable(savedListIds),
       pendingListIds = Set.unmodifiable(pendingListIds);

  final List<CafeList> lists;
  final Set<String> savedListIds;
  final Set<String> pendingListIds;
  final bool isCreating;
  final Object? listActionError;
  final int refreshNonce;

  SaveToListLoaded copyWith({
    List<CafeList>? lists,
    Set<String>? savedListIds,
    Set<String>? pendingListIds,
    bool? isCreating,
    Object? listActionError,
    bool clearListActionError = false,
    int? refreshNonce,
  }) {
    return SaveToListLoaded(
      lists: lists ?? this.lists,
      savedListIds: savedListIds ?? this.savedListIds,
      pendingListIds: pendingListIds ?? this.pendingListIds,
      isCreating: isCreating ?? this.isCreating,
      listActionError: clearListActionError
          ? null
          : listActionError ?? this.listActionError,
      refreshNonce: refreshNonce ?? this.refreshNonce,
    );
  }
}

class SaveToListError extends SaveToListState {
  SaveToListError(this.error);

  final Object error;
}
