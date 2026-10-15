import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/core/analytics/retention_tracking_events.dart';
import 'package:nook/core/cafe/domain/entities/cafe_summary.dart';
import 'package:nook/core/cafe/domain/repositories/i_cafe_repository.dart';
import 'package:nook/core/cafe/domain/use_cases/get_cafe_statuses_usecase.dart';
import 'package:nook/core/cafe/domain/use_cases/set_cafe_status_usecase.dart';
import 'package:nook/core/cafe/presentation/cafe_status_cubit.dart';
import 'package:nook/core/preferences/onboarding_purpose_store.dart';
import 'package:nook/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:nook/features/guest_saves/data/guest_saves_store.dart';
import 'package:nook/features/guest_saves/presentation/cubit/guest_saves_cubit.dart';
import 'package:nook/features/guest_saves/presentation/cubit/recently_viewed_cubit.dart';
import 'package:nook/features/home_page/bloc/home_states.dart';
import 'package:nook/features/home_page/data/home_banner_dismiss_store.dart';
import 'package:nook/features/home_page/domain/home_layout.dart';
import 'package:nook/features/home_page/presentation/home_link.dart';
import 'package:nook/features/home_page/presentation/pages/home_page.dart';
import 'package:nook/features/home_page/presentation/widgets/home_banner_card.dart';
import 'package:nook/features/home_page/presentation/widgets/home_card_section.dart';
import 'package:nook/features/home_page/presentation/widgets/home_rail_impression.dart';
import 'package:nook/utils/theme/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/analytics/recording_analytics.dart';
import '../auth/fake_auth_bloc.dart';

class _NoRepository implements ICafeRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

List<CafeSummary> _cafes(String prefix, int n, {bool featured = false}) => [
  for (var i = 0; i < n; i++)
    CafeSummary(
      id: '$prefix$i',
      name: 'Cafe $prefix$i',
      rating: 4.5,
      reviewCount: 5,
      isFeatured: featured,
    ),
];

/// Every built-in shelf has cafes.
HomeLoadedState _state({
  OnboardingPurpose? purpose,
  HomeLayout? layout,
  Map<String, List<CafeSummary>> shelves = const {},
}) => HomeLoadedState(
  featuredCafes: _cafes('f', 4, featured: true),
  nearbyCafes: _cafes('n', 5),
  newestCafes: _cafes('w', 5),
  trendingCafes: _cafes('t', 5),
  topRatedCafes: _cafes('r', 5),
  specialtyNearbyCafes: _cafes('s', 5),
  laptopFriendlyCafes: _cafes('l', 5),
  localBeansCafes: _cafes('b', 5),
  purpose: purpose,
  layout: layout,
  layoutShelves: shelves,
);

/// Home's titles in the order the pre-layout Home drew them
/// (`_HomeContent` at 311bcbb): the purpose shelf first, then the rest in
/// [HomeRail] order. Your places is empty here, so it draws nothing.
const _legacyTitles = [
  'Near you',
  'House picks',
  'Specialty coffee near you',
  'Local beans',
  'Fresh on Nook',
  'Laptop-friendly',
  'Crowd favorites',
  'Highest rated',
];

/// Lets the "Announcement hidden" toast run out so no timer outlives the
/// test.
Future<void> settleToast(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 6));
  await tester.pumpAndSettle();
}

