import 'package:flutter/foundation.dart';
import 'package:nook/core/cafe/domain/entities/cafe_summary.dart';
import 'package:nook/features/home_page/domain/home_layout.dart';
import 'package:nook/features/home_page/domain/use_cases/get_cafe_summaries_usecase.dart';

/// Debug builds only: run with
/// `--dart-define=NOOK_HOME_LAYOUT_FIXTURE=true` to draw Home from
/// [homeLayoutFixture] instead of `get_home_layout()`. [kDebugMode] is a
/// constant, so in profile and release this is always false and the fixture
/// is compiled out.
const bool homeLayoutFixtureEnabled =
    kDebugMode && bool.fromEnvironment('NOOK_HOME_LAYOUT_FIXTURE');

/// A layout that shows every feature of the contract at once, built from
/// the loaded feed so its cafe ids are real:
///
/// - the banner, linking to a sorted search;
/// - House picks renamed, hand-picked (three top rated cafes, reversed);
/// - a custom picked shelf and a custom rule shelf (tag Specialty Coffee);
/// - a shelf scheduled on now, and one scheduled off (never shown);
/// - shelves reordered (Fresh on Nook first, Your places after House
///   picks), Laptop-friendly hidden, the rest appended in default order.
HomeLayout homeLayoutFixture(HomeFeedResult feed) {
  List<String> ids(List<CafeSummary> cafes, int n) => [
    for (final c in cafes.take(n)) c.id,
  ];

  final top = ids(feed.topRated, 3).reversed.toList();
  final picked = ids(feed.newest.skip(3).toList(), 4);
  final evening = ids(feed.trending.skip(2).toList(), 5);

  final layout = HomeLayout.fromRpc({
    'version': 'debug-fixture-1',
    'published_at': '2026-10-16T00:00:00+08:00',
    'document': {
      'schema': 1,
      'respect_purpose': false,
      'unknown_future_field': {'ignored': true},
      'banner': {
        'enabled': true,
        'title': 'Cebu Coffee Week is on',
        'body': 'Five days of cupping sessions and latte art throwdowns.',
        'image_url': feed.topRated.isEmpty
            ? null
            : feed.topRated.first.coverImage,
        'cta_label': 'See crowd favorites',
        'link': 'nook://search?sort=trending',
      },
      'sections': [
        {'id': 'newest', 'type': 'builtin', 'visible': true},
        {
          'id': 'featured',
          'type': 'builtin',
          'visible': true,
          'title': 'Editor’s picks',
          'cafe_ids': top,
        },
        {'id': 'your_places', 'type': 'builtin', 'visible': true},
        {
          'id': 'custom:debug-rainy',
          'type': 'custom',
          'visible': true,
          'title': 'Rainy-day cafes',
          'source': 'picked',
          'cafe_ids': picked,
        },
        {
          'id': 'custom:debug-tonight',
          'type': 'custom',
          'visible': true,
          'title': 'Open this week',
          'source': 'picked',
          'cafe_ids': evening,
          'schedule': {
            'starts_at': '2026-10-01T00:00:00+08:00',
            'ends_at': '2027-01-01T00:00:00+08:00',
          },
        },
        {
          'id': 'custom:debug-past',
          'type': 'custom',
          'visible': true,
          'title': 'Expired shelf (never shown)',
          'source': 'picked',
          'cafe_ids': picked,
          'schedule': {'ends_at': '2026-01-01T00:00:00+08:00'},
        },
        {
          'id': 'custom:debug-specialty',
          'type': 'custom',
          'visible': true,
          'title': 'Specialty, best rated',
          'source': 'rule',
          'rule': {'tag': 'Specialty Coffee', 'sort': 'top_rated', 'limit': 8},
        },
        {'id': 'laptop_friendly', 'type': 'builtin', 'visible': false},
        {'id': 'not_a_shelf_yet', 'type': 'builtin', 'visible': true},
      ],
    },
  });
  return layout!;
}
