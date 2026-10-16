import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:nook/core/analytics/retention_tracking_events.dart';
import 'package:nook/core/cafe/domain/entities/cafe_summary.dart';
import 'package:nook/features/home_page/data/home_layout_repository.dart';
import 'package:nook/features/home_page/domain/home_layout.dart';
import 'package:nook/features/home_page/domain/use_cases/get_home_shelf_usecase.dart';
import 'package:nook/features/home_page/presentation/home_link.dart';
import 'package:nook/features/home_page/presentation/pages/home_shelf_page.dart';
import 'package:nook/utils/theme/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/analytics/recording_analytics.dart';

CafeSummary _cafe(String id) =>
    CafeSummary(id: id, name: 'Cafe $id', rating: 4.5);

Map<String, Object?> _rpc(
  String version,
  List<Map<String, Object?>> sections,
) => {
  'version': version,
  'document': {'schema': 1, 'sections': sections},
};

final _sections = <Map<String, Object?>>[
  {
    'id': 'custom:week',
    'type': 'custom',
    // Made only for the banner: hidden on Home.
    'visible': false,
    'title': 'Coffee Week cafes',
    'source': 'picked',
    'cafe_ids': ['a', 'b', 'c'],
  },
  {
    'id': 'custom:spec',
    'type': 'custom',
    'title': 'Specialty, best rated',
    'source': 'rule',
    'rule': {'tag': 'Specialty Coffee', 'sort': 'top_rated', 'limit': 8},
  },
  {'id': 'newest', 'type': 'builtin'},
];

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('GetHomeShelfUseCase', () {
    late List<HomeLayout> loads;
    Map<String, List<CafeSummary>> answer = const {};

    Future<Map<String, List<CafeSummary>>> load(HomeLayout layout) async {
      loads.add(layout);
      return answer;
    }

    setUp(() {
      loads = [];
      answer = const {};
    });

    test('a hidden picked shelf opens, with the cafes Home loaded', () async {
      final current = CurrentHomeLayout()
        ..layout = HomeLayout.fromRpc(_rpc('v1', _sections))
        ..shelves = {
          'custom:week': [_cafe('a'), _cafe('b'), _cafe('c')],
        };
      final shelf = await GetHomeShelfUseCase(
        current: current,
        loadShelves: load,
      )('custom:week');
      expect(shelf!.title, 'Coffee Week cafes');
      expect(shelf.cafes.map((c) => c.id), ['a', 'b', 'c']);
      expect(loads, isEmpty);
    });

    test('a picked shelf Home did not load is fetched, as visible', () async {
      answer = {
        'custom:week': [_cafe('a')],
      };
      final current = CurrentHomeLayout()
        ..layout = HomeLayout.fromRpc(_rpc('v1', _sections));
      final shelf = await GetHomeShelfUseCase(
        current: current,
        loadShelves: load,
      )('custom:week');
      expect(shelf!.cafes.single.id, 'a');
      expect(loads.single.sections.single.visible, isTrue);
      expect(loads.single.sections.single.cafeIds, ['a', 'b', 'c']);
    });

    test('a rule shelf asks again for a full page', () async {
      answer = {
        'custom:spec': [_cafe('s')],
      };
      final current = CurrentHomeLayout()
        ..layout = HomeLayout.fromRpc(_rpc('v1', _sections));
      await GetHomeShelfUseCase(current: current, loadShelves: load)(
        'custom:spec',
      );
      final rule = loads.single.sections.single.rule!;
      expect(rule.tag, 'Specialty Coffee');
      expect(rule.sort, 'top_rated');
      expect(rule.limit, GetHomeShelfUseCase.pageLimit);
    });

    test('unknown ids and plain builtins have no page', () async {
      final current = CurrentHomeLayout()
        ..layout = HomeLayout.fromRpc(_rpc('v1', _sections));
      final use = GetHomeShelfUseCase(current: current, loadShelves: load);
      expect(await use('custom:nope'), isNull);
      expect(await use('newest'), isNull);
      expect(
        await GetHomeShelfUseCase(
          current: CurrentHomeLayout(),
          loadShelves: load,
        )('custom:week'),
        isNull,
      );
    });

    test('a failed load throws, for the page to offer Try again', () async {
      final current = CurrentHomeLayout()
        ..layout = HomeLayout.fromRpc(_rpc('v1', _sections));
      expect(
        GetHomeShelfUseCase(current: current, loadShelves: load)('custom:spec'),
        throwsStateError,
      );
    });

    test('a shelf missing from the cached layout is looked up on the '
        'server', () async {
      final cache = HomeLayoutCache();
      var fetches = 0;
      final repository = HomeLayoutRepository(
        fetch: () async {
          fetches++;
          return _rpc('v2', _sections);
        },
        cache: cache,
      );
      answer = {
        'custom:week': [_cafe('a')],
      };
      final shelf = await GetHomeShelfUseCase(
        current: CurrentHomeLayout(),
        repository: repository,
        loadShelves: load,
      )('custom:week');
      expect(fetches, 1);
      expect(shelf!.cafes.single.id, 'a');
    });

    test('ids that can never be a shelf page are "not on Nook" without '
        'asking the server, even offline', () async {
      var fetches = 0;
      final repository = HomeLayoutRepository(
        fetch: () async {
          fetches++;
          throw Exception('offline');
        },
        cache: HomeLayoutCache(),
      );
      final use = GetHomeShelfUseCase(
        current: CurrentHomeLayout(),
        repository: repository,
        loadShelves: load,
      );
      expect(await use('laptop_friendly'), isNull);
      expect(await use('your_places'), isNull);
      expect(fetches, 0);
    });

    test('offline with the shelf not at hand throws (Try again), not '
        '"not on Nook"', () async {
      final repository = HomeLayoutRepository(
        fetch: () async => throw const SocketException('offline'),
        cache: HomeLayoutCache(),
      );
      expect(
        GetHomeShelfUseCase(
          current: CurrentHomeLayout(),
          repository: repository,
          loadShelves: load,
        )('custom:week'),
        throwsA(isA<SocketException>()),
      );
    });
  });

  group('links', () {
    test('nook://shelf/<id> is the shelf route, id encoded', () {
      expect(
        inAppLocation(Uri.parse('nook://shelf/custom:week')),
        '/shelf/custom%3Aweek',
      );
      expect(homeShelfLocation('custom:week'), '/shelf/custom%3Aweek');
    });

    test('built-in shelves that are a search open that search', () {
      expect(builtinShelfSearch('trending'), '/search?sort=trending');
      expect(
        builtinShelfSearch('specialty'),
        '/search?tag=Specialty+Coffee&sort=nearby',
      );
      expect(builtinShelfSearch('local_beans'), '/search?tag=Philippine+Beans');
      expect(builtinShelfSearch('custom:week'), isNull);
      expect(builtinShelfSearch('featured'), isNull);
    });

    testWidgets('the router decodes the id and passes the banner header', (
      tester,
    ) async {
      String? opened;
      HomeShelfHeader? header;
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, _) => TextButton(
              onPressed: () => openHomeLink(
                context,
                Uri.parse('nook://shelf/custom:week'),
                extra: const HomeShelfHeader(title: 'Coffee Week'),
              ),
              child: const Text('open'),
            ),
            routes: [
              GoRoute(
                path: 'shelf/:id',
                builder: (context, state) {
                  opened = state.pathParameters['id'];
                  header = state.extra as HomeShelfHeader?;
                  return const SizedBox();
                },
              ),
            ],
          ),
        ],
      );
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(opened, 'custom:week');
      expect(header?.title, 'Coffee Week');
    });

    testWidgets('a banner link to another page does not hand it the header', (
      tester,
    ) async {
      String? email = 'unset';
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, _) => TextButton(
              onPressed: () => openHomeLink(
                context,
                Uri.parse('nook://signup-details'),
                extra: const HomeShelfHeader(title: 'Join'),
              ),
              child: const Text('open'),
            ),
          ),
          GoRoute(
            path: '/signup-details',
            builder: (context, state) {
              // As app_router does.
              email = state.extra as String?;
              return const SizedBox();
            },
          ),
        ],
      );
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(email, isNull);
    });
  });

  group('HomeShelfPage', () {
    Future<void> pumpPage(
      WidgetTester tester,
      Future<HomeShelf?> Function(String id) load, {
      HomeShelfHeader? header,
      double scale = 1,
    }) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: TAppTheme.lightTheme,
          home: MediaQuery(
            data: MediaQueryData(
              size: const Size(390, 844),
              textScaler: TextScaler.linear(scale),
            ),
            child: HomeShelfPage(
              sectionId: 'custom:week',
              header: header,
              load: load,
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
    }

    final section = HomeSection.tryParse(_sections.first)!;

    testWidgets('opened from a banner: its title and line, a count, the '
        'cafes', (tester) async {
      final analytics = RecordingAnalytics.install(addTearDown);
      await pumpPage(
        tester,
        (_) async =>
            HomeShelf(section: section, cafes: [_cafe('a'), _cafe('b')]),
        header: const HomeShelfHeader(
          title: 'Cebu Coffee Week is on',
          body: 'Five days of cupping.',
        ),
      );
      expect(find.text('Cebu Coffee Week is on'), findsOneWidget);
      expect(find.text('Five days of cupping.'), findsOneWidget);
      expect(find.text('Coffee Week cafes'), findsNothing);
      expect(find.text('2 cafes'), findsOneWidget);
      expect(find.text('Cafe a'), findsOneWidget);
      expect(analytics.propertiesOf(HomeShelfEvents.opened), {
        'shelf': 'custom:week',
        'from_banner': true,
        'found': true,
        'cafes': 2,
      });
    });

    testWidgets('from See all: the shelf title', (tester) async {
      await pumpPage(
        tester,
        (_) async => HomeShelf(section: section, cafes: [_cafe('a')]),
      );
      expect(find.text('Coffee Week cafes'), findsOneWidget);
      expect(find.text('1 cafe'), findsOneWidget);
    });

    testWidgets('a shelf that is gone says so and offers Home', (tester) async {
      await pumpPage(tester, (_) async => null);
      expect(find.text('This shelf isn’t on Nook right now'), findsOneWidget);
      expect(find.text('Go to Home'), findsOneWidget);
    });

    testWidgets('a failed load offers Try again', (tester) async {
      var calls = 0;
      await pumpPage(tester, (_) async {
        calls++;
        throw Exception('offline');
      });
      expect(find.text('Try again'), findsOneWidget);
      await tester.tap(find.text('Try again'));
      await tester.pump();
      await tester.pump();
      expect(calls, 2);
    });

    testWidgets('a long title wraps at text x2 with nothing clipped', (
      tester,
    ) async {
      await pumpPage(
        tester,
        (_) async => HomeShelf(section: section, cafes: [_cafe('a')]),
        header: const HomeShelfHeader(
          title: 'The Cebu Coffee Crawl is back with five new cafes',
          body: 'Five cafes, one stamp card, free cupping on Saturday.',
        ),
        scale: 2,
      );
      expect(tester.takeException(), isNull);
      expect(find.bySemanticsLabel('Back'), findsOneWidget);
      expect(tester.getSize(find.bySemanticsLabel('Back')), const Size(48, 48));
    });
  });
}
