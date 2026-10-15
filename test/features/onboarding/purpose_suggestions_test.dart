import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:nook/core/cafe/domain/entities/cafe_query.dart';
import 'package:nook/core/cafe/domain/entities/cafe_summary.dart';
import 'package:nook/core/cafe/domain/repositories/i_cafe_repository.dart';
import 'package:nook/core/location/device_location.dart';
import 'package:nook/core/preferences/onboarding_purpose_store.dart';
import 'package:nook/features/onboarding/bloc/purpose_suggestions_cubit.dart';
import 'package:nook/features/onboarding/domain/get_purpose_suggestions_usecase.dart';

CafeSummary _cafe(String id, {bool featured = false, String? cover = 'x'}) =>
    CafeSummary(
      id: id,
      name: 'Cafe $id',
      rating: 4.5,
      isFeatured: featured,
      coverImage: cover,
    );

class _Repo implements ICafeRepository {
  _Repo(this.byTags);

  /// Tag set (joined) → result; a missing key returns nothing.
  final Map<String, Object> byTags;
  final List<CafeQuery> queries = [];
  List<CafeSummary>? warmed;

  @override
  Future<List<CafeSummary>> getCafes(CafeQuery query) async {
    queries.add(query);
    final r = byTags[query.tags.join('+')];
    if (r is Exception) throw r;
    return (r as List<CafeSummary>?) ?? const [];
  }

  @override
  Future<void> warmCache(List<CafeSummary> summaries) async {
    warmed = summaries;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

Position _at(double lat, double lng) => Position(
  latitude: lat,
  longitude: lng,
  timestamp: DateTime(2026),
  accuracy: 1,
  altitude: 0,
  altitudeAccuracy: 0,
  heading: 0,
  headingAccuracy: 0,
  speed: 0,
  speedAccuracy: 0,
);

const LocationAccess _denied = (
  servicesOff: false,
  denied: true,
  deniedForever: false,
);
const LocationAccess _granted = (
  servicesOff: false,
  denied: false,
  deniedForever: false,
);

void main() {
  group('GetPurposeSuggestionsUseCase', () {
    GetPurposeSuggestionsUseCase useCase(
      _Repo repo, {
      LocationAccess access = _denied,
      Future<Position?> Function()? position,
    }) => GetPurposeSuggestionsUseCase(
      repo,
      locationAccess: () async => access,
      firstPosition: position ?? () async => null,
      positionTimeout: const Duration(milliseconds: 50),
    );

    test('work: laptop-friendly first, topped up from the fallbacks', () async {
      final repo = _Repo({
        'Free WiFi+Power Outlets': [_cafe('a')],
        'Free WiFi': [_cafe('a'), _cafe('b')],
        '': [_cafe('c'), _cafe('d')],
      });
      final cafes = await useCase(repo)(OnboardingPurpose.work);
      expect(cafes.map((c) => c.id), ['a', 'b', 'c']);
      expect(repo.warmed!.map((c) => c.id), ['a', 'b', 'c']);
    });

    test('without a granted location: top rated, never a position', () async {
      var asked = false;
      final repo = _Repo({});
      await useCase(
        repo,
        position: () async {
          asked = true;
          return null;
        },
      )(OnboardingPurpose.date);
      expect(asked, isFalse);
      expect(repo.queries.map((q) => q.sort).toSet(), {'top_rated'});
      expect(repo.queries.map((q) => q.tags), [
        ['Date Spot'],
        ['Group Hangout'],
        <String>[],
      ]);
    });

    test('with a granted location: nearest first from the position', () async {
      final repo = _Repo({});
      await useCase(
        repo,
        access: _granted,
        position: () async => _at(10.3, 123.9),
      )(OnboardingPurpose.specialty);
      expect(repo.queries.map((q) => q.sort).toSet(), {'nearby'});
      expect(repo.queries.first.lat, 10.3);
      expect(repo.queries.first.tags, ['Specialty Coffee']);
    });

    test('a slow position falls back to top rated', () async {
      final repo = _Repo({});
      await useCase(
        repo,
        access: _granted,
        position: () => Completer<Position?>().future,
      )(OnboardingPurpose.exploring);
      expect(repo.queries.single.sort, 'top_rated');
    });

    test('one query failing is skipped', () async {
      final repo = _Repo({
        'Specialty Coffee': Exception('boom'),
        '': [_cafe('x')],
      });
      final cafes = await useCase(repo)(OnboardingPurpose.specialty);
      expect(cafes.map((c) => c.id), ['x']);
    });

    test('every query failing throws', () async {
      final repo = _Repo({'': Exception('offline')});
      expect(
        () => useCase(repo)(OnboardingPurpose.exploring),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('rankSuggestions', () {
    test('photos first, query order kept otherwise', () {
      final ranked = rankSuggestions(OnboardingPurpose.work, [
        _cafe('a', cover: null),
        _cafe('b'),
        _cafe('c'),
      ]);
      expect(ranked.map((c) => c.id), ['b', 'c', 'a']);
    });

    test('exploring puts House picks first', () {
      final ranked = rankSuggestions(OnboardingPurpose.exploring, [
        _cafe('a'),
        _cafe('b', featured: true, cover: null),
      ]);
      expect(ranked.map((c) => c.id), ['b', 'a']);
    });
  });

  group('PurposeSuggestionsCubit', () {
    test('loaded with cafes', () async {
      final cubit = PurposeSuggestionsCubit((_) async => [_cafe('a')]);
      await cubit.load(OnboardingPurpose.work);
      expect(cubit.state.status, PurposeSuggestionsStatus.loaded);
      expect(cubit.state.purpose, OnboardingPurpose.work);
      expect(cubit.state.cafes.single.id, 'a');
      await cubit.close();
    });

    test('empty, an error or a timeout all end in failed', () async {
      for (final loader in <PurposeSuggestionsLoader>[
        (_) async => const [],
        (_) async => throw Exception('offline'),
        (_) => Completer<List<CafeSummary>>().future,
      ]) {
        final cubit = PurposeSuggestionsCubit(
          loader,
          timeout: const Duration(milliseconds: 20),
        );
        await cubit.load(OnboardingPurpose.date);
        expect(cubit.state.status, PurposeSuggestionsStatus.failed);
        await cubit.close();
      }
    });
  });
}
