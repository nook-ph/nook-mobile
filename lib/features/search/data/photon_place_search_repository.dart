import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:nook/features/search/data/edge_place_search_repository.dart';
import 'package:nook/features/search/domain/entities/place_suggestion.dart';
import 'package:nook/features/search/domain/repositories/i_place_search_repository.dart';
import 'package:nook/features/search/domain/search_place_index.dart';

/// DEBUG ONLY (see `kPlaceSearchDirect`): calls the public Photon server
/// from the phone, for trying the feature before `place-search` is
/// deployed. Release builds always go through the edge function, which
/// caches and rate-limits; this does neither.
///
/// [PhotonMapper] mirrors `supabase/functions/place-search/photon.ts` in
/// nook-supabase.
class PhotonPlaceSearchRepository implements IPlaceSearchRepository {
  PhotonPlaceSearchRepository({
    http.Client? client,
    this.baseUrl = 'https://photon.komoot.io',
  }) : _client = client ?? http.Client();

  final http.Client _client;
  final String baseUrl;

  static const _headers = {
    'User-Agent': 'Nook/1.0 debug (+https://www.nookph.app)',
    'Accept': 'application/json',
  };

  @override
  Future<PlaceSearchResult> search(
    String query, {
    double? lat,
    double? lng,
  }) async {
    final bias = lat != null && lng != null && PhotonMapper.inPh(lat, lng)
        ? (lat, lng)
        : (10.3157, 123.8854);
    final uri = Uri.parse('$baseUrl/api').replace(
      queryParameters: {
        'q': query.trim(),
        'lat': bias.$1.toStringAsFixed(1),
        'lon': bias.$2.toStringAsFixed(1),
        'lang': 'en',
        'limit': '12',
        'bbox': '116,4,127.5,22',
      },
    );
    final json = await _get(uri);
    return EdgePlaceSearchRepository.parseResponse({
      'places': PhotonMapper.map(json, 8),
      'attribution': PhotonMapper.attribution,
    });
  }

  @override
  Future<PlaceSuggestion?> reverse(double lat, double lng) async {
    final uri = Uri.parse('$baseUrl/reverse').replace(
      queryParameters: {
        'lat': lat.toStringAsFixed(5),
        'lon': lng.toStringAsFixed(5),
        'lang': 'en',
        'limit': '5',
        'radius': '0.3',
      },
    );
    final best = PhotonMapper.pickReverse(await _get(uri));
    if (best == null) return null;
    return EdgePlaceSearchRepository.parseResponse({
      'places': [best],
    }).places.first;
  }

  Future<Object?> _get(Uri uri) async {
    try {
      final res = await _client
          .get(uri, headers: _headers)
          .timeout(const Duration(seconds: 5));
      if (res.statusCode != 200) {
        throw PlaceSearchUnavailable('photon ${res.statusCode}');
      }
      return jsonDecode(res.body);
    } on PlaceSearchUnavailable {
      rethrow;
    } catch (e) {
      throw PlaceSearchUnavailable(e.toString());
    }
  }
}

/// Photon GeoJSON to Nook's place shape (`label`, `subtitle`, `lat`, `lng`,
/// `kind`).
class PhotonMapper {
  const PhotonMapper._();

  static const attribution = '© OpenStreetMap contributors';

  /// Two results with one name this close are the same place.
  static const _sameNameMeters = 1500.0;

  static bool inPh(double lat, double lng) =>
      lng >= 116 && lng <= 127.5 && lat >= 4 && lat <= 22;

  static const _minorWays = {
    'service',
    'footway',
    'path',
    'track',
    'steps',
    'cycleway',
    'pedestrian',
    'corridor',
    'platform',
  };

  static String _kind(Map p) {
    switch (p['type']) {
      case 'city':
      case 'district':
      case 'locality':
      case 'county':
      case 'state':
        return 'area';
      case 'street':
        return 'street';
    }
    if (p['osm_key'] == 'place' || p['osm_key'] == 'boundary') return 'area';
    if (p['name'] == null && p['housenumber'] != null) return 'address';
    return 'poi';
  }

  static String _subtitle(Map p, String label, String kind) {
    final parts = <String>[];
    void push(Object? s) {
      final v = (s as String?)?.trim() ?? '';
      if (v.isEmpty || v.toLowerCase() == label.toLowerCase()) return;
      if (parts.any((x) => x.toLowerCase() == v.toLowerCase())) return;
      parts.add(v);
    }

    if (kind == 'poi') push(p['street']);
    push(p['district'] ?? p['locality']);
    push(p['city'] ?? p['county'] ?? p['state']);
    return parts.take(3).join(', ');
  }

  static List<Map<String, Object>> map(Object? json, int limit) {
    final features = json is Map ? json['features'] : null;
    if (features is! List) return const [];
    final out = <Map<String, Object>>[];
    final seen = <String>{};
    for (final f in features) {
      if (f is! Map) continue;
      final p = (f['properties'] as Map?) ?? const {};
      final coords = (f['geometry'] as Map?)?['coordinates'];
      if (coords is! List || coords.length < 2) continue;
      final lng = (coords[0] as num?)?.toDouble();
      final lat = (coords[1] as num?)?.toDouble();
      if (lat == null || lng == null) continue;
      final cc = (p['countrycode'] as String?)?.toUpperCase();
      if (cc != null && cc != 'PH') continue;
      if (!inPh(lat, lng)) continue;
      if (p['osm_key'] == 'highway' && _minorWays.contains(p['osm_value'])) {
        continue;
      }
      final kind = _kind(p);
      final label =
          ((p['name'] as String?) ??
                  [p['housenumber'], p['street']].whereType<String>().join(' '))
              .trim();
      if (label.isEmpty) continue;
      final subtitle = _subtitle(p, label, kind);
      if (!seen.add('${label.toLowerCase()}|${subtitle.toLowerCase()}')) {
        continue;
      }
      // One mall mapped as an area and as a building is one place.
      if (out.any(
        (o) =>
            (o['label'] as String).toLowerCase() == label.toLowerCase() &&
            SearchPlaceIndex.distanceMeters(
                  lat,
                  lng,
                  o['lat'] as double,
                  o['lng'] as double,
                ) <
                _sameNameMeters,
      )) {
        continue;
      }
      out.add({
        'label': label,
        'subtitle': subtitle,
        'lat': lat,
        'lng': lng,
        'kind': kind,
      });
      if (out.length >= limit) break;
    }
    return out;
  }

  static Map<String, Object>? pickReverse(Object? json) {
    final places = map(json, 5);
    for (final p in places) {
      if (p['kind'] == 'poi' || p['kind'] == 'area') return p;
    }
    return places.isEmpty ? null : places.first;
  }
}
