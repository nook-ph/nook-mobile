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

  /// Where distances are measured from; null means the phone's location.
  final SearchOrigin? origin;

  /// Keep only cafes open right now. Applied to the fetched rows on the
  /// device: `get_cafes` has no parameter for it.
  final bool openNow;

  /// True once the results were fetched with a position (phone or origin),
  /// so the list can say "near you" or name the place.
  final bool hasPosition;

  /// Whether the phone's location can be used. Drives the "Near" row, the
  /// "Search near you" card and the location card above results.
  final SearchLocationStatus location;

  /// "Nearest" was asked for without a position, so the results came back
  /// by rating instead.
  final bool sortFellBack;

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
    this.origin,
    this.openNow = false,
    this.hasPosition = false,
    this.location = SearchLocationStatus.available,
    this.sortFellBack = false,
  });

  /// The sort the results are really in, for the sort chip and sheet.
  String get shownSort => sortFellBack ? 'top_rated' : sort;

  /// The phone's location is wanted (no place chosen) but cannot be used.
  bool get locationUnavailable =>
      origin == null && location != SearchLocationStatus.available;

  /// The rows to show: [cafes], minus closed ones when [openNow] is on.
  List<CafeSummary> get visibleCafes {
    if (!openNow) return cafes;
    return cafes
        .where((c) => CafeOpenStatus.resolve(c.operatingHours).isOpen)
        .toList();
  }

  /// Whether "Open now" can be offered. `get_cafes` does not return opening
  /// hours yet, and without them the filter would hide every cafe; the chip
  /// comes back by itself once the rows carry hours.
  bool get canFilterOpenNow =>
      openNow || cafes.any((c) => c.operatingHours != null);

  bool get hasFilters => tags.isNotEmpty || openNow || sort != 'nearby';

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
    SearchOrigin? origin,
    bool clearOrigin = false,
    bool? openNow,
    bool? hasPosition,
    SearchLocationStatus? location,
    bool? sortFellBack,
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
      origin: clearOrigin ? null : origin ?? this.origin,
      openNow: openNow ?? this.openNow,
      hasPosition: hasPosition ?? this.hasPosition,
      location: location ?? this.location,
      sortFellBack: sortFellBack ?? this.sortFellBack,
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
    origin,
    openNow,
    hasPosition,
    location,
    sortFellBack,
  ];
}
