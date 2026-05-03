part of 'search_bloc.dart';

abstract class SearchEvent extends Equatable {
  const SearchEvent();

  @override
  List<Object?> get props => [];
}

class SearchQueryChanged extends SearchEvent {
  final String query;
  const SearchQueryChanged(this.query);

  @override
  List<Object?> get props => [query];
}

class SearchTagsChanged extends SearchEvent {
  final Set<String> tags;
  const SearchTagsChanged(this.tags);

  @override
  List<Object?> get props => [tags];
}

class SearchSortChanged extends SearchEvent {
  final String sort;
  const SearchSortChanged(this.sort);

  @override
  List<Object?> get props => [sort];
}

class SearchLoadMore extends SearchEvent {
  const SearchLoadMore();
}

class SearchRefresh extends SearchEvent {
  const SearchRefresh();
}
