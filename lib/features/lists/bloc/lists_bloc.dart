import 'package:flutter_bloc/flutter_bloc.dart';
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

  String? defaultListId;

  ListsBloc({
    required this.getUserListsUseCase,
    required this.addCafeToListUseCase,
    required this.removeCafeFromListUseCase,
    required this.createListUseCase,
    required this.repository,
  }) : super(ListsInitial()) {
    on<LoadUserLists>(_onLoadUserLists);
    on<LoadListCafes>(_onLoadListCafes);
    on<CreateList>(_onCreateList);
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
      final lists = results[1] as List;

      emit(ListsLoaded(lists.cast()));
    } catch (e) {
      emit(ListsError('Failed to load your lists. Please try again.'));
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

      final lists = results[0] as List;
      final cafes = results[1] as List;

      final targetList = lists.cast<dynamic>().firstWhere(
        (l) => l.id == event.listId,
        orElse: () => throw StateError('List ${event.listId} not found.'),
      );

      emit(ListCafesLoaded(targetList, cafes.cast()));
    } catch (e) {
      emit(ListsError('Failed to load cafes for this list. Please try again.'));
    }
  }

  Future<void> _onCreateList(CreateList event, Emitter<ListsState> emit) async {
    try {
      await createListUseCase(name: event.name, description: event.description);

      add(LoadUserLists());
    } catch (e) {
      emit(ListsError('Failed to create list. Please try again.'));
    }
  }

  Future<void> _onDeleteList(DeleteList event, Emitter<ListsState> emit) async {
    try {
      await repository.deleteList(event.listId);

      add(LoadUserLists());
    } catch (e) {
      emit(ListsError('Failed to delete list. Please try again.'));
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
      emit(ListsError('Failed to save cafe. Please try again.'));
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
      emit(ListsError('Failed to remove cafe. Please try again.'));
    }
  }
}
