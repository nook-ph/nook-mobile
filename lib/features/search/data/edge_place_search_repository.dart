import 'package:nook/features/search/domain/entities/place_suggestion.dart';
import 'package:nook/features/search/domain/entities/search_origin.dart';
import 'package:nook/features/search/domain/repositories/i_place_search_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Place search through the `place-search` edge function, which returns
/// Nook's own shape whatever geocoder it uses.
class EdgePlaceSearchRepository implements IPlaceSearchRepository {
  EdgePlaceSearchRepository(this._invoke);

  /// `functions.invoke('place-search', body: …)`, returning the JSON body.
  /// Throws on a non-2xx status.
  final Future<Object?> Function(Map<String, dynamic> body) _invoke;

  factory EdgePlaceSearchRepository.supabase(SupabaseClient client) {
    return EdgePlaceSearchRepository((body) async {
      final res = await client.functions.invoke('place-search', body: body);
      return res.data;
    });
  }

  /// Answers already fetched this session, so retyping a query or backing
  /// up a letter costs nothing.
  final _memo = <String, PlaceSearchResult>{};
  static const _memoSize = 40;

  @override
  Future<PlaceSearchResult> search(
    String query, {
    double? lat,
    double? lng,
  }) async {
    final q = query.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
    final key = '$q|${lat?.toStringAsFixed(1)}|${lng?.toStringAsFixed(1)}';
    final hit = _memo.remove(key);
    if (hit != null) return _memo[key] = hit;

    final json = await _call({
      'mode': 'search',
      'q': query.trim(),
      'lat': ?lat,
      'lng': ?lng,
      'limit': 8,
    });
    final result = parseResponse(json);
    _memo[key] = result;
    if (_memo.length > _memoSize) _memo.remove(_memo.keys.first);
    return result;
  }

  @override
  Future<PlaceSuggestion?> reverse(double lat, double lng) async {
    final json = await _call({'mode': 'reverse', 'lat': lat, 'lng': lng});
    final places = parseResponse(json).places;
    return places.isEmpty ? null : places.first;
  }

  Future<Object?> _call(Map<String, dynamic> body) async {
    try {
      return await _invoke(body);
    } catch (e) {
      throw PlaceSearchUnavailable(e.toString());
    }
  }

  /// `{ places: [{label, subtitle, lat, lng, kind}], attribution }`.
  static PlaceSearchResult parseResponse(Object? json) {
    if (json is! Map) throw const PlaceSearchUnavailable('bad response');
    final raw = json['places'];
    final places = <PlaceSuggestion>[];
    if (raw is List) {
      for (final p in raw) {
        if (p is! Map) continue;
        final lat = (p['lat'] as num?)?.toDouble();
        final lng = (p['lng'] as num?)?.toDouble();
        final label = (p['label'] as String?)?.trim() ?? '';
        if (lat == null || lng == null || label.isEmpty) continue;
        final sub = (p['subtitle'] as String?)?.trim();
        places.add(
          PlaceSuggestion(
            SearchOrigin(
              label: label,
              subtitle: sub == null || sub.isEmpty ? null : sub,
              lat: lat,
              lng: lng,
            ),
            PlaceType.fromKind(p['kind'] as String?),
          ),
        );
      }
    }
    return PlaceSearchResult(
      places,
      attribution: json['attribution'] as String?,
    );
  }
}
