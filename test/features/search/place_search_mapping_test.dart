import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nook/features/search/data/edge_place_search_repository.dart';
import 'package:nook/features/search/data/photon_place_search_repository.dart';
import 'package:nook/features/search/data/spot_namer.dart';
import 'package:nook/features/search/domain/entities/place_suggestion.dart';
import 'package:nook/features/search/domain/repositories/i_place_search_repository.dart';

Object? _fixture(String name) =>
    jsonDecode(File('test/features/search/fixtures/$name').readAsStringSync());

void main() {
  group('Photon mapping (recorded sample)', () {
    test('SM Seaside: label, area and street kinds, service lane dropped', () {
      final places = PhotonMapper.map(
        _fixture('photon_forward_sm_seaside.json'),
        8,
      );
      expect(places.first, {
        'label': 'SM Seaside City Cebu',
        'subtitle': 'Mambaling, Cebu City',
        'lat': 10.28127,
        'lng': 123.8795782,
        'kind': 'area',
      });
      expect(places[1]['kind'], 'street');
      expect(
        places.map((p) => p['label']),
        isNot(contains('SM Seaside City Access Road 1')),
      );
    });

    test('one name twice within 1.5 km is one place', () {
      Map<String, Object> f(
        String? district,
        String city,
        double lng,
        double lat,
      ) => {
        'properties': {
          'name': 'Ayala Center Cebu',
          'type': 'locality',
          'district': ?district,
          'city': city,
        },
        'geometry': {
          'coordinates': [lng, lat],
        },
      };
      final places = PhotonMapper.map({
        'features': [
          f('Luz', 'Cebu City', 123.9053, 10.3179),
          f(null, 'Cebu City', 123.9060, 10.3185),
          f(null, 'Makati', 121.02, 14.55),
        ],
      }, 8);
      expect(places.map((p) => p['subtitle']), ['Luz, Cebu City', 'Makati']);
    });

    test('places outside the Philippines are dropped', () {
      final json = {
        'features': [
          {
            'properties': {'name': 'Tokyo', 'countrycode': 'JP'},
            'geometry': {
              'coordinates': [139.69, 35.68],
            },
          },
          {
            'properties': {'name': 'Kota Kinabalu', 'type': 'city'},
            'geometry': {
              'coordinates': [116.07, 5.98],
            },
          },
          {
            'properties': {
              'name': 'Lahug',
              'type': 'district',
              'countrycode': 'PH',
              'city': 'Cebu City',
            },
            'geometry': {
              'coordinates': [123.9, 10.33],
            },
          },
        ],
      };
      // Kota Kinabalu sits inside the bbox, so only a country code drops
      // it; without one it stays. Tokyo is outside both.
      expect(PhotonMapper.map(json, 8).map((p) => p['label']), [
        'Kota Kinabalu',
        'Lahug',
      ]);
    });

    test('reverse prefers a landmark and reads "Near …"', () {
      final best = PhotonMapper.pickReverse(
        _fixture('photon_reverse_cbp.json'),
      )!;
      expect(best['label'], 'KFC');
      expect(best['subtitle'], 'Bohol Avenue, Luz, Cebu City');
      final suggestion = EdgePlaceSearchRepository.parseResponse({
        'places': [best],
      }).places.single;
      final name = SpotNamer.labelFor(suggestion);
      expect(name.label, 'Near KFC');
    });

    test('debug repository sends a User-Agent and maps the reply', () async {
      late http.Request sent;
      final repo = PhotonPlaceSearchRepository(
        client: MockClient((req) async {
          sent = req;
          return http.Response(
            File(
              'test/features/search/fixtures/photon_forward_sm_seaside.json',
            ).readAsStringSync(),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );
      final result = await repo.search('SM Seaside');
      expect(sent.headers['User-Agent'], contains('Nook'));
      expect(sent.url.queryParameters['bbox'], '116,4,127.5,22');
      expect(result.places.first.origin.label, 'SM Seaside City Cebu');
      expect(result.attribution, '© OpenStreetMap contributors');
    });

    test('debug repository: 429 is "unavailable"', () async {
      final repo = PhotonPlaceSearchRepository(
        client: MockClient((_) async => http.Response('slow down', 429)),
      );
      expect(repo.search('Ayala'), throwsA(isA<PlaceSearchUnavailable>()));
    });
  });

  group('edge function', () {
    test('parses Nook’s shape', () {
      final result = EdgePlaceSearchRepository.parseResponse({
        'places': [
          {
            'label': 'USC Talamban Campus',
            'subtitle': 'Banilad, Cebu City',
            'lat': 10.35,
            'lng': 123.91,
            'kind': 'poi',
          },
          {'label': '', 'lat': 1, 'lng': 1},
        ],
        'attribution': '© OpenStreetMap contributors',
      });
      expect(result.places.single.type, PlaceType.landmark);
      expect(result.places.single.origin.subtitle, 'Banilad, Cebu City');
    });

    test(
      'a failed call is "unavailable"; repeats are answered from memory',
      () async {
        var calls = 0;
        var fail = true;
        final repo = EdgePlaceSearchRepository((body) async {
          calls++;
          if (fail) throw Exception('503');
          expect(body['mode'], 'search');
          return {
            'places': [
              {'label': 'IT Park', 'lat': 10.33, 'lng': 123.9, 'kind': 'area'},
            ],
          };
        });
        await expectLater(
          repo.search('it park'),
          throwsA(isA<PlaceSearchUnavailable>()),
        );
        fail = false;
        await repo.search('IT  Park');
        await repo.search('it park');
        expect(calls, 2);
      },
    );
  });
}
