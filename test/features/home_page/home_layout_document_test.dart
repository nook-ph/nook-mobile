import 'package:flutter_test/flutter_test.dart';
import 'package:nook/core/preferences/onboarding_purpose_store.dart';
import 'package:nook/features/home_page/domain/home_layout.dart';
import 'package:nook/features/home_page/domain/home_layout_plan.dart';
import 'package:nook/features/home_page/domain/home_rail_order.dart';

Map<String, Object?> _rpc(Map<String, Object?> document) => {
  'version': 'v1',
  'published_at': '2026-10-16T00:00:00+08:00',
  'document': {'schema': 1, ...document},
};

HomeLayout _layout(
  List<Map<String, Object?>> sections, {
  bool? purpose,
  bool? pinTop,
}) => HomeLayout.fromRpc(
  _rpc({'sections': sections, 'respect_purpose': ?purpose, 'pin_top': ?pinTop}),
)!;

/// Manila wall clock as an instant.
DateTime _manila(int y, int m, int d, [int h = 0, int min = 0]) =>
    DateTime.utc(y, m, d, h, min).subtract(manilaOffset);

final _allRails = HomeRail.values.toSet();

void main() {
  group('HomeLayout.fromRpc', () {
    test('null, non-maps and missing documents mean the built-in Home', () {
      expect(HomeLayout.fromRpc(null), isNull);
      expect(HomeLayout.fromRpc('nope'), isNull);
      expect(HomeLayout.fromRpc([1, 2]), isNull);
      expect(HomeLayout.fromRpc({'version': 'v1'}), isNull);
      expect(
        HomeLayout.fromRpc({
          'document': {'schema': 1},
        }),
        isNull,
      );
    });

    test('a schema above 1 (or none) is not read', () {
      expect(HomeLayout.fromRpc(_rpc({'schema': 2})), isNull);
      expect(
        HomeLayout.fromRpc({'version': 'v', 'document': <String, Object>{}}),
        isNull,
      );
      expect(HomeLayout.fromRpc(_rpc({'schema': '1'})), isNull);
    });

    test('reads the contract example', () {
      final layout = HomeLayout.fromRpc(
        _rpc({
          'respect_purpose': true,
          'banner': {
            'enabled': true,
            'title': 'Cebu Coffee Crawl this Saturday',
            'body': 'Five cafes, one stamp card.',
            'image_url': 'https://example.com/a.jpg',
            'cta_label': 'See the crawl',
            'link': 'nook://c/ABC123',
            'schedule': {
              'starts_at': '2026-10-20T00:00:00+08:00',
              'ends_at': '2026-10-26T23:59:00+08:00',
            },
          },
          'sections': [
            {'id': 'your_places', 'type': 'builtin', 'visible': true},
            {
              'id': 'featured',
              'type': 'builtin',
              'title': 'House picks',
              'cafe_ids': ['a', 'b'],
            },
            {
              'id': 'custom:3f1c',
              'type': 'custom',
              'title': 'Rainy-day cafes',
              'source': 'picked',
              'cafe_ids': ['a', 'b', 'c'],
              'schedule': {
                'days': [6, 7],
                'hours': {'from': '07:00', 'to': '12:00'},
              },
            },
            {
              'id': 'custom:9a2b',
              'type': 'custom',
              'title': 'Open late',
              'source': 'rule',
              'rule': {'tag': 'Open Late', 'sort': 'top_rated', 'limit': 10},
            },
            {'id': 'local_beans', 'type': 'builtin', 'visible': false},
          ],
        }),
      )!;

      expect(layout.version, 'v1');
      expect(layout.respectPurpose, isTrue);
      expect(layout.banner!.title, 'Cebu Coffee Crawl this Saturday');
      expect(layout.banner!.link.toString(), 'nook://c/ABC123');
      expect(
        layout.banner!.dismissKey('v1'),
        'v1|Cebu Coffee Crawl this Saturday',
      );
      expect(layout.banner!.id, isNull);
      expect(
        [for (final s in layout.sections) s.id],
        [
          'your_places',
          'featured',
          'custom:3f1c',
          'custom:9a2b',
          'local_beans',
        ],
      );
      final featured = layout.sections[1];
      expect(featured.builtin, HomeBuiltin.featured);
      expect(featured.cafeIds, ['a', 'b']);
      final picked = layout.sections[2];
      expect(picked.isCustom, isTrue);
      expect(picked.source, HomeShelfSource.picked);
      expect(picked.railId, 'custom:3f1c');
      expect(picked.schedule.days, {6, 7});
      expect(picked.schedule.fromMinute, 7 * 60);
      final rule = layout.sections[3].rule!;
      expect((rule.tag, rule.sort, rule.limit), ('Open Late', 'top_rated', 10));
      expect(layout.sections[4].visible, isFalse);
    });

    test('ignores unknown fields, unknown builtins and broken entries', () {
      final layout = HomeLayout.fromRpc(
        _rpc({
          'future_knob': {'x': 1},
          'banner': {'enabled': true}, // no title
          'sections': [
            {'id': 'stories', 'type': 'builtin'}, // a later app's shelf
            {'id': 'newest', 'type': 'carousel'}, // unknown type
            'not a map',
            {'type': 'builtin'}, // no id
            {
              'id': 'custom:a',
              'type': 'custom',
              'source': 'picked',
            }, // no title
            {
              'id': 'custom:b',
              'type': 'custom',
              'title': 'B',
              'source': 'rule',
            }, // no rule
            {
              'id': 'custom:c',
              'type': 'custom',
              'title': 'C',
              'source': 'weird',
            },
            {'id': 'trending', 'type': 'builtin', 'extra': true},
            {'id': 'trending', 'type': 'builtin', 'visible': false}, // dup
          ],
        }),
      )!;
      expect(layout.banner, isNull);
      expect([for (final s in layout.sections) s.id], ['trending']);
      expect(layout.sections.single.visible, isTrue);
    });

    test('a disabled banner, or one with a bad link, is handled', () {
      expect(
        HomeLayout.fromRpc(
          _rpc({
            'banner': {'enabled': false, 'title': 'Hi'},
          }),
        )!.banner,
        isNull,
      );
      final banner = HomeLayout.fromRpc(
        _rpc({
          'banner': {'title': 'Hi', 'link': 'javascript:alert(1)'},
        }),
      )!.banner!;
      expect(banner.link, isNull);
      expect(HomeBanner.parseLink('https://www.nookph.app/u/cris'), isNotNull);
      expect(HomeBanner.parseLink('http://example.com'), isNull);
    });

    test('rule sort and limit are clamped to the contract', () {
      final layout = _layout([
        {
          'id': 'custom:r',
          'type': 'custom',
          'title': 'R',
          'source': 'rule',
          'rule': {'tag': 'Free WiFi', 'sort': 'random', 'limit': 99},
        },
      ]);
      final rule = layout.sections.single.rule!;
      expect(rule.sort, 'top_rated');
      expect(rule.limit, 20);
    });

    test('cafe ids are deduped and truncated to 30', () {
      final layout = _layout([
        {
          'id': 'featured',
          'type': 'builtin',
          'cafe_ids': ['a', 'a', 7, '', for (var i = 0; i < 40; i++) 'c$i'],
        },
      ]);
      final ids = layout.sections.single.cafeIds;
      expect(ids.first, 'a');
      expect(ids, hasLength(30));
    });

    test('at most 20 sections and 12 custom shelves', () {
      final layout = _layout([
        for (var i = 0; i < 30; i++)
          {
            'id': 'custom:$i',
            'type': 'custom',
            'title': 'S$i',
            'source': 'picked',
            'cafe_ids': ['a'],
          },
      ]);
      expect(layout.sections, hasLength(12));
    });
  });

  group('HomeSchedule', () {
    test('no schedule is always on', () {
      expect(HomeSchedule.always.isActiveAt(DateTime.now()), isTrue);
    });

    test('starts_at and ends_at bound the instant', () {
      final s = HomeSchedule.tryParse({
        'starts_at': '2026-10-20T00:00:00+08:00',
        'ends_at': '2026-10-26T23:59:00+08:00',
      })!;
      expect(s.isActiveAt(_manila(2026, 10, 19, 23, 59)), isFalse);
      expect(s.isActiveAt(_manila(2026, 10, 20, 0, 0)), isTrue);
      expect(s.isActiveAt(_manila(2026, 10, 26, 23, 59)), isTrue);
      expect(s.isActiveAt(_manila(2026, 10, 27, 0, 0)), isFalse);
    });

    test('an end written as HH:MM:59.999 shows through that minute', () {
      final s = HomeSchedule.tryParse({
        'starts_at': '2026-10-20T00:00:00+08:00',
        'ends_at': '2026-10-26T23:59:59.999+08:00',
      })!;
      expect(s.endsAt, DateTime.utc(2026, 10, 26, 15, 59, 59, 999));
      final lastMs = DateTime.utc(2026, 10, 26, 15, 59, 59, 999);
      expect(s.isActiveAt(_manila(2026, 10, 26, 23, 59)), isTrue);
      expect(s.isActiveAt(lastMs), isTrue);
      expect(
        s.isActiveAt(lastMs.add(const Duration(milliseconds: 1))),
        isFalse,
      );
    });

    test('days are Manila weekdays, 1 = Monday', () {
      final weekend = HomeSchedule.tryParse({
        'days': [6, 7],
      })!;
      // 2026-10-17 is a Saturday. 23:30 UTC Friday is already Saturday in
      // Manila.
      expect(weekend.isActiveAt(_manila(2026, 10, 17, 9)), isTrue);
      expect(weekend.isActiveAt(_manila(2026, 10, 19, 9)), isFalse);
      expect(weekend.isActiveAt(DateTime.utc(2026, 10, 16, 23, 30)), isTrue);
      expect(weekend.isActiveAt(DateTime.utc(2026, 10, 16, 15, 30)), isFalse);
    });

    test('hours are a half-open window in Manila', () {
      final morning = HomeSchedule.tryParse({
        'hours': {'from': '07:00', 'to': '12:00'},
      })!;
      expect(morning.isActiveAt(_manila(2026, 10, 16, 6, 59)), isFalse);
      expect(morning.isActiveAt(_manila(2026, 10, 16, 7)), isTrue);
      expect(morning.isActiveAt(_manila(2026, 10, 16, 11, 59)), isTrue);
      expect(morning.isActiveAt(_manila(2026, 10, 16, 12)), isFalse);
    });

    test('a window past midnight belongs to the day it started', () {
      final fridayNight = HomeSchedule.tryParse({
        'days': [5],
        'hours': {'from': '22:00', 'to': '02:00'},
      })!;
      // Friday 2026-10-16.
      expect(fridayNight.isActiveAt(_manila(2026, 10, 16, 23)), isTrue);
      expect(fridayNight.isActiveAt(_manila(2026, 10, 17, 1, 30)), isTrue);
      expect(fridayNight.isActiveAt(_manila(2026, 10, 17, 2)), isFalse);
      expect(fridayNight.isActiveAt(_manila(2026, 10, 16, 1)), isFalse);
      expect(fridayNight.isActiveAt(_manila(2026, 10, 16, 21, 59)), isFalse);
    });

    test('unreadable parts fall back to open', () {
      final s = HomeSchedule.tryParse({
        'starts_at': 'not a date',
        'days': [0, 8, 'x'],
        'hours': {'from': '25:00', 'to': '10:00'},
      })!;
      expect(s.startsAt, isNull);
      expect(s.days, isEmpty);
      expect(s.fromMinute, isNull);
      expect(s.isActiveAt(_manila(2026, 10, 16, 3)), isTrue);
    });
  });

  group('planHomeSlots', () {
    final now = _manila(2026, 10, 16, 12);

    List<String> ids(List<HomeSlot> slots) => [for (final s in slots) '$s'];

    test('no layout is today\'s order, purpose shelf first', () {
      for (final purpose in [null, ...OnboardingPurpose.values]) {
        final legacy = orderHomeRails(purpose, available: _allRails);
        expect(
          ids(
            planHomeSlots(
              layout: null,
              purpose: purpose,
              available: _allRails,
              now: now,
            ),
          ),
          ['your_places', for (final r in legacy) builtinFor(r).id],
          reason: '$purpose',
        );
      }
    });

    test(
      'a layout with no sections (reset to default) is the built-in order',
      () {
        final layout = HomeLayout.fromRpc(_rpc({'sections': <Object>[]}))!;
        expect(
          ids(
            planHomeSlots(
              layout: layout,
              purpose: OnboardingPurpose.work,
              available: _allRails,
              now: now,
            ),
          ),
          ids(defaultHomeSlots(OnboardingPurpose.work, available: _allRails)),
        );
      },
    );

    test('layout order first, missing builtins appended in default order', () {
      final layout = _layout([
        {'id': 'newest', 'type': 'builtin'},
        {'id': 'featured', 'type': 'builtin', 'title': 'Editor picks'},
        {'id': 'your_places', 'type': 'builtin'},
        {
          'id': 'custom:x',
          'type': 'custom',
          'title': 'X',
          'source': 'picked',
          'cafe_ids': ['a'],
        },
        {'id': 'laptop_friendly', 'type': 'builtin', 'visible': false},
      ], pinTop: false);
      final slots = planHomeSlots(
        layout: layout,
        purpose: null,
        available: _allRails,
        now: now,
      );
      expect(ids(slots), [
        'newest',
        'featured',
        'your_places',
        'custom:x',
        'nearby',
        'specialty',
        'local_beans',
        'trending',
        'top_rated',
      ]);
      expect(slots[1].titleOverride, 'Editor picks');
      expect(slots[4].titleOverride, isNull);
    });

    test('out-of-schedule sections are left out', () {
      final layout = _layout([
        {
          'id': 'custom:weekend',
          'type': 'custom',
          'title': 'Weekend',
          'source': 'picked',
          'cafe_ids': ['a'],
          'schedule': {
            'days': [6, 7],
          },
        },
        {
          'id': 'trending',
          'type': 'builtin',
          'schedule': {'ends_at': '2026-01-01T00:00:00+08:00'},
        },
      ]);
      // Friday.
      final slots = ids(
        planHomeSlots(
          layout: layout,
          purpose: null,
          available: _allRails,
          now: now,
        ),
      );
      expect(slots, isNot(contains('custom:weekend')));
      // Mentioned but scheduled off: not appended back either.
      expect(slots, isNot(contains('trending')));
      // Saturday.
      expect(
        ids(
          planHomeSlots(
            layout: layout,
            purpose: null,
            available: _allRails,
            now: _manila(2026, 10, 17, 12),
          ),
        ).first,
        'custom:weekend',
      );
    });

    test(
      'respect_purpose moves the purpose shelf up, below a leading Your places',
      () {
        final sections = [
          {'id': 'your_places', 'type': 'builtin'},
          {'id': 'newest', 'type': 'builtin'},
          {'id': 'laptop_friendly', 'type': 'builtin'},
        ];
        expect(
          ids(
            planHomeSlots(
              layout: _layout(sections, pinTop: false),
              purpose: OnboardingPurpose.work,
              available: _allRails,
              now: now,
            ),
          ).take(3),
          ['your_places', 'laptop_friendly', 'newest'],
        );
        expect(
          ids(
            planHomeSlots(
              layout: _layout(sections, purpose: false, pinTop: false),
              purpose: OnboardingPurpose.work,
              available: _allRails,
              now: now,
            ),
          ).take(3),
          ['your_places', 'newest', 'laptop_friendly'],
        );
      },
    );

    test(
      'a hidden purpose shelf stays hidden; the next purpose shelf leads',
      () {
        final layout = _layout([
          {'id': 'newest', 'type': 'builtin'},
          {'id': 'specialty', 'type': 'builtin', 'visible': false},
        ]);
        final slots = ids(
          planHomeSlots(
            layout: layout,
            purpose: OnboardingPurpose.specialty,
            available: _allRails,
            now: now,
          ),
        );
        expect(slots.first, 'local_beans');
        expect(slots, isNot(contains('specialty')));
      },
    );
  });

  group('pin_top', () {
    final now = _manila(2026, 10, 16, 12);
    List<String> plan(HomeLayout layout, {Set<HomeRail>? available}) => [
      for (final s in planHomeSlots(
        layout: layout,
        purpose: null,
        available: available ?? _allRails,
        now: now,
      ))
        '$s',
    ];

    test('is on by default and parsed from the document', () {
      expect(_layout(const []).pinTop, isTrue);
      expect(_layout(const [], pinTop: false).pinTop, isFalse);
    });

    test('pulls Your places and Near you into the first three', () {
      final layout = _layout([
        {'id': 'newest', 'type': 'builtin'},
        {'id': 'featured', 'type': 'builtin'},
        {
          'id': 'custom:x',
          'type': 'custom',
          'title': 'X',
          'source': 'picked',
          'cafe_ids': ['a'],
        },
        {'id': 'trending', 'type': 'builtin'},
        {'id': 'your_places', 'type': 'builtin'},
        {'id': 'nearby', 'type': 'builtin'},
      ]);
      expect(plan(layout), [
        'newest',
        'your_places',
        'nearby',
        'featured',
        'custom:x',
        'trending',
        'specialty',
        'local_beans',
        'laptop_friendly',
        'top_rated',
      ]);
    });

    test('moves nothing when both already lead', () {
      final layout = _layout([
        {'id': 'featured', 'type': 'builtin'},
        {'id': 'nearby', 'type': 'builtin'},
        {'id': 'your_places', 'type': 'builtin'},
        {'id': 'newest', 'type': 'builtin'},
      ]);
      expect(plan(layout).take(4), [
        'featured',
        'nearby',
        'your_places',
        'newest',
      ]);
    });

    test('Near you with no cafes (no position) stays put', () {
      final layout = _layout([
        {'id': 'newest', 'type': 'builtin'},
        {'id': 'featured', 'type': 'builtin'},
        {'id': 'trending', 'type': 'builtin'},
        {'id': 'top_rated', 'type': 'builtin'},
        {'id': 'nearby', 'type': 'builtin'},
        {'id': 'your_places', 'type': 'builtin'},
      ]);
      final slots = plan(
        layout,
        available: _allRails.difference({HomeRail.nearby}),
      );
      expect(slots.take(3), ['newest', 'featured', 'your_places']);
      expect(slots.indexOf('nearby'), 5);
    });

    test('a hidden Near you is not brought back', () {
      final layout = _layout([
        {'id': 'newest', 'type': 'builtin'},
        {'id': 'featured', 'type': 'builtin'},
        {'id': 'trending', 'type': 'builtin'},
        {'id': 'nearby', 'type': 'builtin', 'visible': false},
      ]);
      expect(plan(layout), isNot(contains('nearby')));
    });

    test('pin_top false keeps the document order', () {
      final layout = _layout([
        {'id': 'newest', 'type': 'builtin'},
        {'id': 'featured', 'type': 'builtin'},
        {'id': 'trending', 'type': 'builtin'},
        {'id': 'nearby', 'type': 'builtin'},
        {'id': 'your_places', 'type': 'builtin'},
      ], pinTop: false);
      expect(plan(layout).take(5), [
        'newest',
        'featured',
        'trending',
        'nearby',
        'your_places',
      ]);
    });
  });
}
