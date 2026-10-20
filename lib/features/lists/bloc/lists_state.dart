import 'package:nook/core/cafe/domain/entities/cafe_list.dart';
import 'package:nook/core/cafe/domain/entities/cafe_summary.dart';

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

  /// How many add/remove writes had been answered when this load started
  /// ([ListsBloc.settledWrites]): it reflects at least every one of them
  /// (a write settling while it reads may show too). A page uses it to
  /// tell a reload from before its write. Required, so no load can pass
  /// for one from before every write by leaving it out.
  final int afterWrites;

  ListCafesLoaded(this.list, this.cafes, {required this.afterWrites});
}

class ListsError extends ListsState {
  final Object error;

  ListsError(this.error);
}
