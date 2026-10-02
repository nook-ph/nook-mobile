import 'package:flutter_test/flutter_test.dart';
import 'package:nook/core/cafe/domain/entities/cafe_summary.dart';
import 'package:nook/features/search/bloc/search_bloc.dart';
import 'package:nook/features/search/data/search_location.dart';
import 'package:nook/features/search/domain/entities/search_origin.dart';
import 'package:nook/features/search/presentation/pages/search_results_page.dart';
import 'package:nook/features/search/presentation/widgets/search_empty_view.dart';

void main() {
  const itPark = SearchOrigin(
    label: 'IT Park',
    subtitle: 'Cebu City',
    lat: 10.33,
    lng: 123.9,
  );
  const pin = SearchOrigin.pin(lat: 10.3, lng: 123.8);

  group('SearchOrigin', () {
    test('JSON round trip', () {
      expect(SearchOrigin.fromJson(itPark.toJson()), itPark);
      expect(SearchOrigin.fromJson(pin.toJson()), pin);
    });

    test('bad JSON reads as null', () {
      expect(SearchOrigin.fromJson(null), isNull);
      expect(SearchOrigin.fromJson('x'), isNull);
      expect(SearchOrigin.fromJson({'label': 'A'}), isNull);
    });

    test('pin is labelled Pinned location', () {
      expect(pin.isPin, isTrue);
      expect(pin.label, 'Pinned location');
      expect(itPark.isPin, isFalse);
      expect(itPark.fullLabel, 'IT Park, Cebu City');
    });
  });

  group('SearchState', () {
    test('hasFilters', () {
      expect(const SearchState().hasFilters, isFalse);
      expect(const SearchState(openNow: true).hasFilters, isTrue);
      expect(const SearchState(tags: {'Free WiFi'}).hasFilters, isTrue);
      expect(const SearchState(sort: 'top_rated').hasFilters, isTrue);
    });

    test('open now drops cafes that are not open', () {
      const cafe = CafeSummary(id: '1', name: 'A', rating: 4);
      expect(const SearchState(cafes: [cafe]).visibleCafes, [cafe]);
      expect(
        const SearchState(cafes: [cafe], openNow: true).visibleCafes,
        isEmpty,
      );
    });

    test('"Open now" is only offered when the rows carry hours (S-1)', () {
      const bare = CafeSummary(id: '1', name: 'A', rating: 4);
      const withHours = CafeSummary(
        id: '2',
        name: 'B',
        rating: 4,
        operatingHours: {
          'monday': {'open': '08:00', 'close': '17:00'},
        },
      );
      expect(const SearchState(cafes: [bare]).canFilterOpenNow, isFalse);
      expect(
        const SearchState(cafes: [bare, withHours]).canFilterOpenNow,
        isTrue,
      );
      // Already on: the chip stays, so it can be turned off again.
      expect(
        const SearchState(cafes: [bare], openNow: true).canFilterOpenNow,
        isTrue,
      );
    });

    test('a pin takes the name of the neighbourhood it is near', () {
      const named = SearchOrigin.pin(
        lat: 10.3,
        lng: 123.8,
        near: 'Banilad, Cebu City',
      );
      expect(named.isPin, isTrue);
      expect(named.label, 'Banilad, Cebu City');
      expect(named.fullLabel, 'Banilad, Cebu City');
      expect(SearchOrigin.fromJson(named.toJson()), named);
    });

    test('the sort chip shows the sort the results are really in', () {
      expect(const SearchState().shownSort, 'nearby');
      expect(const SearchState(sortFellBack: true).shownSort, 'top_rated');
      expect(
        const SearchState(sort: 'newest', sortFellBack: false).shownSort,
        'newest',
      );
    });

    test('location is unavailable only when no place is chosen', () {
      expect(const SearchState().locationUnavailable, isFalse);
      expect(
        const SearchState(
          location: SearchLocationStatus.off,
        ).locationUnavailable,
        isTrue,
      );
      expect(
        const SearchState(
          location: SearchLocationStatus.notAsked,
        ).locationUnavailable,
        isTrue,
      );
      expect(
        const SearchState(
          location: SearchLocationStatus.off,
          origin: itPark,
        ).locationUnavailable,
        isFalse,
      );
    });

    test('copyWith sets and clears the origin', () {
      final set = const SearchState().copyWith(origin: itPark);
      expect(set.origin, itPark);
      expect(set.copyWith(openNow: true).origin, itPark);
      expect(set.copyWith(clearOrigin: true).origin, isNull);
    });
  });

  group('copy', () {
    test('count line', () {
      expect(searchCountLine(12, null, true), '12 cafes near you');
      expect(searchCountLine(1, null, false), '1 cafe');
      expect(
        searchCountLine(12, null, false, byRating: true),
        '12 cafes · sorted by rating',
      );
      // With a position, or a place, "sorted by rating" never shows.
      expect(
        searchCountLine(12, null, true, byRating: true),
        '12 cafes near you',
      );
      expect(
        searchCountLine(8, itPark, true, byRating: true),
        '8 cafes near IT Park · distances from IT Park',
      );
      expect(
        searchCountLine(8, itPark, true),
        '8 cafes near IT Park · distances from IT Park',
      );
      expect(
        searchCountLine(3, pin, true),
        '3 cafes near your pin · distances from the pin',
      );
    });

    test('no results line', () {
      expect(
        searchNoResultsLine(
          query: 'matcha',
          place: 'IT Park',
          filters: ['Open now', 'Free WiFi'],
        ),
        'Nothing matches “matcha” near IT Park with Open now and Free WiFi on.',
      );
      expect(searchNoResultsLine(query: ' ', filters: []), 'Nothing matches.');
      expect(
        searchNoResultsLine(query: 'x', filters: ['A', 'B', 'C']),
        'Nothing matches “x” with A, B and C on.',
      );
    });
  });
}
