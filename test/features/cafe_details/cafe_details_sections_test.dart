import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:nook/core/analytics/analytics_service.dart';
import 'package:nook/features/cafe_details/domain/entities/cafe_details_entity.dart';
import 'package:nook/features/cafe_details/domain/use_cases/get_cafe_details_usecase.dart';
import 'package:nook/features/cafe_details/presentation/utils/cafe_open_status.dart';
import 'package:nook/features/cafe_details/presentation/utils/cafe_tag_groups.dart';
import 'package:nook/features/cafe_details/presentation/widgets/cafe_actions_bar.dart';
import 'package:nook/features/cafe_details/presentation/widgets/cafe_info.dart';
import 'package:nook/features/cafe_details/presentation/widgets/cafe_info_header.dart';
import 'package:nook/utils/theme/theme.dart';

/// Open around the clock, so the assertions do not depend on when the test
/// runs: 00:00 to 00:00 reads as overnight and is always open.
Map<String, dynamic> _alwaysOpen() => {
  for (final day in CafeOpenStatus.orderedDays)
    day: {'open': '00:00', 'close': '00:00'},
};

/// (0, 0) counts as "no coordinates", so the section shows the placeholder
/// image and never builds the platform map view.
CafeDetailsResult _cafe({
  Map<String, dynamic>? hours,
  List<TagEntity> tags = const [],
  int reviewCount = 32,
  String address = 'Salinas Drive, Lahug, Cebu City',
  Map<String, dynamic> socials = const {},
}) => CafeDetailsResult(
  cafeDetails: CafeDetailsEntity(
    id: 'cafe-1',
    createdAt: DateTime(2026),
    name: 'Tadaima',
    description: '',
    address: address,
    neighborhood: 'Lahug',
    city: 'Cebu City',
    lat: 0,
    lng: 0,
    rating: 4.9,
    reviewCount: reviewCount,
    isNew: false,
    operatingHours: hours ?? _alwaysOpen(),
    socialLinks: socials,
    tags: tags,
  ),
  menuHighlights: const [],
  allMenuItems: const [],
  latestReviews: const [],
  allReviews: const [],
);

