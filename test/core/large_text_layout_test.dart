// SF6: fixed heights around text clipped or overflowed at large text sizes.
// Each surface is pumped at 360pt wide, at text scale 1.3 and 2.0, and must
// lay out without an overflow error.

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:nook/core/analytics/analytics_service.dart';
import 'package:nook/core/block/block_cubit.dart';
import 'package:nook/features/cafe_details/bloc/reviews_bloc.dart';
import 'package:nook/features/cafe_details/bloc/reviews_state.dart';
import 'package:nook/features/cafe_details/domain/entities/cafe_details_entity.dart';
import 'package:nook/features/cafe_details/domain/use_cases/get_cafe_details_usecase.dart';
import 'package:nook/features/cafe_details/presentation/utils/cafe_open_status.dart';
import 'package:nook/features/cafe_details/presentation/widgets/cafe_info_header.dart';
import 'package:nook/features/cafe_details/presentation/widgets/menu_highlights.dart';
import 'package:nook/features/cafe_details/presentation/widgets/review_row.dart';
import 'package:nook/features/cafe_details/presentation/widgets/reviews_preview_section.dart';
import 'package:nook/features/lists/presentation/widgets/lists_ui.dart';
import 'package:nook/features/map/presentation/widgets/map_search_pill.dart';
import 'package:nook/features/map/presentation/widgets/map_sheet_toggle.dart';
import 'package:nook/features/public_profile/domain/i_public_profile_repository.dart';
import 'package:nook/features/search/presentation/widgets/search_origin_sheet.dart';
import 'package:nook/utils/theme/theme.dart';

import '../features/profile/profile_test_support.dart' show FakeBlockCubit;
import '../features/public_profile/public_profile_fakes.dart';

class _StubReviewsBloc extends Cubit<ReviewsState> implements ReviewsBloc {
  _StubReviewsBloc(super.initialState);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

ReviewEntity _review(String id, {int helpful = 3}) => ReviewEntity(
  id: id,
  cafeId: 'cafe-1',
  userId: 'user-$id',
  rating: 4,
  content:
      'Quiet upstairs, good light, and the cortado is the best in Lahug. '
      'Came back twice in a week and will again.',
  createdAt: DateTime(2026, 9, 1),
  updatedAt: DateTime(2026, 9, 1),
  name: 'Bea Santos Delacruz',
  helpfulCount: helpful,
);

MenuItemEntity _item(String id) => MenuItemEntity(
  id: id,
  cafeId: 'cafe-1',
  name: 'Spanish latte with oat milk',
  price: 180,
  isHighlight: true,
);

/// Closed now (today's one minute past midnight is over), opening tomorrow
/// morning, so the header shows its longest status line
/// ("Closed · opens 7 AM tomorrow").
Map<String, dynamic> _opensLater() {
  final today = CafeOpenStatus.todayKey();
  final tomorrow = CafeOpenStatus
      .orderedDays[(CafeOpenStatus.orderedDays.indexOf(today) + 1) % 7];
  return {
    today: {'open': '00:00', 'close': '00:01'},
    tomorrow: {'open': '07:00', 'close': '08:00'},
  };
}

CafeDetailsResult _cafe() => CafeDetailsResult(
  cafeDetails: CafeDetailsEntity(
    id: 'cafe-1',
    createdAt: DateTime(2026),
    name: 'Tadaima Coffee and Kitchen',
    description: '',
    address: 'Salinas Drive, Lahug, Cebu City',
    neighborhood: 'Lahug',
    city: 'Cebu City',
    lat: 0,
    lng: 0,
    rating: 4.9,
    reviewCount: 132,
    isNew: false,
    operatingHours: _opensLater(),
    socialLinks: const {},
    tags: const [],
  ),
  menuHighlights: [_item('a'), _item('b'), _item('c')],
  allMenuItems: const [],
  latestReviews: const [],
  allReviews: const [],
);

Future<void> _pumpAt(
  WidgetTester tester,
  double scale,
  Widget child, {
  bool scroll = true,
}) async {
  tester.view.physicalSize = const Size(360, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => MediaQuery.withClampedTextScaling(
          minScaleFactor: scale,
          maxScaleFactor: scale,
          child: Scaffold(
            body: scroll ? SingleChildScrollView(child: child) : child,
          ),
        ),
      ),
    ],
  );
  await tester.pumpWidget(
    MaterialApp.router(theme: TAppTheme.lightTheme, routerConfig: router),
  );
  await tester.pump();
}

/// Each text found by [finder] gets the height its lines need: a fixed box
/// around text squeezes the paragraph without an overflow error, so this is
/// the check that catches a clip.
void _expectNotClipped(WidgetTester tester, Finder finder) {
  expect(finder, findsWidgets);
  for (final element in finder.evaluate()) {
    final paragraph = element.renderObject! as RenderParagraph;
    final needs = paragraph.getMinIntrinsicHeight(paragraph.size.width);
    expect(
      paragraph.size.height,
      greaterThanOrEqualTo(needs - 0.5),
      reason: '"${paragraph.text.toPlainText()}" is clipped',
    );
  }
}

