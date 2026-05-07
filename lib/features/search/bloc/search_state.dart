part of 'search_bloc.dart';

enum SearchStatus { initial, loading, success, failure }

class SearchState extends Equatable {
  final SearchStatus status;
  final List<CafeSummary> cafes;
  final String query;
  final Set<String> tags;
  final String sort;
  final int page;
  final bool hasReachedMax;

  /// Thrown object from last failed fetch (for [AppErrorCopy]).
  final Object? lastError;

  final bool locationDenied;

  /// User dismissed banner until next successful fetch.
  final bool locationBannerDismissed;

  const SearchState({
    this.status = SearchStatus.initial,
    this.cafes = const [],
    this.query = '',
    this.tags = const {},
    this.sort = 'nearby',
    this.page = 0,
    this.hasReachedMax = false,
    this.lastError,
    this.locationDenied = false,
    this.locationBannerDismissed = false,
  });

  SearchState copyWith({
    SearchStatus? status,
    List<CafeSummary>? cafes,
    String? query,
    Set<String>? tags,
    String? sort,
    int? page,
    bool? hasReachedMax,
    Object? lastError,
    bool? locationDenied,
    bool? locationBannerDismissed,
    bool clearLastError = false,
  }) {
    return SearchState(
      status: status ?? this.status,
      cafes: cafes ?? this.cafes,
      query: query ?? this.query,
      tags: tags ?? this.tags,
      sort: sort ?? this.sort,
      page: page ?? this.page,
      hasReachedMax: hasReachedMax ?? this.hasReachedMax,
      lastError: clearLastError ? null : lastError ?? this.lastError,
      locationDenied: locationDenied ?? this.locationDenied,
      locationBannerDismissed:
          locationBannerDismissed ?? this.locationBannerDismissed,
    );
  }

  @override
  List<Object?> get props => [
        status,
        cafes,
        query,
        tags,
        sort,
        page,
        hasReachedMax,
        lastError,
        locationDenied,
        locationBannerDismissed,
      ];
}