Widget _host(Widget child) => MaterialApp(
  theme: TAppTheme.lightTheme,
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

void main() {
  setUpAll(() {
    final sl = GetIt.instance;
    if (!sl.isRegistered<AnalyticsService>()) {
      sl.registerLazySingleton<AnalyticsService>(() => AnalyticsService());
    }
  });

  group('CafeInfoHeader', () {
    testWidgets('puts rating and open status on one line', (tester) async {
      await tester.pumpWidget(_host(CafeInfoHeader(cafe: _cafe())));
      await tester.pump();

      expect(find.text('Tadaima'), findsOneWidget);
      expect(find.text('Lahug, Cebu City'), findsOneWidget);
      expect(find.text('4.9'), findsOneWidget);
      expect(find.text('(32)'), findsOneWidget);
      expect(find.text('Open'), findsOneWidget);
      expect(find.text('until 12 AM'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('says so when there are no reviews', (tester) async {
      await tester.pumpWidget(
        _host(CafeInfoHeader(cafe: _cafe(reviewCount: 0))),
      );

      expect(find.text('No reviews yet'), findsOneWidget);
      expect(find.text('4.9'), findsNothing);
    });

    testWidgets('makes no open or closed claim without hours', (tester) async {
      await tester.pumpWidget(
        _host(CafeInfoHeader(cafe: _cafe(hours: const {}))),
      );

      expect(find.text('Open'), findsNothing);
      expect(find.text('Closed'), findsNothing);
    });
  });

  group('CafeActionsBar', () {
    testWidgets('shows the open status beside Directions', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: TAppTheme.lightTheme,
          home: Scaffold(bottomNavigationBar: CafeActionsBar(cafe: _cafe())),
        ),
      );
      await tester.pump();

      expect(find.text('Directions'), findsOneWidget);
      expect(find.text('Open until 12 AM'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('is just the button when there is nothing to say', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: TAppTheme.lightTheme,
          home: Scaffold(
            bottomNavigationBar: CafeActionsBar(cafe: _cafe(hours: const {})),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Directions'), findsOneWidget);
      expect(find.textContaining('Open'), findsNothing);
      expect(find.textContaining('Closed'), findsNothing);
    });
  });

  group('CafeAmenitiesSection', () {
    testWidgets('lists amenities and best-for tags', (tester) async {
      final groups = CafeTagGroups.from([
        TagEntity(id: '1', name: 'Free WiFi', category: 'amenities'),
        TagEntity(id: '2', name: 'Power Outlets', category: 'amenities'),
        TagEntity(id: '3', name: 'Solo Work / Study', category: 'best_for'),
      ]);
      await tester.pumpWidget(_host(CafeAmenitiesSection(groups: groups)));

      expect(find.text('Amenities'), findsOneWidget);
      expect(find.text('Free WiFi'), findsOneWidget);
      expect(find.text('Best for'), findsOneWidget);
      expect(find.text('Solo Work / Study'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('leaves out the half that has nothing in it', (tester) async {
      final groups = CafeTagGroups.from([
        TagEntity(id: '3', name: 'Solo Work / Study', category: 'best_for'),
      ]);
      await tester.pumpWidget(_host(CafeAmenitiesSection(groups: groups)));

      expect(find.text('Amenities'), findsNothing);
      expect(find.text('Best for'), findsOneWidget);
    });

    test('has no content for a listing without those tags', () {
      expect(
        CafeAmenitiesSection.hasContent(
          CafeTagGroups.from([TagEntity(id: '1', name: 'Cash')]),
        ),
        isFalse,
      );
    });
  });

  group('CafeHoursLocationSection', () {
    Widget section(CafeDetailsResult cafe) => _host(
      CafeHoursLocationSection(
        cafe: cafe,
        groups: CafeTagGroups.from(cafe.cafeDetails.tags),
      ),
    );

    testWidgets('shows hours, address and payments as rows', (tester) async {
      await tester.pumpWidget(
        section(
          _cafe(
            tags: [
              TagEntity(id: '1', name: 'Cash', category: 'payment_options'),
              TagEntity(id: '2', name: 'GCash', category: 'payment_options'),
            ],
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Hours & location'), findsOneWidget);
      expect(find.textContaining('Closes 12:00 AM'), findsOneWidget);
      expect(find.text('Salinas Drive, Lahug, Cebu City'), findsOneWidget);
      expect(find.text('Cash, GCash'), findsOneWidget);
      expect(find.text('Payments accepted'), findsOneWidget);
      // The week stays folded until the row is tapped.
      expect(find.text('Monday'), findsNothing);
    });

    testWidgets('opens the week in place, with today marked', (tester) async {
      await tester.pumpWidget(section(_cafe()));
      await tester.pump();

      await tester.tap(find.textContaining('Closes 12:00 AM'));
      await tester.pump();

      final today = CafeOpenStatus.dayKey(DateTime.now());
      final label = today[0].toUpperCase() + today.substring(1);
      expect(find.text('$label · Today'), findsOneWidget);
      // Seven day lines in total: six plain, one marked as today.
      final plain = CafeOpenStatus.orderedDays
          .where((d) => d != today)
          .map((d) => d[0].toUpperCase() + d.substring(1));
      for (final day in plain) {
        expect(find.text(day), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('drops the rows a sparse listing has nothing for', (
      tester,
    ) async {
      await tester.pumpWidget(section(_cafe(hours: const {}, address: '  ')));
      await tester.pump();

      expect(find.text('Hours & location'), findsOneWidget);
      expect(find.textContaining('Closes'), findsNothing);
      expect(find.text('Payments accepted'), findsNothing);
      expect(find.bySemanticsLabel(RegExp('^Open ')), findsNothing);
    });

    testWidgets('shows only the socials the cafe has', (tester) async {
      await tester.pumpWidget(
        section(_cafe(socials: const {'instagram': 'tadaima', 'tiktok': ''})),
      );
      await tester.pump();

      expect(find.bySemanticsLabel('Open instagram'), findsOneWidget);
      expect(find.bySemanticsLabel('Open facebook'), findsNothing);
      expect(find.bySemanticsLabel('Open tiktok'), findsNothing);
    });
  });
}