void main() {
  setUpAll(() {
    final sl = GetIt.instance;
    if (!sl.isRegistered<AnalyticsService>()) {
      sl.registerLazySingleton<AnalyticsService>(() => AnalyticsService());
    }
    if (!sl.isRegistered<IPublicProfileRepository>()) {
      sl.registerSingleton<IPublicProfileRepository>(
        FakePublicProfileRepository(profile: beaProfile()),
      );
    }
  });

  testWidgets('map search pill holds both lines at 2.4x (it overflowed '
      'past 2.1)', (tester) async {
    await _pumpAt(
      tester,
      2.4,
      const MapSearchPill(origin: 'IT Park, Cebu City'),
    );
    expect(tester.takeException(), isNull);
    expect(
      tester.getRect(find.text('IT Park, Cebu City')).bottom,
      lessThanOrEqualTo(tester.getRect(find.byType(MapSearchPill)).bottom),
    );
  });

  for (final scale in [1.3, 2.0]) {
    group('at text scale $scale, 360pt wide', () {
      testWidgets('menu highlights strip fits its cards', (tester) async {
        await _pumpAt(tester, scale, MenuHighlights(width: 140, cafe: _cafe()));
        expect(tester.takeException(), isNull);
        _expectNotClipped(tester, find.textContaining('₱'));
      });

      testWidgets('review preview cards fit their review', (tester) async {
        final bloc = _StubReviewsBloc(
          ReviewsLoaded(
            cafeId: 'cafe-1',
            reviews: [_review('1'), _review('2', helpful: 0)],
          ),
        );
        addTearDown(bloc.close);
        final block = FakeBlockCubit();
        addTearDown(block.close);
        await _pumpAt(
          tester,
          scale,
          MultiBlocProvider(
            providers: [
              BlocProvider<ReviewsBloc>.value(value: bloc),
              BlocProvider<BlockCubit>.value(value: block),
            ],
            child: ReviewsPreviewSection(
              onSeeAllTap: () {},
              onWriteReviewTap: () {},
            ),
          ),
        );
        expect(tester.takeException(), isNull);
        _expectNotClipped(tester, find.text('Helpful · 3'));
      });

      testWidgets('review row header fits name and date', (tester) async {
        await _pumpAt(
          tester,
          scale,
          ReviewRow(review: _review('1'), currentUserId: 'me'),
        );
        expect(tester.takeException(), isNull);
        _expectNotClipped(tester, find.text('Sep 1, 2026'));
      });

      testWidgets('lists sheet header fits its title', (tester) async {
        await _pumpAt(
          tester,
          scale,
          ListsSheet(
            title: 'Add to your gallery',
            onBack: () {},
            children: const [SizedBox(height: 40)],
          ),
          scroll: false,
        );
        expect(tester.takeException(), isNull);
        _expectNotClipped(tester, find.text('Add to your gallery'));
      });

      testWidgets('sheet title row fits its title, with a 44pt close', (
        tester,
      ) async {
        await _pumpAt(tester, scale, const SheetTitleRow(title: 'Search near'));
        expect(tester.takeException(), isNull);
        _expectNotClipped(tester, find.text('Search near'));
        expect(
          tester.getSize(find.bySemanticsLabel('Close')).height,
          greaterThanOrEqualTo(44),
        );
      });

      testWidgets('map search pill and toggle grow together', (tester) async {
        await _pumpAt(
          tester,
          scale,
          Row(
            children: [
              const Expanded(
                child: MapSearchPill(origin: 'IT Park, Cebu City'),
              ),
              MapListToggleButton(listOpen: false, onTap: () {}),
            ],
          ),
        );
        expect(tester.takeException(), isNull);
        final pill = tester.getSize(find.byType(MapSearchPill));
        final toggle = tester.getSize(find.byType(MapListToggleButton));
        expect(pill.height, toggle.height);
        expect(pill.height, greaterThanOrEqualTo(MapSearchPill.height));
        // Both lines sit inside the pill.
        final box = tester.getRect(find.byType(MapSearchPill));
        expect(
          tester.getRect(find.text('IT Park, Cebu City')).bottom,
          lessThanOrEqualTo(box.bottom),
        );
      });

      testWidgets('cafe header status line wraps instead of overflowing', (
        tester,
      ) async {
        await _pumpAt(tester, scale, CafeInfoHeader(cafe: _cafe()));
        expect(tester.takeException(), isNull);
        expect(find.text('Closed'), findsOneWidget);
        _expectNotClipped(tester, find.textContaining('opens 7 AM'));
      });
    });
  }

  test('map pill height is the design 52 at the default text size', () {
    expect(MapSearchPill.heightFor(TextScaler.noScaling), 52);
    expect(
      MapSearchPill.heightFor(const TextScaler.linear(2)),
      greaterThan(52 + 30),
    );
  });
}