void main() {
  late GuestSavesCubit saves;
  late RecentlyViewedCubit recent;
  late FakeAuthBloc auth;
  late CafeStatusCubit statuses;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    HomeRailImpression.resetForTest();
    HomeBannerSlot.resetForTest();
    saves = GuestSavesCubit(store: GuestSavesStore());
    recent = RecentlyViewedCubit(store: RecentlyViewedStore());
    auth = FakeAuthBloc();
    final repository = _NoRepository();
    statuses = CafeStatusCubit(
      getCafeStatusesUseCase: GetCafeStatusesUseCase(repository),
      setCafeStatusUseCase: SetCafeStatusUseCase(repository),
    );
  });

  tearDown(() async {
    await saves.close();
    await recent.close();
    await auth.close();
    await statuses.close();
  });

  Future<void> pump(
    WidgetTester tester,
    HomeLoadedState state, {
    DateTime? now,
  }) async {
    tester.view.physicalSize = const Size(400, 8000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider.value(value: saves),
          BlocProvider.value(value: recent),
          BlocProvider<AuthBloc>.value(value: auth),
          BlocProvider.value(value: statuses),
        ],
        child: MaterialApp(
          theme: TAppTheme.lightTheme,
          home: Scaffold(
            body: SingleChildScrollView(
              child: HomeContent(
                state: state,
                isSignedIn: () => false,
                clock: () => now ?? DateTime.utc(2026, 10, 16, 4),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  List<String> titles(WidgetTester tester) => [
    for (final t in tester.widgetList<HomeSectionTitle>(
      find.byType(HomeSectionTitle),
    ))
      t.text,
  ];

  group('no layout', () {
    testWidgets('renders the same sections, in the same order, as before', (
      tester,
    ) async {
      await pump(tester, _state());
      expect(titles(tester), _legacyTitles);
      expect(find.byType(HomeBannerSlot), findsNothing);
    });

    testWidgets('keeps the purpose boost', (tester) async {
      await pump(tester, _state(purpose: OnboardingPurpose.work));
      expect(titles(tester).first, 'Laptop-friendly');
      expect(titles(tester).skip(1), [
        for (final t in _legacyTitles)
          if (t != 'Laptop-friendly') t,
      ]);
    });

    testWidgets('rail events carry no layout_version', (tester) async {
      final analytics = RecordingAnalytics.install(addTearDown);
      await pump(tester, _state());
      final props = analytics.propertiesOf(HomeRailEvents.impression)!;
      expect(props.containsKey('layout_version'), isFalse);
    });
  });

  group('with a layout', () {
    final layout = HomeLayout.fromRpc({
      'version': 'v7',
      'document': {
        'schema': 1,
        'respect_purpose': false,
        'banner': {
          'title': 'Cebu Coffee Week',
          'body': 'Five days of cupping.',
          'cta_label': 'See the list',
          'link': 'nook://search?sort=trending',
        },
        'sections': [
          {'id': 'newest', 'type': 'builtin'},
          {
            'id': 'featured',
            'type': 'builtin',
            'title': 'Editor picks',
            'cafe_ids': ['p0', 'p1'],
          },
          {
            'id': 'custom:rain',
            'type': 'custom',
            'title': 'Rainy-day cafes',
            'source': 'picked',
            'cafe_ids': ['c0', 'c1', 'c2'],
          },
          {
            'id': 'custom:two',
            'type': 'custom',
            'title': 'Too short',
            'source': 'picked',
            'cafe_ids': ['x0', 'x1'],
          },
          {
            'id': 'custom:sat',
            'type': 'custom',
            'title': 'Saturday only',
            'source': 'picked',
            'cafe_ids': ['c0', 'c1', 'c2'],
            'schedule': {
              'days': [6],
            },
          },
          {'id': 'laptop_friendly', 'type': 'builtin', 'visible': false},
        ],
      },
    })!;
    final shelves = {
      'featured': _cafes('p', 2),
      'custom:rain': _cafes('c', 3),
      'custom:two': _cafes('x', 2),
      'custom:sat': _cafes('c', 3),
    };

    testWidgets('orders, renames, hides and adds shelves', (tester) async {
      await pump(
        tester,
        _state(
          layout: layout,
          shelves: shelves,
          purpose: OnboardingPurpose.work,
        ),
      );
      expect(titles(tester), [
        'Fresh on Nook',
        // Pinned into the first three (Your places, empty here, is the
        // other pinned slot).
        'Near you',
        'Editor picks',
        'Rainy-day cafes',
        // Missing builtins in default order; Laptop-friendly hidden, no
        // purpose boost (respect_purpose false).
        'Specialty coffee near you',
        'Local beans',
        'Crowd favorites',
        'Highest rated',
      ]);
      expect(find.text('Cafe p0'), findsOneWidget);
      expect(find.text('Cafe f0'), findsNothing);
    });

    testWidgets('pin_top false keeps Near you where the document puts it', (
      tester,
    ) async {
      final raw = {
        'version': 'v8',
        'document': {
          'schema': 1,
          'respect_purpose': false,
          'pin_top': false,
          'sections': [
            {'id': 'newest', 'type': 'builtin'},
            {'id': 'featured', 'type': 'builtin'},
            {'id': 'trending', 'type': 'builtin'},
            {'id': 'nearby', 'type': 'builtin'},
          ],
        },
      };
      await pump(tester, _state(layout: HomeLayout.fromRpc(raw)));
      expect(titles(tester).take(4), [
        'Fresh on Nook',
        'House picks',
        'Crowd favorites',
        'Near you',
      ]);
    });

    testWidgets('custom shelves open their own page from See all', (
      tester,
    ) async {
      await pump(tester, _state(layout: layout, shelves: shelves));
      final section = tester.widget<HomeCafeSection>(
        find.widgetWithText(HomeCafeSection, 'Rainy-day cafes'),
      );
      expect(section.seeAllLocation, '/shelf/custom%3Arain');
      expect(find.bySemanticsLabel('Rainy-day cafes, see all'), findsOneWidget);
    });

    testWidgets('a scheduled shelf shows inside its window', (tester) async {
      // Saturday 10:00 Manila.
      await pump(
        tester,
        _state(layout: layout, shelves: shelves),
        now: DateTime.utc(2026, 10, 17, 2),
      );
      expect(titles(tester), contains('Saturday only'));
    });

    testWidgets(
      'featured falls back to automatic picks when its cafes failed',
      (tester) async {
        await pump(tester, _state(layout: layout, shelves: const {}));
        expect(titles(tester), contains('Editor picks'));
        expect(titles(tester), isNot(contains('Rainy-day cafes')));
        expect(find.text('Cafe f0'), findsOneWidget);
      },
    );

    testWidgets('banner shows, logs, dismisses and stays dismissed', (
      tester,
    ) async {
      final analytics = RecordingAnalytics.install(addTearDown);
      await pump(tester, _state(layout: layout, shelves: shelves));
      expect(find.text('Cebu Coffee Week'), findsOneWidget);
      expect(analytics.propertiesOf(HomeBannerEvents.shown), {
        'layout_version': 'v7',
        'link_type': 'nook',
        'style': 'card',
      });
      expect(
        analytics.propertiesOf(HomeRailEvents.impression)!['layout_version'],
        'v7',
      );

      await tester.tap(find.bySemanticsLabel('Close announcement'));
      await tester.pump();
      // Collapses over 200ms rather than jumping.
      expect(find.byType(AnimatedSize), findsOneWidget);
      await settleToast(tester);
      expect(find.text('Cebu Coffee Week'), findsNothing);
      expect(analytics.names, contains(HomeBannerEvents.dismissed));
      expect(await HomeBannerDismissStore().read(), {'v7|Cebu Coffee Week'});

      // A new Home (next launch) reads the dismissal.
      await tester.pumpWidget(const SizedBox());
      await pump(tester, _state(layout: layout, shelves: shelves));
      expect(find.text('Cebu Coffee Week'), findsNothing);
    });
  });

  group('banner undo and strip', () {
    final layout = HomeLayout.fromRpc({
      'version': 'v9',
      'document': {
        'schema': 1,
        'banner': {
          'title': 'Cebu Coffee Week',
          'cta_label': 'See the cafes',
          'link': 'nook://shelf/custom:week',
        },
        'sections': <Object>[],
      },
    })!;

    testWidgets('Undo on the toast brings the banner back', (tester) async {
      final analytics = RecordingAnalytics.install(addTearDown);
      await pump(tester, _state(layout: layout));
      await tester.tap(find.bySemanticsLabel('Close announcement'));
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }
      expect(find.text('Announcement hidden'), findsOneWidget);
      await tester.tap(find.text('Undo'));
      await settleToast(tester);
      expect(find.text('Cebu Coffee Week'), findsOneWidget);
      expect(analytics.names, contains(HomeBannerEvents.restored));
      expect(await HomeBannerDismissStore().read(), isEmpty);
    });

    testWidgets('an opened banner comes back as a one-line strip', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({
        'flutter.homeBannerTapped': ['v9|Cebu Coffee Week'],
      });
      await pump(tester, _state(layout: layout));
      expect(find.byType(HomeBannerStrip), findsOneWidget);
      expect(find.byType(HomeBannerCard), findsNothing);
      expect(find.text('See the cafes'), findsNothing);
      expect(find.bySemanticsLabel('Close announcement'), findsOneWidget);
    });
  });

  group('HomeBannerCard', () {
    Future<void> pumpCard(WidgetTester tester, double scale) async {
      tester.view.physicalSize = const Size(360, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: TAppTheme.lightTheme,
          home: MediaQuery(
            data: MediaQueryData(
              size: const Size(360, 1600),
              textScaler: TextScaler.linear(scale),
            ),
            child: Scaffold(
              body: Padding(
                padding: const EdgeInsets.all(20),
                child: HomeBannerCard(
                  banner: HomeBanner(
                    title: 'Cebu Coffee Week is on',
                    body: 'Five days of cupping sessions.',
                    ctaLabel: 'See crowd favorites',
                    imageUrl: 'https://example.com/x.jpg',
                    link: Uri.parse('nook://shelf/custom:week'),
                  ),
                  onTap: () {},
                  onDismiss: () {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('from text x1.6 the image sits above the copy', (tester) async {
      await pumpCard(tester, 1.0);
      expect(find.byType(AspectRatio), findsNothing);
      await pumpCard(tester, 1.6);
      expect(find.byType(AspectRatio), findsOneWidget);
      final image = tester.getRect(find.byType(AspectRatio));
      final title = tester.getRect(find.text('Cebu Coffee Week is on'));
      expect(image.bottom, lessThanOrEqualTo(title.top));
    });

    testWidgets('at text x2 the button label is not ellipsized', (
      tester,
    ) async {
      await pumpCard(tester, 2.0);
      final label = tester.renderObject<RenderParagraph>(
        find.text('See crowd favorites'),
      );
      expect(label.didExceedMaxLines, isFalse);
      final close = tester.getSize(find.bySemanticsLabel('Close announcement'));
      expect(close, const Size(48, 48));
    });

    for (final scale in [1.0, 2.0]) {
      for (final image in [false, true]) {
        testWidgets('fits a 360pt phone, image $image, text x$scale', (
          tester,
        ) async {
          tester.view.physicalSize = const Size(360, 1200);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          await tester.pumpWidget(
            MaterialApp(
              theme: TAppTheme.lightTheme,
              home: MediaQuery(
                data: MediaQueryData(
                  size: const Size(360, 1200),
                  textScaler: TextScaler.linear(scale),
                ),
                child: Scaffold(
                  body: Padding(
                    padding: const EdgeInsets.all(20),
                    child: HomeBannerCard(
                      banner: HomeBanner(
                        title:
                            'The Cebu Coffee Crawl is back this Saturday with '
                            'five new cafes on the route',
                        body: 'Five cafes, one stamp card, free cupping.',
                        ctaLabel: 'See the crawl',
                        imageUrl: image ? 'https://example.com/x.jpg' : null,
                        link: Uri.parse('nook://c/ABC123'),
                      ),
                      onTap: () {},
                      onDismiss: () {},
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pump();
          expect(tester.takeException(), isNull);
          final close = tester.getSize(
            find.bySemanticsLabel('Close announcement'),
          );
          expect(close.width, greaterThanOrEqualTo(44));
        });
      }
    }

    testWidgets('no link: no button and no CTA', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: TAppTheme.lightTheme,
          home: Scaffold(
            body: HomeBannerCard(
              banner: const HomeBanner(title: 'Hi', ctaLabel: 'Go'),
              onTap: null,
              onDismiss: () {},
            ),
          ),
        ),
      );
      expect(find.text('Go'), findsNothing);
    });
  });

  group('inAppLocation', () {
    test('nook:// maps to a router location', () {
      expect(inAppLocation(Uri.parse('nook://cafe/abc')), '/cafe/abc');
      expect(
        inAppLocation(Uri.parse('nook://search?sort=trending')),
        '/search?sort=trending',
      );
      expect(inAppLocation(Uri.parse('nook://c/ABC123')), '/c/ABC123');
    });

    test('nookph.app profile and crawl links stay in the app', () {
      expect(
        inAppLocation(Uri.parse('https://www.nookph.app/u/cris')),
        '/u/cris',
      );
      expect(
        inAppLocation(Uri.parse('https://www.nookph.app/c/ABC123?crew=X')),
        '/c/ABC123?crew=X',
      );
    });

    test('other https links open in the browser', () {
      expect(inAppLocation(Uri.parse('https://www.nookph.app/about')), isNull);
      expect(inAppLocation(Uri.parse('https://example.com/x')), isNull);
    });
  });
}
