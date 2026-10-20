import 'dart:async';

abstract class ListsEvent {}

class LoadUserLists extends ListsEvent {}

class CreateList extends ListsEvent {
  final String name;
  final String? description;
  final bool isPublic;

  /// Completes once the list is in, or with the error that stopped it.
  final Completer<void>? done;

  CreateList({
    required this.name,
    this.description,
    required this.isPublic,
    this.done,
  });
}

class RenameList extends ListsEvent {
  final String listId;
  final String name;

  RenameList({required this.listId, required this.name});
}

class DeleteList extends ListsEvent {
  final String listId;

  DeleteList({required this.listId});
}

class LoadListCafes extends ListsEvent {
  final String listId;

  LoadListCafes({required this.listId});
}

class AddCafeToList extends ListsEvent {
  final String listId;
  final String cafeId;

  AddCafeToList({required this.listId, required this.cafeId});
}

class RemoveCafeFromList extends ListsEvent {
  final String listId;
  final String cafeId;

  /// Completes once the remove has been answered (done, failed or skipped),
  /// before the reload it starts: from then on a list that still has the
  /// cafe is the server's word, not a reload from before it.
  final Completer<void>? done;

  RemoveCafeFromList({required this.listId, required this.cafeId, this.done});
}

class UpdateList extends ListsEvent {
  final String listId;
  final String name;
  final String? description;
  final bool isPublic;

  /// Completes once the edit is saved, or with the error that stopped it.
  final Completer<void>? done;

  UpdateList({
    required this.listId,
    required this.name,
    this.description,
    required this.isPublic,
    this.done,
  });
}
