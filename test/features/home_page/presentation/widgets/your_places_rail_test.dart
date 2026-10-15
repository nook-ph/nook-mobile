import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/core/analytics/retention_tracking_events.dart';
import 'package:nook/core/analytics/screen_tracking.dart';
import 'package:nook/core/cafe/domain/entities/cafe_status.dart';
import 'package:nook/core/cafe/domain/entities/cafe_summary.dart';
import 'package:nook/core/cafe/domain/repositories/i_cafe_repository.dart';
import 'package:nook/core/cafe/domain/use_cases/get_cafe_statuses_usecase.dart';
import 'package:nook/core/cafe/domain/use_cases/set_cafe_status_usecase.dart';
import 'package:nook/core/cafe/presentation/cafe_status_cubit.dart';
import 'package:nook/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:nook/features/guest_saves/data/guest_saves_store.dart';
import 'package:nook/features/guest_saves/domain/cafe_snapshot.dart';
import 'package:nook/features/guest_saves/presentation/cubit/guest_saves_cubit.dart';
import 'package:nook/features/guest_saves/presentation/cubit/recently_viewed_cubit.dart';
import 'package:nook/features/home_page/presentation/widgets/home_cafe_card.dart';
import 'package:nook/features/home_page/presentation/widgets/home_rail_impression.dart';
import 'package:nook/features/home_page/presentation/widgets/your_places_rail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/analytics/recording_analytics.dart';
import '../../../auth/fake_auth_bloc.dart';

CafeSummary _summary(String id) =>
    CafeSummary(id: id, name: 'Cafe $id', address: '', rating: 0);

class _NoRepository implements ICafeRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

CafeSnapshot _snap(String id) => CafeSnapshot(id: id, name: 'Cafe $id');

void main() {
  group('yourPlaces', () {
    test('Want to Try first, then recent cafes not already in it', () {
      final out = yourPlaces(
        wantToTry: [_summary('a'), _summary('b')],
        recent: [_summary('b'), _summary('c')],
      );

      expect([for (final c in out) c.id], ['a', 'b', 'c']);
    });

    test('stops at max', () {
      final out = yourPlaces(
        wantToTry: [for (var i = 0; i < 4; i++) _summary('w$i')],
        recent: [for (var i = 0; i < 4; i++) _summary('r$i')],
        max: 5,
      );

      expect([for (final c in out) c.id], ['w0', 'w1', 'w2', 'w3', 'r0']);
    });

    test('empty in, empty out', () {
      expect(yourPlaces(wantToTry: const [], recent: const []), isEmpty);
    });
  });

  group('YourPlacesRail (guest)', () {
    late GuestSavesCubit saves;
    late RecentlyViewedCubit recent;
    late FakeAuthBloc auth;
    late CafeStatusCubit statuses;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
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

    Future<void> pump(WidgetTester tester) => tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider.value(value: saves),
          BlocProvider.value(value: recent),
          BlocProvider<AuthBloc>.value(value: auth),
          BlocProvider.value(value: statuses),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: YourPlacesRail(isSignedIn: () => false),
            ),
          ),
        ),
      ),
    );

    testWidgets('renders nothing while there is nothing of the person\'s', (
      tester,
    ) async {
      await pump(tester);
      await tester.pumpAndSettle();

      expect(find.text(YourPlacesRail.title), findsNothing);
      expect(find.byType(HomeCafeCard), findsNothing);
    });

    testWidgets('shows Been progress while something is on Want to Try', (
      tester,
    ) async {
      await tester.runAsync(() async {
        await saves.set(_snap('w'), CafeStatus.wantToTry);
        await saves.set(_snap('b'), CafeStatus.been);
        await recent.record(_snap('r'));
      });
      await pump(tester);
      await tester.pump();
      expect(find.text('Been to 1 of 2'), findsOneWidget);

      // Nothing left to try: the row still shows recent cafes, without a
      // count that has no goal left.
      await tester.runAsync(() => saves.set(_snap('w'), CafeStatus.been));
      await tester.pump();
      expect(find.text(YourPlacesRail.title), findsOneWidget);
      expect(find.textContaining('Been to'), findsNothing);
    });

    testWidgets('shows Want to Try before recently viewed', (tester) async {
      await tester.runAsync(() async {
        await recent.record(_snap('r'));
        await saves.set(_snap('w'), CafeStatus.wantToTry);
        // Been is not part of the row's Want to Try.
        await saves.set(_snap('b'), CafeStatus.been);
      });
      await pump(tester);
      await tester.pump();

      expect(find.text(YourPlacesRail.title), findsOneWidget);
      final cards = tester
          .widgetList<HomeCafeCard>(find.byType(HomeCafeCard))
          // The row measures itself with a skeleton prototype card.
          .where((c) => !c.isSkeleton)
          .toList();
      expect([for (final c in cards) c.cafe.id], ['w', 'r']);
      expect(cards.first.section, YourPlacesRail.railId);
      expect([for (final c in cards) c.position], [0, 1]);
    });

    testWidgets('logs its impression and card taps as the your_places rail', (
      tester,
    ) async {
      final analytics = RecordingAnalytics.install(addTearDown);
      HomeRailImpression.resetForTest();
      ScreenTracker.instance.resetForTest();
      await tester.runAsync(() => saves.set(_snap('w'), CafeStatus.wantToTry));
      await pump(tester);
      await tester.pump();
      await tester.pump();

      expect(analytics.propertiesOf(HomeRailEvents.impression), {
        'rail': YourPlacesRail.railId,
      });
      final card = tester
          .widgetList<HomeCafeCard>(find.byType(HomeCafeCard))
          .firstWhere((c) => !c.isSkeleton);
      expect(card.rail, YourPlacesRail.railId);
    });
  });
}
