import 'package:flutter/foundation.dart';
import 'package:nook/core/cafe/domain/cafe_list_display_title.dart';
import 'package:nook/core/cafe/domain/repositories/i_cafe_repository.dart';
import 'package:nook/core/cafe/domain/use_cases/create_list_usecase.dart';
import 'package:nook/core/preferences/last_saved_list_store.dart';

/// Resolves which list the app-bar bookmark should add to: last list the user
/// saved a café into (if still valid), else server default, else create "Favorites".
class ResolveQuickSaveListUseCase {
  ResolveQuickSaveListUseCase({
    required this.repository,
    required this.lastSavedListStore,
    required this.createListUseCase,
  });

  final ICafeRepository repository;
  final LastSavedListStore lastSavedListStore;
  final CreateListUseCase createListUseCase;

  Future<ResolvedQuickSaveList> call(String userId) async {
    debugPrint('[ResolveQuickSave] start userId=$userId');
    final lists = await repository.getUserLists();
    debugPrint(
      '[ResolveQuickSave] getUserLists count=${lists.length} '
      'ids=${lists.map((l) => l.id).join(",")}',
    );
    final stored = await lastSavedListStore.getLastSavedListId(userId);
    debugPrint('[ResolveQuickSave] prefs last_saved_list_id=$stored');
    if (stored != null) {
      for (final list in lists) {
        if (list.id == stored) {
          debugPrint('[ResolveQuickSave] branch: matched stored prefs list');
          return ResolvedQuickSaveList(
            listId: stored,
            displayTitle: cafeListDisplayTitle(list),
          );
        }
      }
      debugPrint('[ResolveQuickSave] stored id not in user lists, fall through');
    }

    try {
      final defaultId = await repository.getDefaultListId();
      debugPrint('[ResolveQuickSave] getDefaultListId=$defaultId');
      for (final list in lists) {
        if (list.id == defaultId) {
          debugPrint('[ResolveQuickSave] branch: matched default in list rows');
          return ResolvedQuickSaveList(
            listId: defaultId,
            displayTitle: cafeListDisplayTitle(list),
          );
        }
      }
      debugPrint('[ResolveQuickSave] branch: default id not in rows, use id only');
      return ResolvedQuickSaveList(listId: defaultId, displayTitle: 'Favorites');
    } catch (e, st) {
      debugPrint('[ResolveQuickSave] getDefaultListId failed: $e');
      debugPrint('$st');
      debugPrint('[ResolveQuickSave] branch: create Favorites fallback');
      final newId = await createListUseCase(name: 'Favorites');
      debugPrint('[ResolveQuickSave] created list id=$newId');
      final refreshed = await repository.getUserLists();
      for (final list in refreshed) {
        if (list.id == newId) {
          return ResolvedQuickSaveList(
            listId: newId,
            displayTitle: cafeListDisplayTitle(list),
          );
        }
      }
      return ResolvedQuickSaveList(listId: newId, displayTitle: 'Favorites');
    }
  }
}

class ResolvedQuickSaveList {
  const ResolvedQuickSaveList({
    required this.listId,
    required this.displayTitle,
  });

  final String listId;
  final String displayTitle;
}
