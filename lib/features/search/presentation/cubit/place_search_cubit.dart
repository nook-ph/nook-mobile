import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nook/features/search/domain/entities/place_suggestion.dart';
import 'package:nook/features/search/domain/repositories/i_place_search_repository.dart';
import 'package:nook/features/search/domain/search_place_index.dart';

enum PlaceSearchStatus {
  /// Nothing typed, or too little to ask the map.
  idle,

  /// Waiting on the map; Nook's own areas may already show.
  loading,
  done,

  /// The map could not answer; only Nook's own areas show.
  unavailable,
}

class PlaceSearchState extends Equatable {
  const PlaceSearchState({
    this.query = '',
    this.status = PlaceSearchStatus.idle,
    this.local = const [],
    this.remote = const [],
    this.attribution,
  });

  final String query;
  final PlaceSearchStatus status;

  /// Neighbourhoods and cities from Nook's own cafes.
  final List<PlaceSuggestion> local;

  /// Places from the map service.
  final List<PlaceSuggestion> remote;

  /// Shown under the list whenever [remote] places are in it.
  final String? attribution;

  static const maxResults = 8;

  /// Nook's areas first, then map places that are not the same place again.
  List<PlaceSuggestion> get results {
    final names = {for (final p in local) p.origin.label.toLowerCase()};
    return [
      ...local,
      ...remote.where((p) => !names.contains(p.origin.label.toLowerCase())),
    ].take(maxResults).toList();
  }

  bool get showsAttribution =>
      attribution != null && results.any((p) => !p.fromNook);

  PlaceSearchState copyWith({
    String? query,
    PlaceSearchStatus? status,
    List<PlaceSuggestion>? local,
    List<PlaceSuggestion>? remote,
    String? attribution,
  }) => PlaceSearchState(
    query: query ?? this.query,
    status: status ?? this.status,
    local: local ?? this.local,
    remote: remote ?? this.remote,
    attribution: attribution ?? this.attribution,
  );

  @override
  List<Object?> get props => [query, status, local, remote, attribution];
}

/// Autocomplete for places: Nook's own areas match on every keystroke; the
/// map service is asked once typing pauses ([debounce]) and the query is at
/// least [minRemoteLength] long. An answer to an older query is dropped.
class PlaceSearchCubit extends Cubit<PlaceSearchState> {
  PlaceSearchCubit({
    required IPlaceSearchRepository repository,
    required Future<SearchPlaceIndex> places,
    this.bias,
    this.debounce = const Duration(milliseconds: 300),
  }) : _repository = repository,
       super(const PlaceSearchState()) {
    places
        .then((index) {
          _index = index;
          if (!isClosed && state.query.isNotEmpty) {
            emit(state.copyWith(local: _localMatches(state.query)));
          }
        })
        .catchError((Object _) {});
  }

  final IPlaceSearchRepository _repository;

  /// Where results should lean toward: the phone, or Cebu when unknown.
  final ({double lat, double lng})? Function()? bias;
  final Duration debounce;

  static const minRemoteLength = 3;
  static const _maxLocal = 4;

  SearchPlaceIndex _index = SearchPlaceIndex.empty;
  Timer? _timer;

  /// Bumped on every change; a reply carrying an older number is stale.
  int _generation = 0;

  List<PlaceSuggestion> _localMatches(String q) => _index
      .match(q, limit: _maxLocal)
      .map((o) => PlaceSuggestion(o, PlaceType.nookArea))
      .toList();

  void queryChanged(String text) {
    final q = text.trim();
    if (q == state.query) return;
    _timer?.cancel();
    final generation = ++_generation;
    final local = _localMatches(q);
    if (q.length < minRemoteLength) {
      emit(
        PlaceSearchState(
          query: q,
          local: local,
          attribution: state.attribution,
        ),
      );
      return;
    }
    emit(
      state.copyWith(
        query: q,
        status: PlaceSearchStatus.loading,
        local: local,
        // Keep the last map places until new ones arrive only when the
        // query still starts the same way, so the list does not flicker
        // while typing on.
        remote: q.startsWith(state.query) ? state.remote : const [],
      ),
    );
    _timer = Timer(debounce, () => _fetch(q, generation));
  }

  Future<void> _fetch(String q, int generation) async {
    final at = bias?.call();
    try {
      final result = await _repository.search(q, lat: at?.lat, lng: at?.lng);
      if (isClosed || generation != _generation) return;
      emit(
        state.copyWith(
          status: PlaceSearchStatus.done,
          remote: result.places,
          attribution: result.attribution,
        ),
      );
    } catch (_) {
      if (isClosed || generation != _generation) return;
      emit(
        state.copyWith(status: PlaceSearchStatus.unavailable, remote: const []),
      );
    }
  }

  /// Asks the map again for the current query, after it didn't answer.
  void retry() {
    final q = state.query;
    if (q.length < minRemoteLength) return;
    _timer?.cancel();
    final generation = ++_generation;
    emit(state.copyWith(status: PlaceSearchStatus.loading));
    _fetch(q, generation);
  }

  void clear() => queryChanged('');

  @override
  Future<void> close() {
    _timer?.cancel();
    return super.close();
  }
}
