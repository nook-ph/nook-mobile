import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/core/cafe/domain/entities/cafe_summary.dart';
import 'package:nook/core/utils/error_info.dart';
import 'package:nook/core/widgets/error/location_denied_banner.dart';
import 'package:nook/features/home_page/presentation/widgets/home_card_section.dart';
import 'package:nook/features/cafe_details/presentation/utils/cafe_open_status.dart';
import 'package:nook/features/home_page/presentation/widgets/home_featured_card.dart';
import 'package:nook/features/home_page/presentation/widgets/home_meta_line.dart';
import 'package:nook/features/home_page/presentation/widgets/home_state_view.dart';
import 'package:nook/features/home_page/presentation/widgets/home_tag_chip.dart';
import 'package:nook/utils/theme/theme.dart';

/// Layout smoke tests on the narrow phone QA flagged (360pt wide), using the
/// skeleton variants so no network image or status lookup is needed. A
/// RenderFlex overflow fails the test.
void main() {
  const cafe = CafeSummary(
    id: 'c1',
    name: 'The Coffee Bean and Tea Leaf Reserve Roastery',
    rating: 4.8,
    reviewCount: 12,
    neighborhood: 'Mahayahay-Bankal',
    city: 'Lapu-Lapu City',
    tags: [
      'Solo Work / Study',
      'Aesthetic / IG-worthy',
      'Free Wifi',
      'Parking',
    ],
  );

  Future<void> pump(
    WidgetTester tester,
    Widget child, {
    double textScale = 1,
  }) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: TAppTheme.lightTheme,
        home: MediaQuery(
          data: MediaQueryData(
            size: const Size(360, 640),
            textScaler: TextScaler.linear(textScale),
          ),
          child: Scaffold(body: SingleChildScrollView(child: child)),
        ),
      ),
    );
    await tester.pump();
  }

  for (final scale in [1.0, 1.3]) {
    testWidgets('feed sections fit a 360pt phone at text scale $scale', (
      tester,
    ) async {
      await pump(
        tester,
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FeaturedCarousel(cafes: List.filled(3, cafe), isSkeleton: true),
            HomeCafeSection(
              title: 'New',
              cafes: List.filled(4, cafe),
              isSkeleton: true,
            ),
          ],
        ),
        textScale: scale,
      );

      expect(tester.takeException(), isNull);
      // The featured card is inset by the gutter on both sides.
      final card = tester.getRect(find.byType(FeaturedCard).at(1));
      expect(card.left, 20);
      expect(card.width, 320);
    });
  }

  for (final scale in [1.0, 1.3]) {
    testWidgets('featured chips sit inside the carousel at text scale $scale', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: TAppTheme.lightTheme,
          home: MediaQuery(
            data: MediaQueryData(
              size: const Size(360, 780),
              textScaler: TextScaler.linear(scale),
            ),
            child: Scaffold(
              body: SingleChildScrollView(
                child: FeaturedCarousel(
                  cafes: List.filled(3, cafe),
                  isSkeleton: true,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      // The pager takes its height from the invisible prototype card; every
      // visible card's chip row must end inside it.
      final pager = tester.getRect(find.byType(PageView));
      final chips = find.descendant(
        of: find.byType(PageView),
        matching: find.byType(HomeTagChips),
      );
      expect(chips, findsWidgets);
      for (final element in chips.evaluate()) {
        final rect = tester.getRect(find.byWidget(element.widget).first);
        expect(rect.bottom, lessThanOrEqualTo(pager.bottom));
        expect(rect.top, greaterThanOrEqualTo(pager.top));
      }
    });

    testWidgets('a skeleton chip is as tall as a real one at $scale', (
      tester,
    ) async {
      await pump(
        tester,
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            HomeTagChip(label: 'Solo Work / Study', key: const Key('real')),
            HomeTagChip(
              label: 'Solo Work / Study',
              isSkeleton: true,
              key: const Key('skeleton'),
            ),
          ],
        ),
        textScale: scale,
      );
      expect(
        tester.getSize(find.byKey(const Key('skeleton'))).height,
        tester.getSize(find.byKey(const Key('real'))).height,
      );
    });

    // The carousels take their height from a skeleton card. A skeleton that
    // left the open line out made every row 20pt short of a real card.
    testWidgets('a placeholder open line is as tall as a real one at $scale', (
      tester,
    ) async {
      await pump(
        tester,
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            HomeOpenLine(
              key: const Key('real'),
              hours: {
                for (final day in CafeOpenStatus.orderedDays)
                  day: {'open': '07:00', 'close': '22:00'},
              },
            ),
            const HomeOpenLine.placeholder(key: Key('placeholder')),
          ],
        ),
        textScale: scale,
      );
      final real = tester.getSize(find.byKey(const Key('real'))).height;
      expect(real, greaterThan(0));
      expect(tester.getSize(find.byKey(const Key('placeholder'))).height, real);
    });
  }

  testWidgets('state views and both location banners fit', (tester) async {
    await pump(
      tester,
      Column(
        children: [
          LocationDeniedBanner(visible: true, onDismiss: () {}),
          LocationDeniedBanner.servicesOff(visible: true, onDismiss: () {}),
          HomeStateView.error(
            error: const ErrorInfo(
              type: ErrorType.sessionExpired,
              title: "You've been signed out",
              subtitle: 'Sign in to continue',
            ),
            onRetry: () {},
          ),
          HomeStateView.error(
            error: const ErrorInfo(
              type: ErrorType.offline,
              title: "You're offline",
              subtitle: 'Check your connection and try again',
            ),
            onRetry: () {},
          ),
        ],
      ),
      textScale: 1.3,
    );

    expect(tester.takeException(), isNull);
    expect(find.text('See cafes near you'), findsOneWidget);
    expect(find.text('Location Services are off'), findsOneWidget);
    expect(find.text('Open Settings'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });
}
