import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/core/cafe/domain/entities/cafe_summary.dart';
import 'package:nook/core/cafe/domain/repositories/i_cafe_repository.dart';
import 'package:nook/core/presentation/bottom_nav.dart';
import 'package:nook/core/utils/responsive_card_sizes.dart';
import 'package:nook/features/home_page/bloc/home_bloc.dart';
import 'package:nook/features/home_page/bloc/home_event.dart';
import 'package:nook/features/home_page/bloc/home_states.dart';
import 'package:nook/features/home_page/domain/use_cases/get_cafe_summaries_usecase.dart';
import 'package:nook/features/home_page/presentation/widgets/home_card_section.dart';
import 'package:nook/features/home_page/presentation/widgets/home_meta_line.dart';
import 'package:nook/features/home_page/presentation/widgets/home_tag_chip.dart';

class _NoRepository implements ICafeRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeFeed extends GetHomeFeedUseCase {
  _FakeFeed() : super(_NoRepository());

  HomeFeedWithLocationMeta result = (
    feed: (
      nearby: <CafeSummary>[],
      topRated: <CafeSummary>[],
      trending: <CafeSummary>[],
      newest: <CafeSummary>[],
    ),
    locationDenied: false,
    locationServicesOff: false,
  );
  Object? error;

  @override
  Stream<HomeFeedUpdate> watch({int page = 0, int limit = 20}) async* {
    final e = error;
    if (e != null) throw e;
    yield (data: result, nearbyPending: false);
  }
}

CafeSummary _cafe(String id, {bool featured = false}) =>
    CafeSummary(id: id, name: 'Cafe $id', rating: 4.5, isFeatured: featured);

