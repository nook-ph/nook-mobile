abstract class ListsEvent {}

class LoadUserLists extends ListsEvent {}

class CreateList extends ListsEvent {
  final String name;
  final String? description;

  CreateList({required this.name, this.description});
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

  RemoveCafeFromList({required this.listId, required this.cafeId});
}
