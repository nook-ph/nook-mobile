import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nook/features/public_profile/domain/entities/public_profile.dart';
import 'package:nook/features/public_profile/presentation/widgets/people_matches.dart';
import 'package:go_router/go_router.dart';
import 'package:nook/core/utils/app_error_copy.dart';
import 'package:nook/core/utils/error_info.dart';
import 'package:nook/features/search/bloc/search_bloc.dart';
import 'package:nook/core/utils/toast_helper.dart';
import 'package:nook/features/search/data/search_location.dart';
import 'package:nook/features/search/data/search_places.dart';
import 'package:nook/features/search/data/search_recents_store.dart';
import 'package:nook/features/search/presentation/search_origin_picker.dart';
import 'package:nook/features/search/domain/entities/search_origin.dart';
import 'package:nook/features/search/presentation/widgets/search_empty_view.dart';
import 'package:nook/features/search/presentation/widgets/search_filters.dart';
import 'package:nook/features/search/presentation/widgets/search_header.dart';
import 'package:nook/features/search/presentation/widgets/search_idle_view.dart';
import 'package:nook/features/search/presentation/widgets/search_rows.dart';
import 'package:nook/features/search/presentation/widgets/search_tag_match.dart';
import 'package:nook/features/search/presentation/widgets/search_tokens.dart';
import 'package:nook/injection_container.dart';
import 'package:nook/core/analytics/log_app_event.dart';

/// "12 cafes near you", "8 cafes near IT Park · distances from IT Park", or
/// "12 cafes · sorted by rating" when there was no position to be near and
/// the results fell back to rating ([byRating]).
///
/// [showsDistances] is false when the rows carry no distance (`get_cafes`
/// only measures for the "Nearest" sort); the line then promises neither
/// nearness nor distances.
String searchCountLine(
  int count,
  SearchOrigin? origin,
  bool hasPosition, {
  bool byRating = false,
  bool showsDistances = true,
}) {
  final cafes = count == 1 ? '1 cafe' : '$count cafes';
  if (origin == null || !showsDistances) {
    if (hasPosition && showsDistances) return '$cafes near you';
    return byRating ? '$cafes · sorted by rating' : cafes;
  }
  if (origin.isPin) return '$cafes near your pin · distances from the pin';
  return '$cafes near ${origin.label} · distances from ${origin.label}';
}

class SearchResultsPage extends StatefulWidget {
  const SearchResultsPage({super.key, required this.query, this.sort});

  final String query;

  /// Opens straight on results in this order with no text: the full list
  /// behind a Home shelf ("nearby", "newest", "trending", "top_rated").
  final String? sort;

  @override
  State<SearchResultsPage> createState() => _SearchResultsPageState();
}