void main() {
  group('homeMetaText', () {
    test('joins area and distance', () {
      expect(homeMetaText('IT Park', '492 m'), 'IT Park · 492 m');
    });

    test('drops an unknown distance without a trailing dot', () {
      expect(homeMetaText('IT Park', null), 'IT Park');
      expect(homeMetaText('IT Park', ' '), 'IT Park');
    });

    test('drops an unknown area', () {
      expect(homeMetaText('', '1.2 km'), '1.2 km');
    });
  });

  group('homeCardArea', () {
    test('prefers the neighbourhood, then the city, then the address', () {
      expect(
        homeCardArea(
          const CafeSummary(
            id: 'a',
            name: 'A',
            rating: 0,
            neighborhood: ' IT Park ',
            city: 'Cebu City',
            address: 'Somewhere 1',
          ),
        ),
        'IT Park',
      );
      expect(
        homeCardArea(
          const CafeSummary(
            id: 'a',
            name: 'A',
            rating: 0,
            neighborhood: ' ',
            city: 'Cebu City',
          ),
        ),
        'Cebu City',
      );
      expect(
        homeCardArea(
          const CafeSummary(id: 'a', name: 'A', rating: 0, address: 'Road 2'),
        ),
        'Road 2',
      );
    });
  });

  group('homeFeaturedTags', () {
    test('shows everything up to the limit', () {
      final split = homeFeaturedTags(['Free Wifi', 'Quick Coffee']);
      expect(split.shown, ['Free Wifi', 'Quick Coffee']);
      expect(split.more, 0);
    });

    test('folds the rest into a count and skips blanks', () {
      final split = homeFeaturedTags(['A', ' ', 'B', 'C', 'D']);
      expect(split.shown, ['A', 'B']);
      expect(split.more, 2);
    });
  });

  group('card widths', () {
    test('the featured card always leaves both gutters', () {
      for (final viewport in [320.0, 360.0, 390.0, 430.0]) {
        final width = ResponsiveCardSizes.featuredCardWidthFor(viewport);
        expect(width, viewport - 2 * ResponsiveCardSizes.homeGutter);
      }
    });

    test('the featured card is capped on wide screens', () {
      expect(ResponsiveCardSizes.featuredCardWidthFor(1024), 520);
    });

    test('a compact card fits a 360pt phone with the next one showing', () {
      final width = ResponsiveCardSizes.cafeCardWidthFor(360);
      expect(width, lessThan(360 - ResponsiveCardSizes.homeGutter));
      expect(ResponsiveCardSizes.cafeCardWidthFor(390).round(), 211);
    });
  });

  group('HomeBloc', () {
    test('loads nearby into its own list and reports services off', () async {
      final feed = _FakeFeed()
        ..result = (
          feed: (
            nearby: [_cafe('n1')],
            topRated: [_cafe('t1', featured: true)],
            trending: <CafeSummary>[],
            newest: [_cafe('new1')],
          ),
          locationDenied: false,
          locationServicesOff: true,
        );
      final bloc = HomeBloc(getHomeFeedUseCase: feed);
      addTearDown(bloc.close);

      bloc.add(LoadHomeDataEvent());
      final loaded =
          await bloc.stream.firstWhere((s) => s is HomeLoadedState)
              as HomeLoadedState;

      expect(loaded.nearbyCafes.map((c) => c.id), ['n1']);
      expect(loaded.featuredCafes.map((c) => c.id), ['t1']);
      expect(loaded.cafeIds, {'n1', 't1', 'new1'});
      expect(loaded.locationServicesOff, isTrue);
      expect(loaded.showLocationBanner, isTrue);
      expect(loaded.allEmpty, isFalse);
    });

    test('dismissing hides the banner and keeps the lists', () async {
      final feed = _FakeFeed()
        ..result = (
          feed: (
            nearby: <CafeSummary>[],
            topRated: [_cafe('t1')],
            trending: <CafeSummary>[],
            newest: <CafeSummary>[],
          ),
          locationDenied: true,
          locationServicesOff: false,
        );
      final bloc = HomeBloc(getHomeFeedUseCase: feed);
      addTearDown(bloc.close);

      bloc.add(LoadHomeDataEvent());
      final loaded =
          await bloc.stream.firstWhere((s) => s is HomeLoadedState)
              as HomeLoadedState;
      expect(loaded.showLocationBanner, isTrue);

      bloc.add(HomeDismissLocationBannerEvent());
      final dismissed = await bloc.stream.first as HomeLoadedState;
      expect(dismissed.showLocationBanner, isFalse);
      expect(identical(dismissed.topRatedCafes, loaded.topRatedCafes), isTrue);
    });

    test('a refresh over a loaded feed never shows the skeleton', () async {
      final feed = _FakeFeed()
        ..result = (
          feed: (
            nearby: <CafeSummary>[],
            topRated: [_cafe('t1')],
            trending: <CafeSummary>[],
            newest: <CafeSummary>[],
          ),
          locationDenied: false,
          locationServicesOff: false,
        );
      final bloc = HomeBloc(getHomeFeedUseCase: feed);
      addTearDown(bloc.close);

      bloc.add(LoadHomeDataEvent());
      await bloc.stream.firstWhere((s) => s is HomeLoadedState);

      final emitted = <HomeState>[];
      final sub = bloc.stream.listen(emitted.add);
      bloc.add(LoadHomeDataEvent(refresh: true));
      await bloc.stream.first;
      await sub.cancel();

      expect(emitted, hasLength(1));
      expect(emitted.single, isA<HomeLoadedState>());
    });

    test('a failed refresh keeps the loaded feed and reports why', () async {
      final feed = _FakeFeed()
        ..result = (
          feed: (
            nearby: <CafeSummary>[],
            topRated: [_cafe('t1')],
            trending: <CafeSummary>[],
            newest: <CafeSummary>[],
          ),
          locationDenied: false,
          locationServicesOff: false,
        );
      final bloc = HomeBloc(getHomeFeedUseCase: feed);
      addTearDown(bloc.close);

      bloc.add(LoadHomeDataEvent());
      final loaded =
          await bloc.stream.firstWhere((s) => s is HomeLoadedState)
              as HomeLoadedState;
      expect(loaded.refreshError, isNull);

      final failure = Exception('down');
      feed.error = failure;
      bloc.add(LoadHomeDataEvent(refresh: true));
      final after = await bloc.stream.first;

      expect(after, isA<HomeLoadedState>());
      after as HomeLoadedState;
      expect(after.refreshError, same(failure));
      expect(identical(after.topRatedCafes, loaded.topRatedCafes), isTrue);

      // Reported once: the next emission no longer carries it.
      bloc.add(HomeDismissLocationBannerEvent());
      final next = await bloc.stream.first as HomeLoadedState;
      expect(next.refreshError, isNull);
    });

    test(
      'a first load, and a refresh after an error, show the skeleton',
      () async {
        final feed = _FakeFeed()..error = Exception('down');
        final bloc = HomeBloc(getHomeFeedUseCase: feed);
        addTearDown(bloc.close);

        final emitted = <HomeState>[];
        final sub = bloc.stream.listen(emitted.add);
        bloc.add(LoadHomeDataEvent());
        await bloc.stream.firstWhere((s) => s is HomeError);
        bloc.add(LoadHomeDataEvent(refresh: true));
        await bloc.stream.firstWhere((s) => s is HomeError);
        await sub.cancel();

        expect(emitted.map((s) => s.runtimeType), [
          HomeLoadingState,
          HomeError,
          HomeLoadingState,
          HomeError,
        ]);
      },
    );
  });

  group('widgets', () {
    testWidgets('an empty section renders nothing', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: HomeCafeSection(title: 'Trending', cafes: []),
          ),
        ),
      );
      expect(find.text('Trending'), findsNothing);
      expect(find.textContaining('No cafes'), findsNothing);
    });

    testWidgets('the tab bar labels all four tabs and reports taps', (
      tester,
    ) async {
      int? tapped;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            bottomNavigationBar: BottomNav(
              currentIndex: 0,
              onTap: (i) => tapped = i,
            ),
          ),
        ),
      );

      for (final label in ['Home', 'Map', 'Saved', 'Profile']) {
        expect(find.text(label), findsOneWidget);
      }
      expect(find.text('Search'), findsNothing);

      await tester.tap(find.text('Map'));
      expect(tapped, 1);
    });
  });
}
