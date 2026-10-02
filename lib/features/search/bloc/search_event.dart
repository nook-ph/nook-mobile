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
  /// The user asked again after a page failed. The list's own request, sent
  /// from every build near its end, does not retry a failure.
  final bool retry;
  const SearchLoadMore({this.retry = false});

  @override
  List<Object?> get props => [retry];
}

class SearchRefresh extends SearchEvent {
  const SearchRefresh();
}

class SearchDismissLocationBanner extends SearchEvent {
  const SearchDismissLocationBanner();
}

/// Measure from [origin] instead of the phone; null goes back to the phone.
class SearchOriginChanged extends SearchEvent {
  final SearchOrigin? origin;
  const SearchOriginChanged(this.origin);

  @override
  List<Object?> get props => [origin];
}

class SearchOpenNowToggled extends SearchEvent {
  const SearchOpenNowToggled();
}

/// Clears tags, "Open now" and sort; the query and place stay.
class SearchFiltersCleared extends SearchEvent {
  const SearchFiltersCleared();
}

/// Re-read whether the phone's location can be used: on opening search, on
/// coming back from Settings, and after the system prompt.
class SearchLocationChecked extends SearchEvent {
  const SearchLocationChecked();
}
