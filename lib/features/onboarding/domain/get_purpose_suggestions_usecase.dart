import 'dart:async';

import 'package:geolocator/geolocator.dart';
import 'package:nook/core/cafe/domain/entities/cafe_query.dart';
import 'package:nook/core/cafe/domain/entities/cafe_summary.dart';
import 'package:nook/core/cafe/domain/repositories/i_cafe_repository.dart';
import 'package:nook/core/location/device_location.dart';
import 'package:nook/core/preferences/onboarding_purpose_store.dart';
import 'package:nook/features/home_page/domain/use_cases/get_cafe_summaries_usecase.dart';

/// The tag sets tried for a purpose, best match first. `get_cafes` matches
/// every tag in a set, so each set is one query. An untagged query always
/// follows, so a purpose with few tagged cafes still gets three.
List<List<String>> purposeTagSets(OnboardingPurpose purpose) =>
    switch (purpose) {
      OnboardingPurpose.work => const [
        laptopFriendlyTags,
        ['Free WiFi'],
      ],
      OnboardingPurpose.date => const [
        ['Date Spot'],
        ['Group Hangout'],
      ],
      OnboardingPurpose.specialty => const [
        [specialtyCoffeeTag],
        [localBeansTag],
      ],
      OnboardingPurpose.exploring => const [],
    };

/// Orders one query's cafes for a first impression: a cafe with a photo
/// before one without, and for "Just exploring" the House picks first.
/// Stable, so the query's own order (rating or distance) decides the rest.
List<CafeSummary> rankSuggestions(
  OnboardingPurpose purpose,
  List<CafeSummary> cafes,
) {
  int score(CafeSummary c) {
    final hasPhoto = (c.coverImage?.trim().isNotEmpty ?? false) ? 0 : 1;
    final featured = purpose == OnboardingPurpose.exploring && c.isFeatured
        ? 0
        : 1;
    return featured * 2 + hasPhoto;
  }

  final indexed = [for (var i = 0; i < cafes.length; i++) (i, cafes[i])];
  indexed.sort((a, b) {
    final byScore = score(a.$2).compareTo(score(b.$2));
    return byScore != 0 ? byScore : a.$1.compareTo(b.$1);
  });
  return [for (final e in indexed) e.$2];
}

/// The few cafes shown right after the onboarding purpose step.
///
/// Closest first when location is already granted (it never prompts), else
/// top rated. Every query runs at once; one failing is skipped, and only
/// when all of them failed is the first error thrown.
class GetPurposeSuggestionsUseCase {
  GetPurposeSuggestionsUseCase(
    this.repository, {
    Future<LocationAccess> Function()? locationAccess,
    Future<Position?> Function()? firstPosition,
    this.positionTimeout = const Duration(seconds: 2),
  }) : _locationAccess = locationAccess ?? DeviceLocation.instance.access,
       _firstPosition = firstPosition ?? DeviceLocation.instance.first;

  final ICafeRepository repository;
  final Future<LocationAccess> Function() _locationAccess;
  final Future<Position?> Function() _firstPosition;

  /// How long to wait for a position before ranking by rating instead.
  final Duration positionTimeout;

  Future<List<CafeSummary>> call(
    OnboardingPurpose purpose, {
    int count = 3,
  }) async {
    final at = await _position();
    final tagSets = [...purposeTagSets(purpose), const <String>[]];
    final failures = <Object>[];

    final results = await Future.wait([
      for (final tags in tagSets)
        repository
            .getCafes(
              CafeQuery(
                sort: at == null ? 'top_rated' : 'nearby',
                tags: tags,
                lat: at?.latitude,
                lng: at?.longitude,
                limit: 10,
              ),
            )
            .catchError((Object e) {
              failures.add(e);
              return <CafeSummary>[];
            }),
    ]);

    if (failures.length == tagSets.length) throw failures.first;

    final seen = <String>{};
    final picked = <CafeSummary>[];
    for (final cafes in results) {
      for (final cafe in rankSuggestions(purpose, cafes)) {
        if (picked.length >= count) break;
        if (cafe.id.isNotEmpty && seen.add(cafe.id)) picked.add(cafe);
      }
    }

    // So the cafe page opens on the summary already in hand.
    try {
      await repository.warmCache(picked);
    } catch (_) {}
    return picked;
  }

  Future<Position?> _position() async {
    try {
      final access = await _locationAccess();
      if (access.servicesOff || access.denied) return null;
      return await _firstPosition().timeout(positionTimeout);
    } catch (_) {
      return null;
    }
  }
}
