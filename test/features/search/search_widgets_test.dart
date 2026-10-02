import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:nook/core/cafe/domain/entities/cafe_summary.dart';
import 'package:nook/core/utils/app_error_copy.dart';
import 'package:nook/features/search/data/search_location.dart';
import 'package:nook/features/search/domain/entities/search_origin.dart';
import 'package:nook/features/search/domain/search_place_index.dart';
import 'package:nook/features/search/presentation/pages/search_pick_on_map_page.dart';
import 'package:nook/features/search/presentation/widgets/search_empty_view.dart';
import 'package:nook/features/search/presentation/widgets/search_filters.dart';
import 'package:nook/features/search/presentation/widgets/search_header.dart';
import 'package:nook/features/search/presentation/widgets/search_idle_view.dart';
import 'package:nook/features/search/presentation/widgets/search_origin_sheet.dart';
import 'package:nook/features/search/presentation/widgets/search_rows.dart';
import 'package:nook/features/search/presentation/widgets/search_tokens.dart';

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
              places: Future.value(index),
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
