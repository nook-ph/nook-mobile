import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
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
    on<RenameList>(_onRenameList);
    on<DeleteList>(_onDeleteList);
    on<AddCafeToList>(_onAddCafeToList);
    on<RemoveCafeFromList>(_onRemoveCafeFromList);
  }

  // ─── Handlers ────────────────────────────────────────────────────────────────

  Future<void> _onLoadUserLists(
    LoadUserLists event,
    Emitter<ListsState> emit,
  ) async {
    emit(ListsLoading());
    try {
      final results = await Future.wait([
        repository.getDefaultListId(),
        getUserListsUseCase(),
      ]);

      defaultListId = results[0] as String;
      final lists = (results[1] as List).cast<CafeList>();
      userLists = lists;

      emit(ListsLoaded(lists));
    } catch (e) {
      emit(ListsError(e));
    }
  }

  Future<void> _onLoadListCafes(
    LoadListCafes event,
    Emitter<ListsState> emit,
  ) async {
    emit(ListsLoading());
    try {
      final results = await Future.wait([
        getUserListsUseCase(),
        repository.getListCafes(event.listId),
      ]);

      final lists = (results[0] as List).cast<CafeList>();
      final cafes = results[1] as List;
      userLists = lists;

      final targetList = lists.firstWhere(
        (l) => l.id == event.listId,
        orElse: () => throw StateError('List ${event.listId} not found.'),
      );

      emit(ListCafesLoaded(targetList, cafes.cast()));
    } catch (e) {
      emit(ListsError(e));
    }
  }

  Future<void> _onCreateList(CreateList event, Emitter<ListsState> emit) async {
    try {
      debugPrint(
        '[ListsBloc] CreateList start '
        'nameLength=${event.name.trim().length} '
        'hasDescription=${event.description?.trim().isNotEmpty == true}',
      );
      final listId = await createListUseCase(
        name: event.name,
        description: event.description,
      );
      debugPrint('[ListsBloc] CreateList success listId=$listId');

      add(LoadUserLists());
    } catch (e, st) {
      debugPrint('[ListsBloc] CreateList failed error=$e');
      debugPrint('[ListsBloc] CreateList stackTrace=$st');
      emit(ListsError(e));
    }
  }

  Future<void> _onRenameList(RenameList event, Emitter<ListsState> emit) async {
    try {
      await repository.renameList(event.listId, event.name);
      unawaited(analytics.logEvent('list_renamed'));
      add(LoadUserLists());
    } catch (e, st) {
      debugPrint('[ListsBloc] RenameList failed error=$e stackTrace=$st');
      emit(ListsError(e));
    }
  }

  Future<void> _onDeleteList(DeleteList event, Emitter<ListsState> emit) async {
    try {
      await repository.deleteList(event.listId);
      unawaited(analytics.logEvent('list_deleted'));
      add(LoadUserLists());
    } catch (e, st) {
      debugPrint('[ListsBloc] DeleteList failed error=$e stackTrace=$st');
      emit(ListsError(e));
    }
  }

  Future<void> _onAddCafeToList(
    AddCafeToList event,
    Emitter<ListsState> emit,
  ) async {
    try {
      await addCafeToListUseCase(event.listId, event.cafeId);

      if (state is ListCafesLoaded) {
        final current = state as ListCafesLoaded;
        if (current.list.id == event.listId) {
          add(LoadListCafes(listId: event.listId));
        }
      }
    } catch (e) {
      emit(ListsError(e));
    }
  }

  Future<void> _onRemoveCafeFromList(
    RemoveCafeFromList event,
    Emitter<ListsState> emit,
  ) async {
    try {
      await removeCafeFromListUseCase(event.listId, event.cafeId);

      if (state is ListCafesLoaded) {
        final current = state as ListCafesLoaded;
        if (current.list.id == event.listId) {
          add(LoadListCafes(listId: event.listId));
        }
      }
    } catch (e) {
      emit(ListsError(e));
    }
  }
}
