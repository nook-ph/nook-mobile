import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:nook/core/cafe/domain/entities/cafe_summary.dart';
import 'package:nook/core/utils/app_error_copy.dart';
import 'package:nook/features/search/data/search_location.dart';
import 'package:nook/features/search/domain/entities/search_origin.dart';
import 'package:nook/features/search/domain/search_place_index.dart';
import 'package:nook/features/search/presentation/cubit/place_search_cubit.dart';
import 'package:nook/features/search/presentation/cubit/saved_places_cubit.dart';
import 'package:nook/features/search/presentation/pages/search_pick_on_map_page.dart';
import 'package:nook/features/search/presentation/widgets/search_empty_view.dart';
import 'package:nook/features/search/presentation/widgets/search_filters.dart';
import 'package:nook/features/search/presentation/widgets/search_header.dart';
import 'package:nook/features/search/presentation/widgets/search_idle_view.dart';
import 'package:nook/features/search/presentation/widgets/search_origin_sheet.dart';
import 'package:nook/features/search/presentation/widgets/search_rows.dart';
import 'package:nook/features/search/presentation/widgets/search_tokens.dart';
import 'package:skeletonizer/skeletonizer.dart';

import 'place_search_fakes.dart';

void main() {
  Future<void> pump(WidgetTester tester, Widget child) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: child)));
  }

  group('Near row', () {
    Widget header({
      SearchOrigin? origin,
      SearchLocationStatus location = SearchLocationStatus.available,
      VoidCallback? onTurnOn,
      VoidCallback? onOriginTap,
    }) {
      return SearchHeader(
        controller: TextEditingController(),
        focusNode: FocusNode(),
        origin: origin,
        onChanged: (_) {},
        onSubmitted: (_) {},
        onClear: () {},
        onOriginTap: onOriginTap ?? () {},
        onReset: () {},
        location: location,
        onTurnOn: onTurnOn,
      );
    }

    testWidgets('location off: says so in grey, with Turn on', (tester) async {
      var turnedOn = 0;
      await pump(
        tester,
        header(location: SearchLocationStatus.off, onTurnOn: () => turnedOn++),
      );
      final label = tester.widget<Text>(find.text('Location is off'));
      expect(label.style?.color, SearchTokens.muted);
      expect(label.style?.fontWeight, FontWeight.w600);
      expect(find.text('Current location'), findsNothing);

      final turnOn = tester.widget<Text>(find.text('Turn on'));
      expect(turnOn.style?.fontSize, 12);
      expect(turnOn.style?.fontWeight, FontWeight.w600);
      expect(turnOn.style?.color, SearchTokens.brand);
      await tester.tap(find.text('Turn on'));
      expect(turnedOn, 1);
      expect(tester.takeException(), isNull);
    });

    testWidgets('not asked: "Choose a place" opens the chooser', (
      tester,
    ) async {
      var opened = 0;
      await pump(
        tester,
        header(
          location: SearchLocationStatus.notAsked,
          onTurnOn: () {},
          onOriginTap: () => opened++,
        ),
      );
      final label = tester.widget<Text>(find.text('Choose a place'));
      expect(label.style?.color, SearchTokens.ink);
      expect(find.text('Turn on'), findsNothing);
      await tester.tap(find.text('Choose a place'));
      expect(opened, 1);
    });

    testWidgets('a chosen place wins over the location state', (tester) async {
      await pump(
        tester,
        header(
          origin: const SearchOrigin(
            label: 'IT Park',
            subtitle: 'Cebu City',
            lat: 10.33,
            lng: 123.9,
          ),
          location: SearchLocationStatus.off,
          onTurnOn: () {},
        ),
      );
      expect(find.text('IT Park, Cebu City'), findsOneWidget);
      expect(find.text('Reset'), findsOneWidget);
      expect(find.text('Turn on'), findsNothing);
      expect(find.text('Location is off'), findsNothing);
    });

    testWidgets('available: Current location, nothing on the right', (
      tester,
    ) async {
      await pump(tester, header(onTurnOn: () {}));
      expect(find.text('Current location'), findsOneWidget);
      expect(find.text('Turn on'), findsNothing);
      expect(find.text('Reset'), findsNothing);
    });
  });

  group('idle screen', () {
    testWidgets('Clear all sits beside the recents title', (tester) async {
      var cleared = 0;
      await pump(
        tester,
        SearchIdleView(
          recents: const ['spanish latte', 'Tadaima'],
          onRecentTap: (_) {},
          onRecentRemove: (_) {},
          onTagTap: (_) {},
          onClearRecents: () => cleared++,
        ),
      );
      final clear = tester.widget<Text>(find.text('Clear all'));
      expect(clear.style?.fontSize, 12);
      expect(clear.style?.fontWeight, FontWeight.w500);
      expect(clear.style?.color, SearchTokens.brand);
      expect(
        tester.getCenter(find.text('Clear all')).dy,
        closeTo(tester.getCenter(find.text('Recent searches')).dy, 2),
      );
      await tester.tap(find.text('Clear all'));
      expect(cleared, 1);
    });

    testWidgets('no recents, no Clear all', (tester) async {
      await pump(
        tester,
        SearchIdleView(
          recents: const [],
          onRecentTap: (_) {},
          onRecentRemove: (_) {},
          onTagTap: (_) {},
          onClearRecents: () {},
        ),
      );
      expect(find.text('Clear all'), findsNothing);
      expect(find.text('Recent searches'), findsNothing);
    });

    testWidgets('the "Search near you" card comes first, with two equal '
        '40pt buttons', (tester) async {
      var used = 0;
      var chosen = 0;
      await pump(
        tester,
        SearchIdleView(
          recents: const ['matcha'],
          onRecentTap: (_) {},
          onRecentRemove: (_) {},
          onTagTap: (_) {},
          locationCard: SearchLocationPromptCard(
            onUseMyLocation: () => used++,
            onChoosePlace: () => chosen++,
          ),
        ),
      );
      expect(find.text('Search near you'), findsOneWidget);
      expect(
        find.text(
          'Allow location to see the closest cafes first, or pick a '
          'neighbourhood yourself.',
        ),
        findsOneWidget,
      );
      expect(
        tester.getTopLeft(find.byType(SearchLocationPromptCard)).dy,
        lessThan(tester.getTopLeft(find.text('Recent searches')).dy),
      );
      final card = tester.getRect(find.byType(SearchLocationPromptCard));
      expect(card.width, 350);

      Size button(String label) => tester.getSize(
        find
            .ancestor(of: find.text(label), matching: find.byType(Container))
            .first,
      );
      expect(button('Use my location').height, 40);
      expect(button('Use my location').width, button('Choose a place').width);

      await tester.tap(find.text('Use my location'));
      await tester.tap(find.text('Choose a place'));
      expect(used, 1);
      expect(chosen, 1);
      expect(tester.takeException(), isNull);
    });
  });

  group('results', () {
    testWidgets('location card: the copy, and a dismiss', (tester) async {
      var dismissed = 0;
      await pump(
        tester,
        Padding(
          padding: const EdgeInsets.all(20),
          child: SearchLocationOffCard(onDismiss: () => dismissed++),
        ),
      );
      expect(
        find.text(
          'Turn on location to see the closest cafes first, or choose a '
          'place to search near.',
        ),
        findsOneWidget,
      );
      await tester.tap(find.byIcon(LucideIcons.x));
      expect(dismissed, 1);
    });

    testWidgets('offline block sits under the header, not mid-page', (
      tester,
    ) async {
      var retried = 0;
      await pump(
        tester,
        SearchErrorBlock(
          error: AppErrorCopy.fromException(const SocketException('x')),
          onRetry: () => retried++,
        ),
      );
      expect(find.text("You're offline"), findsOneWidget);
      // 12 of results padding plus the block's own 120.
      expect(tester.getTopLeft(find.byIcon(LucideIcons.wifiOff)).dy, 132);
      final pill = tester.getSize(
        find
            .ancestor(
              of: find.text('Try again'),
              matching: find.byType(Container),
            )
            .first,
      );
      expect(pill.height, 44);
      expect(pill.width, lessThan(200));
      await tester.tap(find.text('Try again'));
      expect(retried, 1);
    });

    testWidgets('an unrated cafe reads "No reviews yet · area"', (
      tester,
    ) async {
      await pump(
        tester,
        const SearchResultRow(
          cafe: CafeSummary(
            id: 'u',
            name: 'Coffee Madness',
            neighborhood: 'Tayud',
            city: 'Liloan',
            rating: 0,
          ),
        ),
      );
      expect(find.text('No reviews yet · Tayud, Liloan'), findsOneWidget);
      expect(find.byIcon(Icons.star_rounded), findsNothing);
    });

    testWidgets('a rated cafe keeps its star, rating and count', (
      tester,
    ) async {
      await pump(
        tester,
        const SearchResultRow(
          cafe: CafeSummary(
            id: 'r',
            name: 'Tadaima',
            neighborhood: 'Lahug',
            city: 'Cebu City',
            rating: 4.9,
            reviewCount: 32,
          ),
        ),
      );
      expect(find.text('(32) · Lahug, Cebu City'), findsOneWidget);
      expect(find.text('4.9'), findsOneWidget);
      expect(find.textContaining('No reviews yet'), findsNothing);
    });
  });

  group('loading', () {
    testWidgets('a count bar, then five rows of a square and four bars', (
      tester,
    ) async {
      await pump(
        tester,
        const SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: SearchResultsSkeleton(),
        ),
      );
      final bone = find.byWidgetPredicate((w) => w is Bone);
      // 1 count bar + 5 x (photo + 4 bars).
      expect(bone, findsNWidgets(26));
      final sizes = bone.evaluate().map((e) => e.size).toList();
      expect(sizes.first, const Size(110, 12));
      expect(sizes.sublist(1, 6), const [
        Size(76, 76),
        Size(150, 14),
        Size(110, 10),
        Size(90, 10),
        Size(170, 10),
      ]);
      // Rows are 76 + 14 above and below, with no divider between them.
      expect(find.byType(SearchDivider), findsNothing);
      final photos = bone
          .evaluate()
          .where((e) => e.size == const Size(76, 76))
          .map(
            (e) => (e.renderObject! as RenderBox).localToGlobal(Offset.zero).dy,
          )
          .toList();
      expect(photos[1] - photos[0], 104);
    });
  });

  group('filters row', () {
    Future<void> row(
      WidgetTester tester, {
      String sort = 'nearby',
      bool openNow = false,
      Set<String> tags = const {},
      VoidCallback? onSort,
      VoidCallback? onOpenNow,
      ValueChanged<String>? onTag,
    }) => pump(
      tester,
      SearchFiltersRow(
        sort: sort,
        openNow: openNow,
        tags: tags,
        onAllFilters: () {},
        onSort: onSort ?? () {},
        onOpenNow: onOpenNow ?? () {},
        onTag: onTag ?? (_) {},
      ),
    );

    testWidgets('all filters, then sort, "Open now", then tags', (
      tester,
    ) async {
      await row(tester);
      final labels = tester
          .widgetList<SearchChip>(find.byType(SearchChip))
          .map((c) => c.label ?? c.semanticLabel)
          .toList();
      // The row scrolls; the chips past the screen edge are not built.
      expect(labels.take(4), [
        'All filters',
        'Nearest',
        'Open now',
        kSearchQuickTags.first,
      ]);
    });

    testWidgets('sort is filled, chosen tags are filled and come first', (
      tester,
    ) async {
      await row(tester, sort: 'top_rated', tags: {'Pet Friendly'});
      expect(
        tester
            .widget<SearchChip>(find.widgetWithText(SearchChip, 'Open now'))
            .selected,
        isFalse,
      );
      final chips = tester
          .widgetList<SearchChip>(find.byType(SearchChip))
          .toList();
      expect(chips[1].label, 'Top rated');
      expect(chips[1].selected, isTrue);
      expect(chips[2].label, 'Open now');
      expect(chips[3].label, 'Pet Friendly');
      expect(chips[3].selected, isTrue);
    });

    testWidgets('"Open now" is left out when there are no hours to filter '
        'on', (tester) async {
      await pump(
        tester,
        SearchFiltersRow(
          sort: 'nearby',
          openNow: false,
          tags: const {},
          onAllFilters: () {},
          onSort: () {},
          onOpenNow: () {},
          onTag: (_) {},
          showOpenNow: false,
        ),
      );
      expect(find.text('Open now'), findsNothing);
      expect(find.text('Nearest'), findsOneWidget);
      expect(find.text('Free WiFi'), findsOneWidget);
    });

    testWidgets('"Open now" fills when on', (tester) async {
      await row(tester, openNow: true);
      expect(
        tester
            .widget<SearchChip>(find.widgetWithText(SearchChip, 'Open now'))
            .selected,
        isTrue,
      );
    });

    testWidgets('taps reach sort, "Open now" and the tag', (tester) async {
      var sorts = 0;
      var opens = 0;
      final tapped = <String>[];
      await row(
        tester,
        onSort: () => sorts++,
        onOpenNow: () => opens++,
        onTag: tapped.add,
      );
      await tester.tap(find.text('Open now'));
      expect(opens, 1);
      await tester.tap(find.text('Nearest'));
      await tester.ensureVisible(find.text('Free WiFi'));
      await tester.pump();
      await tester.tap(find.text('Free WiFi'));
      expect(sorts, 1);
      expect(tapped, ['Free WiFi']);
    });
  });

  group('sort sheet', () {
    Future<void> open(
      WidgetTester tester,
      String current,
      ValueChanged<String?> onClosed,
    ) async {
      await pump(
        tester,
        Builder(
          builder: (context) => TextButton(
            onPressed: () async =>
                onClosed(await showSearchSortSheet(context, current)),
            child: const Text('open'),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    testWidgets('the four sorts get_cafes accepts, the current one ticked', (
      tester,
    ) async {
      await open(tester, 'top_rated', (_) {});
      expect(find.text('Sort by'), findsOneWidget);
      for (final label in ['Nearest', 'Top rated', 'Trending', 'Newest']) {
        expect(find.text(label), findsOneWidget);
      }
      expect(kSearchSorts.map((s) => s.$1), [
        'nearby',
        'top_rated',
        'trending',
        'newest',
      ]);
      expect(find.byIcon(LucideIcons.check), findsOneWidget);
      expect(
        tester.getCenter(find.byIcon(LucideIcons.check)).dy,
        moreOrLessEquals(tester.getCenter(find.text('Top rated')).dy),
      );
    });

    testWidgets('a tap returns the sort id; close returns nothing', (
      tester,
    ) async {
      String? picked = 'unset';
      await open(tester, 'nearby', (v) => picked = v);
      await tester.tap(find.text('Newest'));
      await tester.pumpAndSettle();
      expect(picked, 'newest');

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(LucideIcons.x));
      await tester.pumpAndSettle();
      expect(picked, isNull);
    });

    testWidgets('8 above the grabber, 32pt close, rows 4 apart', (
      tester,
    ) async {
      await open(tester, 'nearby', (_) {});
      final sheet = tester.getRect(find.byType(SearchSheetFrame));
      final title = tester.getRect(find.text('Sort by'));
      final close = tester.getRect(
        find
            .ancestor(
              of: find.byIcon(LucideIcons.x),
              matching: find.byType(SizedBox),
            )
            .first,
      );
      expect(close.size, const Size(32, 32));
      // 8 + grabber 4 + its 4 + gap 4.
      expect(close.top - sheet.top, 20);
      expect(title.left, 20);
      final nearest = tester.getRect(find.text('Nearest'));
      final topRated = tester.getRect(find.text('Top rated'));
      // 13 below one label, 4 between rows, 13 above the next.
      expect(topRated.top - nearest.bottom, 30);
      // 4 under the header, then the row's own 13.
      expect(nearest.top - close.bottom, 17);
    });
  });

  group('all filters sheet', () {
    Future<void> open(
      WidgetTester tester, {
      Future<int?> Function(Set<String>)? count,
      ValueChanged<Set<String>?>? onClosed,
    }) async {
      await pump(
        tester,
        Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              final tags = await showSearchTagsSheet(context, {
                'Free WiFi',
              }, count: count);
              onClosed?.call(tags);
            },
            child: const Text('open'),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    testWidgets('two equal 48pt pills, 8 apart', (tester) async {
      await open(tester, count: (tags) async => 12);
      await tester.pumpAndSettle(const Duration(milliseconds: 400));

      final clear = tester.getRect(
        find
            .ancestor(
              of: find.text('Clear all'),
              matching: find.byType(SearchPillButton),
            )
            .first,
      );
      final show = tester.getRect(
        find
            .ancestor(
              of: find.text('Show 12 cafes'),
              matching: find.byType(SearchPillButton),
            )
            .first,
      );
      expect(clear.height, 48);
      expect(show.height, 48);
      expect(clear.width, closeTo(show.width, 0.5));
      expect(show.left - clear.right, 8);
      expect(clear.top, show.top);
      expect(tester.takeException(), isNull);
    });

    testWidgets('says Apply while counting, and recounts on each change', (
      tester,
    ) async {
      final asked = <Set<String>>[];
      await open(
        tester,
        count: (tags) async {
          asked.add(tags);
          return tags.length * 10;
        },
      );
      await tester.pumpAndSettle(const Duration(milliseconds: 400));
      expect(find.text('Show 10 cafes'), findsOneWidget);

      await tester.ensureVisible(find.text('Power Outlets'));
      await tester.tap(find.text('Power Outlets'));
      await tester.pump();
      expect(find.text('Apply'), findsOneWidget);
      await tester.pumpAndSettle(const Duration(milliseconds: 400));
      expect(find.text('Show 20 cafes'), findsOneWidget);
      expect(asked.last, {'Free WiFi', 'Power Outlets'});

      await tester.tap(find.text('Clear all'));
      await tester.pumpAndSettle(const Duration(milliseconds: 400));
      expect(asked.last, isEmpty);
    });

    testWidgets('a count that cannot be given stays Apply', (tester) async {
      await open(tester, count: (tags) async => null);
      await tester.pumpAndSettle(const Duration(milliseconds: 400));
      expect(find.text('Apply'), findsOneWidget);

      Set<String>? result;
      await tester.pumpWidget(const SizedBox());
      await open(
        tester,
        count: (tags) async => throw Exception('offline'),
        onClosed: (tags) => result = tags,
      );
      await tester.pumpAndSettle(const Duration(milliseconds: 400));
      expect(find.text('Apply'), findsOneWidget);
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();
      expect(result, {'Free WiFi'});
    });
  });

  group('choosing a place', () {
    final index = SearchPlaceIndex.fromCafes(const [
      CafeSummary(
        id: 'a',
        name: 'A',
        rating: 4,
        neighborhood: 'Banilad',
        city: 'Cebu City',
        lat: 10.3400,
        lng: 123.9100,
      ),
    ]);

    test('pick on map: names the neighbourhood under the pin', () {
      expect(
        SearchPickOnMapPage.nearLabel(index, 10.3405, 123.9102),
        'Banilad, Cebu City',
      );
    });

    test('pick on map: nothing near means "Pinned location"', () {
      expect(SearchPickOnMapPage.nearLabel(index, 11.2, 124.0), isNull);
      expect(
        SearchPickOnMapPage.nearLabel(SearchPlaceIndex.empty, 10.34, 123.91),
        isNull,
      );
      expect(
        const SearchOrigin.pin(lat: 11.2, lng: 124.0).label,
        'Pinned location',
      );
    });

    testWidgets('no place matches: the two lines, then pick on the map', (
      tester,
    ) async {
      await pump(
        tester,
        Builder(
          builder: (context) => TextButton(
            onPressed: () => showSearchOriginSheet(
              context,
              current: null,
              currentLocationLabel: null,
              recentPlaces: const [],
              search: PlaceSearchCubit(
                repository: FakePlaceSearchRepository(),
                places: Future.value(index),
                debounce: Duration.zero,
              ),
              saved: SavedPlacesCubit(FakeSavedPlacesRepository())..load(),
              openEditor: (_, {place, required kind}) async => null,
            ),
            child: const Text('open'),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'kasambagn');
      await tester.pumpAndSettle();

      final title = tester.widget<Text>(
        find.text('No places match “kasambagn”'),
      );
      expect(title.style?.fontWeight, FontWeight.w600);
      expect(title.style?.color, SearchTokens.ink);
      expect(
        find.text('Check the spelling, or drop a pin on the map instead.'),
        findsOneWidget,
      );
      expect(find.text('Places'), findsNothing);
      expect(find.text('Pick on the map'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'bani');
      await tester.pumpAndSettle();
      expect(find.text('Places'), findsOneWidget);
      expect(find.text('Banilad'), findsOneWidget);
      expect(find.textContaining('No places match'), findsNothing);
    });
  });
}