class _SearchResultsPageState extends State<SearchResultsPage>
    with WidgetsBindingObserver {
  static const int _maxMatches = 3;

  late final TextEditingController _controller;
  late final FocusNode _focus;
  late final SearchBloc _bloc;
  final _recentsStore = SearchRecentsStore();

  List<String> _recents = const [];

  /// The query was committed (search key, "See all", a chip or a recent).
  /// Editing the text goes back to live matches.
  bool _submitted = false;

  /// Showing a Home shelf's full list. Results show without text or tags
  /// until the person clears the field or types.
  bool _browsing = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.query);
    _focus = FocusNode()..addListener(() => setState(() {}));
    _bloc = sl<SearchBloc>();
    _submitted = widget.query.trim().isNotEmpty;

    _recentsStore.searches().then((v) {
      if (mounted) setState(() => _recents = v);
    });
    WidgetsBinding.instance.addObserver(this);
    _bloc.add(const SearchLocationChecked());

    final sort = widget.sort;
    if (sort != null && widget.query.trim().isEmpty) {
      _browsing = true;
      _submitted = true;
      _bloc.add(SearchSortChanged(sort));
    } else if (widget.query.trim().isNotEmpty) {
      _bloc.add(SearchQueryChanged(widget.query));
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final route = ModalRoute.of(context);
        if (route?.animation?.isCompleted ?? true) {
          _focus.requestFocus();
        } else {
          route?.animation?.addStatusListener(_onRouteAnimation);
        }
      });
    }
  }

  void _onRouteAnimation(AnimationStatus status) {
    if (status == AnimationStatus.completed && mounted) {
      _focus.requestFocus();
      ModalRoute.of(
        context,
      )?.animation?.removeStatusListener(_onRouteAnimation);
    }
  }

  /// Back from Settings or the system prompt: location may have changed.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_bloc.isClosed) {
      _bloc.add(const SearchLocationChecked());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    _focus.dispose();
    _bloc.close();
    super.dispose();
  }

  Future<void> _remember(String query) async {
    if (query.trim().isEmpty) return;
    final list = await _recentsStore.addSearch(query);
    if (mounted) setState(() => _recents = list);
  }

  void _onChanged(String value) {
    setState(() {
      _submitted = false;
      _browsing = false;
    });
    _bloc.add(SearchQueryChanged(value));
  }

  /// The last submitted search already reported as having no results.
  String? _loggedEmpty;

  /// Reports a submitted search with no results, once per search, so the
  /// share of dead ends can be measured (docs/ux/find-a-cafe.md, finding 1).
  void _onSearchState(BuildContext context, SearchState state) {
    if (!_submitted || state.status != SearchStatus.success) return;
    if (state.visibleCafes.isNotEmpty) return;
    final key = '${state.query}|${state.tags.join(',')}|${state.openNow}';
    if (key == _loggedEmpty) return;
    _loggedEmpty = key;
    logAppEvent(
      'search_no_results',
      properties: {
        'query_length': state.query.trim().length,
        'tag_count': state.tags.length,
        'open_now': state.openNow,
        'suggested_tag': searchTagsFor(state.query, max: 1).isNotEmpty,
      },
    );
  }

  void _submit([String? value]) {
    final query = value ?? _controller.text;
    // "@bea" looks for people, not cafes: keep the People matches up.
    if (peopleQuery(query) != null) {
      _focus.unfocus();
      _remember(query);
      return;
    }
    setState(() => _submitted = true);
    _focus.unfocus();
    _remember(query);
    _bloc.add(SearchQueryChanged(query));
  }

  void _clearText() {
    _controller.clear();
    _onChanged('');
    _focus.requestFocus();
  }

  void _useRecent(String query) {
    _controller.text = query;
    _controller.selection = TextSelection.collapsed(offset: query.length);
    _submit(query);
  }

  Future<void> _removeRecent(String query) async {
    final list = await _recentsStore.removeSearch(query);
    if (mounted) setState(() => _recents = list);
  }

  /// Empties the list, with Undo in the toast that says so.
  Future<void> _clearRecents() async {
    final previous = await _recentsStore.clearSearches();
    if (!mounted) return;
    setState(() => _recents = const []);
    showPrimaryToastWithAction(
      context,
      'Recent searches cleared',
      actionLabel: 'Undo',
      onAction: () async {
        final list = await _recentsStore.restoreSearches(previous);
        if (mounted) setState(() => _recents = list);
      },
    );
  }

  /// "Turn on" / "Use my location": the system prompt, or Settings when the
  /// prompt can no longer appear.
  Future<void> _turnOnLocation() async {
    await turnOnSearchLocation();
    if (!mounted) return;
    _bloc.add(const SearchLocationChecked());
  }

  /// A filter suggested by the typed words replaces them: "wifi" becomes the
  /// Free WiFi filter with no text, so the results are every nearby cafe
  /// with it rather than cafes whose names look like "wifi".
  void _applySuggestedTag(String tag) {
    logAppEvent('search_tag_suggestion_used', properties: {'tag': tag});
    _remember(_controller.text);
    _controller.clear();
    _bloc.add(const SearchQueryChanged(''));
    final tags = {..._bloc.state.tags, tag};
    setState(() => _submitted = true);
    _focus.unfocus();
    _bloc.add(SearchTagsChanged(tags));
  }

  void _toggleTag(String tag) {
    final tags = {..._bloc.state.tags};
    if (!tags.remove(tag)) tags.add(tag);
    setState(() => _submitted = true);
    _focus.unfocus();
    _bloc.add(SearchTagsChanged(tags));
  }

  Future<void> _openTagsSheet() async {
    final tags = await showSearchTagsSheet(
      context,
      _bloc.state.tags,
      count: _bloc.countFor,
    );
    if (tags != null) _bloc.add(SearchTagsChanged(tags));
  }

  Future<void> _openSortSheet() async {
    final sort = await showSearchSortSheet(context, _bloc.state.shownSort);
    if (sort != null && sort != _bloc.state.sort) {
      _bloc.add(SearchSortChanged(sort));
    }
  }

  Future<void> _openOriginSheet() async {
    _focus.unfocus();
    final pick = await pickSearchOrigin(
      context,
      current: _bloc.state.origin,
      places: sl<SearchPlaces>(),
      recents: _recentsStore,
    );
    if (!mounted || pick == null) return;
    _bloc.add(SearchOriginChanged(pick.origin));
    // Choosing "Current location" before the system prompt has ever been
    // shown shows it.
    if (pick.origin == null &&
        _bloc.state.location == SearchLocationStatus.notAsked) {
      await _turnOnLocation();
    }
  }

  void _retryOrSignIn(SearchState state) {
    final info = AppErrorCopy.fromException(
      state.lastError ?? Exception('Search failed'),
    );
    if (info.type == ErrorType.sessionExpired) {
      context.push('/login');
      return;
    }
    _bloc.add(const SearchRefresh());
  }

  Future<void> _refresh() async {
    _bloc.add(const SearchRefresh());
    // Leaving the page closes the bloc mid-refresh; the stream then ends
    // with no match, which is not an error.
    await _bloc.stream.firstWhere(
      (s) => s.status != SearchStatus.loading,
      orElse: () => _bloc.state,
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _bloc,
      child: Scaffold(
        backgroundColor: SearchTokens.surface,
        body: SafeArea(
          bottom: false,
          child: BlocConsumer<SearchBloc, SearchState>(
            listener: _onSearchState,
            builder: (context, state) {
              final idle =
                  !_browsing &&
                  state.query.trim().isEmpty &&
                  state.tags.isEmpty;
              final typing =
                  !idle &&
                  ((!_submitted &&
                          _focus.hasFocus &&
                          state.query.trim().isNotEmpty) ||
                      // People matches stay up with the keyboard down.
                      peopleQuery(state.query) != null);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SearchHeader(
                    controller: _controller,
                    focusNode: _focus,
                    origin: state.origin,
                    onChanged: _onChanged,
                    onSubmitted: _submit,
                    onClear: _clearText,
                    onOriginTap: _openOriginSheet,
                    onReset: () => _bloc.add(const SearchOriginChanged(null)),
                    location: state.location,
                    onTurnOn: _turnOnLocation,
                  ),
                  if (!idle && !typing)
                    SearchFiltersRow(
                      sort: state.shownSort,
                      openNow: state.openNow,
                      tags: state.tags,
                      onAllFilters: _openTagsSheet,
                      onSort: _openSortSheet,
                      onOpenNow: () => _bloc.add(const SearchOpenNowToggled()),
                      onTag: _toggleTag,
                      showOpenNow: state.canFilterOpenNow,
                    ),
                  const SearchDivider(),
                  Expanded(
                    child: idle
                        ? SearchIdleView(
                            recents: _recents,
                            onRecentTap: _useRecent,
                            onRecentRemove: _removeRecent,
                            onTagTap: _toggleTag,
                            onClearRecents: _clearRecents,
                            locationCard:
                                state.origin == null &&
                                    state.location ==
                                        SearchLocationStatus.notAsked
                                ? SearchLocationPromptCard(
                                    onUseMyLocation: _turnOnLocation,
                                    onChoosePlace: _openOriginSheet,
                                  )
                                : null,
                          )
                        : typing
                        ? _Matches(
                            state: state,
                            onSeeAll: _submit,
                            onMatchTap: () => _remember(state.query),
                            onTag: _applySuggestedTag,
                          )
                        : _Results(
                            state: state,
                            onRefresh: _refresh,
                            onRetry: () => _retryOrSignIn(state),
                            onClearFilters: () =>
                                _bloc.add(const SearchFiltersCleared()),
                            onSearchNearMe: () =>
                                _bloc.add(const SearchOriginChanged(null)),
                            onDismissBanner: () =>
                                _bloc.add(const SearchDismissLocationBanner()),
                            onTag: _applySuggestedTag,
                          ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _Matches extends StatelessWidget {
  const _Matches({
    required this.state,
    required this.onSeeAll,
    required this.onMatchTap,
    required this.onTag,
  });

  final SearchState state;
  final VoidCallback onSeeAll;
  final VoidCallback onMatchTap;
  final ValueChanged<String> onTag;

  @override
  Widget build(BuildContext context) {
    final people = peopleQuery(state.query);
    if (people != null) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        children: [PeopleMatches(prefix: people, onOpen: onMatchTap)],
      );
    }
    final matches = state.visibleCafes
        .take(_SearchResultsPageState._maxMatches)
        .toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: [
        // Filters the words mean come first: "wifi" is a filter, not a name.
        for (final tag in searchTagsFor(state.query))
          if (!state.tags.contains(tag))
            SearchTagSuggestionRow(tag: tag, onTap: () => onTag(tag)),
        for (final cafe in matches)
          SearchMatchRow(cafe: cafe, query: state.query, onOpen: onMatchTap),
        if (matches.isNotEmpty) const SearchDivider(),
        SearchSeeAllRow(query: state.query, onTap: onSeeAll),
      ],
    );
  }
}

class _Results extends StatelessWidget {
  const _Results({
    required this.state,
    required this.onRefresh,
    required this.onRetry,
    required this.onClearFilters,
    required this.onSearchNearMe,
    required this.onDismissBanner,
    required this.onTag,
  });

  final SearchState state;
  final Future<void> Function() onRefresh;
  final VoidCallback onRetry;
  final VoidCallback onClearFilters;
  final VoidCallback onSearchNearMe;
  final VoidCallback onDismissBanner;
  final ValueChanged<String> onTag;

  @override
  Widget build(BuildContext context) {
    final loading =
        state.status == SearchStatus.loading ||
        state.status == SearchStatus.initial;
    final cafes = state.visibleCafes;

    if (state.status == SearchStatus.failure && state.cafes.isEmpty) {
      return SearchErrorBlock(
        error: AppErrorCopy.fromException(
          state.lastError ?? Exception('Search failed'),
        ),
        onRetry: onRetry,
      );
    }

    if (!loading && cafes.isEmpty) {
      final filters = [if (state.openNow) 'Open now', ...state.tags];
      final suggested = searchTagsFor(
        state.query,
        max: 1,
      ).where((t) => !state.tags.contains(t)).firstOrNull;
      return SearchEmptyView(
        line: searchNoResultsLine(
          query: state.query,
          place: state.origin?.isPin == true ? 'your pin' : state.origin?.label,
          filters: filters,
        ),
        onClearFilters: state.hasFilters ? onClearFilters : null,
        onSearchNearMe: state.origin != null ? onSearchNearMe : null,
        suggestedTag: suggested,
        onSuggestedTag: suggested == null ? null : () => onTag(suggested),
      );
    }

    // Loading shows skeletons in the page's shape instead of a blank screen
    // (QA bug 4: the list was cleared before each fetch, so there was
    // nothing to shimmer).
    final showBanner =
        !loading &&
        state.locationUnavailable &&
        !state.hasPosition &&
        !state.locationBannerDismissed;

    return RefreshIndicator(
      color: SearchTokens.brand,
      onRefresh: onRefresh,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        itemCount: loading ? 1 : cafes.length + 1,
        itemBuilder: (context, index) {
          if (loading) return const SearchResultsSkeleton();
          if (index == 0) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (showBanner)
                  SearchLocationOffCard(onDismiss: onDismissBanner),
                Text(
                  searchCountLine(
                    cafes.length,
                    state.origin,
                    state.hasPosition,
                    byRating: state.shownSort == 'top_rated',
                    showsDistances: cafes.any((c) => c.distanceMeters != null),
                  ),
                  style: SearchTokens.text(
                    context,
                    size: 12,
                    color: SearchTokens.muted,
                  ),
                ),
              ],
            );
          }
          final i = index - 1;
          if (state.status == SearchStatus.success &&
              !state.hasReachedMax &&
              i == cafes.length - 1) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (context.mounted) {
                context.read<SearchBloc>().add(const SearchLoadMore());
              }
            });
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (i > 0) const SearchDivider(),
              SearchResultRow(cafe: cafes[i]),
              if (state.loadMoreFailed && i == cafes.length - 1)
                SearchLoadMoreError(
                  error: AppErrorCopy.fromException(
                    state.lastError ?? Exception('Search failed'),
                  ),
                  onRetry: () => context.read<SearchBloc>().add(
                    const SearchLoadMore(retry: true),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
