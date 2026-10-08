import 'dart:async';

import 'package:nook/features/search/domain/entities/place_suggestion.dart';
import 'package:nook/features/search/domain/entities/saved_place.dart';
import 'package:nook/features/search/domain/entities/search_origin.dart';
import 'package:nook/features/search/domain/repositories/i_place_search_repository.dart';
import 'package:nook/features/search/domain/repositories/i_saved_places_repository.dart';

PlaceSuggestion landmark(String label, {String? subtitle, double lat = 10.3}) =>
    PlaceSuggestion(
      SearchOrigin(label: label, subtitle: subtitle, lat: lat, lng: 123.9),
      PlaceType.landmark,
    );

/// Answers from [answers] by query; records every query asked. A query in
/// [hold] waits until its completer is completed.
class FakePlaceSearchRepository implements IPlaceSearchRepository {
  FakePlaceSearchRepository({this.answers = const {}, this.fail = false});

  final Map<String, List<PlaceSuggestion>> answers;
  bool fail;
  final List<String> queries = [];
  final Map<String, Completer<void>> hold = {};
  PlaceSuggestion? reverseAnswer;

  @override
  Future<PlaceSearchResult> search(
    String query, {
    double? lat,
    double? lng,
  }) async {
    queries.add(query);
    final wait = hold[query];
    if (wait != null) await wait.future;
    if (fail) throw const PlaceSearchUnavailable('busy');
    return PlaceSearchResult(
      answers[query] ?? const [],
      attribution: '© OpenStreetMap contributors',
    );
  }

  @override
  Future<PlaceSuggestion?> reverse(double lat, double lng) async {
    if (fail) throw const PlaceSearchUnavailable('busy');
    return reverseAnswer;
  }
}

/// Saved places in memory, with the database's cap.
class FakeSavedPlacesRepository implements ISavedPlacesRepository {
  FakeSavedPlacesRepository({List<SavedPlace>? places, this.canSave = true})
    : places = places ?? [];

  final List<SavedPlace> places;
  var _next = 0;
  bool failSave = false;

  @override
  final bool canSave;

  @override
  Future<List<SavedPlace>> list() async => List.of(places);

  @override
  Future<SavedPlace> save(SavedPlace place) async {
    if (failSave) throw Exception('offline');
    final id = place.id;
    if (id == null) {
      if (places.length >= ISavedPlacesRepository.maxPlaces) {
        throw const SavedPlacesLimitReached();
      }
      final stored = place.copyWith(id: 'p${_next++}');
      places.add(stored);
      return stored;
    }
    final i = places.indexWhere((p) => p.id == id);
    places[i] = place;
    return place;
  }

  @override
  Future<void> delete(String id) async => places.removeWhere((p) => p.id == id);
}
