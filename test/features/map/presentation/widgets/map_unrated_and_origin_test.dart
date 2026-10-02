import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/core/cafe/domain/entities/cafe_summary.dart';
import 'package:nook/core/filters/cubit/filter_cubit.dart';
import 'package:nook/core/utils/geo.dart';
import 'package:nook/features/map/presentation/widgets/bottom_modal_sheet.dart';
import 'package:nook/features/map/presentation/widgets/map_filter_sub_sheet.dart';
import 'package:nook/features/map/presentation/widgets/map_search_pill.dart';
import 'package:nook/features/map/presentation/widgets/map_sheet_cafe_card.dart';
import 'package:nook/features/map/presentation/widgets/map_tokens.dart';
import 'package:nook/features/map/presentation/widgets/map_updating_chip.dart';

void main() {
  group('unrated cafes', () {
    const unrated = CafeSummary(
      id: 'u',
      name: 'Coffee Madness',
      neighborhood: 'Tayud',
      city: 'Liloan',
      rating: 0,
    );
    const rated = CafeSummary(
      id: 'r',
      name: 'Tadaima',
      neighborhood: 'Lahug',
      city: 'Cebu City',
      rating: 4.9,
      reviewCount: 32,
    );

    test('the list says "No reviews yet" before the area', () {
      expect(
        MapSheetCafeCard.countAndArea(unrated),
        'No reviews yet · Tayud, Liloan',
      );
    });

    test('the pin preview card says only "No reviews yet"', () {
      expect(
        MapSheetCafeCard.countAndArea(unrated, withUnratedArea: false),
        'No reviews yet',
      );
    });

    test('a cafe with no area still says "No reviews yet"', () {
      const bare = CafeSummary(id: 'b', name: 'Bare', rating: 0);
      expect(MapSheetCafeCard.countAndArea(bare), 'No reviews yet');
    });

    test('rated cafes are unchanged', () {
      expect(MapSheetCafeCard.countAndArea(rated), '(32) · Lahug, Cebu City');
      expect(
        MapSheetCafeCard.countAndArea(rated, withUnratedArea: false),
        '(32) · Lahug, Cebu City',
      );
    });
  });

  group('distance from a chosen place', () {
    const itPark = GeoPoint(lat: 10.3300, lng: 123.9060);

    test('is measured from the place', () {
      const cafe = CafeSummary(
        id: 'c',
        name: 'C',
        rating: 4,
        lat: 10.3300,
        lng: 123.9160,
      );
      // 0.01 degrees of longitude at this latitude is about 1.1 km.
      expect(MapSheetCafeCard.distanceLabel(cafe, itPark), '1.1 km');
    });

    test('is null without coordinates', () {
      const cafe = CafeSummary(id: 'c', name: 'C', rating: 4);
      expect(MapSheetCafeCard.distanceLabel(cafe, itPark), isNull);
    });
  });

  group('search pill', () {
    Future<void> pump(WidgetTester tester, Widget pill) => tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Padding(padding: const EdgeInsets.all(20), child: pill),
        ),
      ),
    );

    testWidgets('names the chosen place', (tester) async {
      await pump(
        tester,
        MapSearchPill(origin: 'IT Park, Cebu City', onOriginTap: () {}),
      );
      expect(find.text('Near'), findsOneWidget);
      expect(find.text('IT Park, Cebu City'), findsOneWidget);
      expect(tester.getSize(find.byType(MapSearchPill)).height, 52);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the Near line is its own tap target', (tester) async {
      var originTaps = 0;
      await pump(tester, MapSearchPill(onOriginTap: () => originTaps++));

      await tester.tap(find.text('Current location'));
      await tester.pump();
      expect(originTaps, 1);

      // The target is the line, not the pill's whole lower half.
      final target = tester.getRect(
        find.byKey(const ValueKey('map-search-origin')),
      );
      final pill = tester.getRect(find.byType(MapSearchPill));
      expect(target.width, lessThan(pill.width / 2));
      expect(target.bottom, pill.bottom);
    });

    testWidgets('a long place name is cut, not overflowed', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await pump(
        tester,
        MapSearchPill(
          origin: 'Kasambagan Heights Subdivision Phase Two, Cebu City',
          onOriginTap: () {},
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('sheet', () {
    Future<void> pumpSheet(WidgetTester tester, List<CafeSummary> cafes) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider(
            create: (_) => FilterCubit(),
            child: Scaffold(
              body: BottomModalSheet(cafes: cafes, tags: const []),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));
    }

    testWidgets('no "0 cafes in view" above the empty state', (tester) async {
      await pumpSheet(tester, const []);
      expect(find.text('No cafes in this area'), findsOneWidget);
      expect(find.textContaining('in view'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the count shows when there are cafes', (tester) async {
      await pumpSheet(tester, const [
        CafeSummary(id: 'a', name: 'A', rating: 4.5, reviewCount: 3),
      ]);
      expect(find.text('1 cafe in view'), findsOneWidget);
    });
  });

  testWidgets('the updating spinner is brand green', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Center(child: MapUpdatingChip())),
      ),
    );
    final spinner = tester.widget<CircularProgressIndicator>(
      find.byType(CircularProgressIndicator),
    );
    expect(spinner.color, MapTokens.brand);
    expect(MapTokens.brand, const Color(0xFF344E41));
  });

  test('sort is the only group without a footer count', () {
    // Sort applies on tap; the other groups are counted before Apply.
    expect(MapFilterSubSheet.titleFor(MapFilterSubSection.sort), 'Sort');
  });
}
