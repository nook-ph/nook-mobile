import 'package:nook/core/cafe/domain/entities/cafe_summary.dart';
import 'package:nook/features/lists/domain/entities/cafe_list.dart';

abstract class ListsState {}

class ListsInitial extends ListsState {}

class ListsLoading extends ListsState {}

class ListsLoaded extends ListsState {
  final List<CafeList> lists;

  ListsLoaded(this.lists);
}

class ListCafesLoaded extends ListsState {
  final CafeList list;
  final List<CafeSummary> cafes;

  ListCafesLoaded(this.list, this.cafes);
}

class ListsError extends ListsState {
  final String message;

  ListsError(this.message);
}
