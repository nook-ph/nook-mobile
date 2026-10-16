import 'package:flutter_test/flutter_test.dart';
import 'package:nook/features/guest_saves/data/guest_saves_store.dart';
import 'package:nook/features/guest_saves/domain/cafe_snapshot.dart';
import 'package:nook/features/guest_saves/presentation/cubit/recently_viewed_cubit.dart';
import 'package:shared_preferences/shared_preferences.dart';

CafeSnapshot _cafe(String id) => CafeSnapshot(id: id, name: 'Cafe $id');

void main() {
  late RecentlyViewedStore store;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    store = RecentlyViewedStore();
  });

  List<String> ids(List<RecentlyViewedCafe> entries) => [
    for (final e in entries) e.cafe.id,
  ];

  test(
    'newest first, a revisit moves to the front without a duplicate',
    () async {
      final cubit = RecentlyViewedCubit(store: store);
      await cubit.record(_cafe('a'));
      await cubit.record(_cafe('b'));
      await cubit.record(_cafe('a'));

      expect(ids(cubit.state), ['a', 'b']);
      await cubit.close();
    },
  );

  test('a sign-out during the first read does not bring the views back',
      () async {
    final first = RecentlyViewedCubit(store: store);
    await first.record(_cafe('a'));
    await first.close();

    final cubit = RecentlyViewedCubit(store: store);
    final loading = cubit.load();
    await cubit.clear();
    await loading;

    expect(cubit.state, isEmpty);
    await cubit.close();
  });

  test('keeps the last ten, and they survive a restart', () async {
    final cubit = RecentlyViewedCubit(store: store);
    for (var i = 0; i < 12; i++) {
      await cubit.record(_cafe('$i'));
    }
    expect(cubit.state, hasLength(RecentlyViewedStore.maxEntries));
    expect(cubit.state.first.cafe.id, '11');
    await cubit.close();

    final next = RecentlyViewedCubit(store: store);
    await next.load();
    expect(ids(next.state), [
      '11',
      '10',
      '9',
      '8',
      '7',
      '6',
      '5',
      '4',
      '3',
      '2',
    ]);
    await next.close();
  });

  test('clear empties the row and the phone', () async {
    final cubit = RecentlyViewedCubit(store: store);
    await cubit.record(_cafe('a'));

    await cubit.clear();

    expect(cubit.state, isEmpty);
    expect(await store.read(), isEmpty);
    await cubit.close();
  });
}
