import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nook/core/cafe/domain/entities/cafe_summary.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:nook/core/analytics/analytics_service.dart';
import 'package:nook/core/cafe/domain/entities/cafe_list.dart';
import 'package:nook/core/cafe/domain/use_cases/add_cafe_to_list_usecase.dart';
import 'package:nook/core/cafe/domain/use_cases/create_list_usecase.dart';
import 'package:nook/core/cafe/domain/use_cases/get_user_lists_usecase.dart';
import 'package:nook/core/cafe/domain/use_cases/remove_cafe_from_list_usecase.dart';
import 'package:nook/core/cafe/domain/repositories/i_cafe_repository.dart';
import 'package:nook/features/lists/bloc/lists_event.dart';
import 'package:nook/features/lists/bloc/lists_state.dart';

class ListsBloc extends Bloc<ListsEvent, ListsState> {
  final GetUserListsUseCase getUserListsUseCase;
  final AddCafeToListUseCase addCafeToListUseCase;
  final RemoveCafeFromListUseCase removeCafeFromListUseCase;
  final CreateListUseCase createListUseCase;
  final ICafeRepository repository;
  final AnalyticsService analytics;

  String? defaultListId;
  List<CafeList> userLists = const [];

  /// list id → up to three cafe images, for the Lists index preview strip.
  /// Read alongside [userLists]; refreshed by every [LoadUserLists].
  Map<String, List<String>> listPreviews = const {};

  ListsBloc({
    required this.getUserListsUseCase,
    required this.addCafeToListUseCase,
    required this.removeCafeFromListUseCase,
    required this.createListUseCase,
    required this.repository,
    required this.analytics,
  }) : super(ListsInitial()) {
    on<LoadUserLists>(_onLoadUserLists);
    on<LoadListCafes>(_onLoadListCafes);
    on<CreateList>(_onCreateList);
    on<UpdateList>(_onUpdateList);
    on<DeleteList>(_onDeleteList);
    on<AddCafeToList>(_onAddCafeToList);
    on<RemoveCafeFromList>(_onRemoveCafeFromList);
  }

  bool get _isAuthenticated =>
      Supabase.instance.client.auth.currentSession != null;

  /// Previews are decoration. A failure here must not take the Lists page down
  /// with it — the last good set is kept and the cards fall back to text.
  Future<Map<String, List<String>>> _loadPreviews(List<CafeList> lists) async {
    final withCafes = [
      for (final list in lists)
        if (list.cafeCount > 0) list.id,
    ];
    if (withCafes.isEmpty) return const {};

    try {
      return await repository.getListPreviewImages(withCafes);
    } catch (e, st) {
      debugPrint('ListsBloc._loadPreviews error: $e\n$st');
      return listPreviews;
    }
  }

  Future<void> _onLoadUserLists(
    LoadUserLists event,
    Emitter<ListsState> emit,
  ) async {
    if (!_isAuthenticated) return;

    emit(ListsLoading());
    try {
      final results = await Future.wait([
        repository.getDefaultListId(),
        getUserListsUseCase(),
      ]);

      defaultListId = results[0] as String?;
      final lists = (results[1] as List).cast<CafeList>();
      userLists = lists;
      listPreviews = await _loadPreviews(lists);

      emit(ListsLoaded(lists));
    } catch (e, st) {
      debugPrint('ListsBloc._onLoadUserLists error: $e\n$st');
      emit(ListsError(e));
    }
  }

  Future<void> _onLoadListCafes(
    LoadListCafes event,
    Emitter<ListsState> emit,
  ) async {
    if (!_isAuthenticated) return;

    emit(ListsLoading());
    try {
      final results = await Future.wait([
        getUserListsUseCase(),
        repository.getListCafes(event.listId),
      ]);

      final lists = (results[0] as List).cast<CafeList>();
      final cafes = (results[1] as List).cast<CafeSummary>();
      userLists = lists;

      final targetList = lists.firstWhere(
        (l) => l.id == event.listId,
        orElse: () => throw StateError('List ${event.listId} not found.'),
      );

      emit(ListCafesLoaded(targetList, cafes));
    } catch (e, st) {
      debugPrint('ListsBloc._onLoadListCafes error: $e\n$st');
      emit(ListsError(e));
    }
  }

  Future<void> _onCreateList(CreateList event, Emitter<ListsState> emit) async {
    if (!_isAuthenticated) return;

    try {
      await createListUseCase(
        name: event.name,
        description: event.description,
        isPublic: event.isPublic,
      );
      add(LoadUserLists());
    } catch (e, st) {
      debugPrint('ListsBloc._onCreateList error: $e\n$st');
      emit(ListsError(e));
    }
  }

  Future<void> _onUpdateList(UpdateList event, Emitter<ListsState> emit) async {
    if (!_isAuthenticated) return;

    try {
      await repository.updateList(
        event.listId,
        name: event.name,
        description: event.description,
        isPublic: event.isPublic,
      );
      unawaited(analytics.logEvent('list_updated'));
      add(LoadUserLists());
    } catch (e, st) {
      debugPrint('ListsBloc._onUpdateList error: $e\n$st');
      emit(ListsError(e));
    }
  }

  Future<void> _onDeleteList(DeleteList event, Emitter<ListsState> emit) async {
    if (!_isAuthenticated) return;

    try {
      await repository.deleteList(event.listId);
      unawaited(analytics.logEvent('list_deleted'));
      add(LoadUserLists());
    } catch (e, st) {
      debugPrint('ListsBloc._onDeleteList error: $e\n$st');
      emit(ListsError(e));
    }
  }

  Future<void> _onAddCafeToList(
    AddCafeToList event,
    Emitter<ListsState> emit,
  ) async {
    if (!_isAuthenticated) return;

    try {
      await addCafeToListUseCase(event.listId, event.cafeId);
      if (state is ListCafesLoaded &&
          (state as ListCafesLoaded).list.id == event.listId) {
        add(LoadListCafes(listId: event.listId));
      }
    } catch (e, st) {
      debugPrint('ListsBloc._onAddCafeToList error: $e\n$st');
      emit(ListsError(e));
    }
  }

  Future<void> _onRemoveCafeFromList(
    RemoveCafeFromList event,
    Emitter<ListsState> emit,
  ) async {
    if (!_isAuthenticated) return;

    try {
      await removeCafeFromListUseCase(event.listId, event.cafeId);
      if (state is ListCafesLoaded &&
          (state as ListCafesLoaded).list.id == event.listId) {
        add(LoadListCafes(listId: event.listId));
      }
    } catch (e, st) {
      debugPrint('ListsBloc._onRemoveCafeFromList error: $e\n$st');
      emit(ListsError(e));
    }
  }
}
