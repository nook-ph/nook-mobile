import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nook/core/analytics/saves_events.dart';
import 'package:nook/core/cafe/domain/entities/cafe_status.dart';
import 'package:nook/features/guest_saves/data/guest_saves_store.dart';
import 'package:nook/features/guest_saves/domain/cafe_snapshot.dart';
import 'package:nook/features/guest_saves/presentation/cubit/guest_saves_cubit.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/analytics/recording_analytics.dart';

const _a = CafeSnapshot(id: 'a', name: 'Cafe A');
const _b = CafeSnapshot(id: 'b', name: 'Cafe B');

void main() {
  late RecordingAnalytics analytics;
  late GuestSavesStore store;
  var clock = DateTime.utc(2026, 10, 1);

  GuestSavesCubit newCubit() => GuestSavesCubit(store: store, now: () => clock);

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    analytics = RecordingAnalytics.install(addTearDown);
    store = GuestSavesStore();
    clock = DateTime.utc(2026, 10, 1);
  });

  test('a save is kept on the phone and read back by a new session', () async {
    final cubit = newCubit();
    await cubit.set(_a, CafeStatus.wantToTry);
    clock = clock.add(const Duration(minutes: 1));
    await cubit.set(_b, CafeStatus.been);
    await cubit.close();

    final next = newCubit();
    await next.load();

    expect(next.state.loaded, isTrue);
    // Newest first.
    expect([for (final s in next.state.saves) s.cafeId], ['b', 'a']);
    expect(next.state.statusFor('a'), CafeStatus.wantToTry);
    expect(next.state.statusFor('b'), CafeStatus.been);
    expect(next.state.statusMap, {
      'a': CafeStatus.wantToTry,
      'b': CafeStatus.been,
    });
    await next.close();
  });

  test('undo after Been puts the Want to try back as it was, in place, '
      'with no new guest_save_created', () async {
    final cubit = newCubit();
    await cubit.set(_a, CafeStatus.wantToTry);
    clock = clock.add(const Duration(minutes: 1));
    await cubit.set(_b, CafeStatus.wantToTry);
    final original = cubit.state.saves.firstWhere((s) => s.cafeId == 'a');
    clock = clock.add(const Duration(minutes: 1));
    final outcome = await cubit.set(_a, CafeStatus.been);
    expect([for (final s in cubit.state.saves) s.cafeId], ['a', 'b']);
    analytics.events.clear();

    expect(await cubit.undo('a', outcome!), isTrue);

    expect([for (final s in cubit.state.saves) s.cafeId], ['b', 'a']);
    expect(cubit.state.saves.last, original);
    expect(analytics.names, isEmpty);
    expect((await store.read()).last, original);
    await cubit.close();
  });

  test('undo of a removal restores the save without logging a creation; '
      'undo of a new save takes it off', () async {
    final cubit = newCubit();
    await cubit.set(_a, CafeStatus.been);
    final original = cubit.state.saves.single;
    clock = clock.add(const Duration(minutes: 1));
    await cubit.set(_b, CafeStatus.wantToTry);
    final removed = await cubit.set(_a, CafeStatus.none);
    analytics.events.clear();

    await cubit.undo('a', removed!);
    expect(cubit.state.saves.last, original);
    expect(analytics.names, isEmpty);

    final added = await cubit.set(
      const CafeSnapshot(id: 'c', name: 'Cafe C'),
      CafeStatus.wantToTry,
    );
    analytics.events.clear();
    await cubit.undo('c', added!);
    expect(cubit.state.statusFor('c'), CafeStatus.none);
    expect(analytics.names, [SavesEvents.guestSaveRemoved]);
    await cubit.close();
  });

  test('changing a status replaces it; none removes the save', () async {
    final cubit = newCubit();
    await cubit.set(_a, CafeStatus.wantToTry);

    final moved = await cubit.set(_a, CafeStatus.been);
    expect(moved!.previous, CafeStatus.wantToTry);
    expect(cubit.state.saves, hasLength(1));
    expect(cubit.state.statusFor('a'), CafeStatus.been);

    final removed = await cubit.set(_a, CafeStatus.none);
    expect(removed!.previous, CafeStatus.been);
    expect(cubit.state.isEmpty, isTrue);
    expect(await store.read(), isEmpty);
    await cubit.close();
  });

  test('logs guest_save_created per save and first_save only once', () async {
    final cubit = newCubit();

    final first = await cubit.set(_a, CafeStatus.wantToTry);
    final second = await cubit.set(_b, CafeStatus.been);

    expect(first!.firstSave, isTrue);
    expect(second!.firstSave, isFalse);
    expect(
      analytics.names.where((n) => n == SavesEvents.guestSaveCreated),
      hasLength(2),
    );
    expect(analytics.names.where((n) => n == SavesEvents.firstSave), [
      SavesEvents.firstSave,
    ]);
    expect(analytics.propertiesOf(SavesEvents.firstSave), {
      'status': 'want_to_try',
      'guest': true,
    });
    expect(analytics.propertiesOf(SavesEvents.guestSaveCreated), {
      'status': 'been',
    });
    await cubit.close();
  });

  test('removing a save logs guest_save_removed with its source', () async {
    final cubit = newCubit();
    await cubit.set(_a, CafeStatus.wantToTry);
    analytics.events.clear();

    await cubit.set(_a, CafeStatus.none, source: SavesSource.undo);

    expect(analytics.names, [SavesEvents.guestSaveRemoved]);
    expect(analytics.propertiesOf(SavesEvents.guestSaveRemoved), {
      'source': 'undo',
    });
    await cubit.close();
  });

  test('removeAll drops only the given cafes', () async {
    final cubit = newCubit();
    await cubit.set(_a, CafeStatus.wantToTry);
    await cubit.set(_b, CafeStatus.been);

    await cubit.removeAll({'a'});

    expect([for (final s in cubit.state.saves) s.cafeId], ['b']);
    expect([for (final s in await store.read()) s.cafeId], ['b']);
    await cubit.close();
  });

  test('the keep-saves prompt is claimed once per phone', () async {
    final cubit = newCubit();

    expect(await cubit.claimFirstSaveLine(), isTrue);
    expect(await cubit.claimFirstSaveLine(), isFalse);
    expect(await newCubit().claimFirstSaveLine(), isFalse);
    await cubit.close();
  });

  test('a corrupt store reads as no saves', () async {
    SharedPreferences.setMockInitialValues({'guest_saves_v1': '{not json'});
    final cubit = newCubit();

    await cubit.load();

    expect(cubit.state.loaded, isTrue);
    expect(cubit.state.isEmpty, isTrue);
    await cubit.close();
  });

  test('a corrupt store is set aside, not written over', () async {
    SharedPreferences.setMockInitialValues({'guest_saves_v1': '{not json'});
    final cubit = newCubit();

    await cubit.set(_a, CafeStatus.wantToTry);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('guest_saves_v1_unreadable'), '{not json');
    expect([for (final s in await store.read()) s.cafeId], ['a']);
    await cubit.close();
  });

  test('one bad entry costs only that entry, and a new save keeps the '
      'rest', () async {
    SharedPreferences.setMockInitialValues({
      'guest_saves_v1': jsonEncode([
        {
          'cafe': {'id': 'a', 'name': 'Cafe A', 'rating': '4.5'},
          'status': 'want_to_try',
          'saved_at': '2026-09-01T00:00:00Z',
        },
        {'cafe': 'not a map', 'status': 42, 'saved_at': 7},
        {
          'cafe': {'id': 'b', 'name': 'Cafe B', 'lat': 'x'},
          'status': 'been',
          'saved_at': '2026-09-02T00:00:00Z',
        },
      ]),
    });
    final cubit = newCubit();
    await cubit.load();

    expect([for (final s in cubit.state.saves) s.cafeId], ['a', 'b']);
    expect(cubit.state.saves.first.cafe.rating, 0);

    await cubit.set(
      const CafeSnapshot(id: 'c', name: 'Cafe C'),
      CafeStatus.been,
    );
    expect([for (final s in await store.read()) s.cafeId], ['c', 'a', 'b']);
    // The entry this build can't read is still on disk after the write.
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonDecode(prefs.getString('guest_saves_v1')!) as List;
    expect(raw, hasLength(4));
    expect(raw.last, {'cafe': 'not a map', 'status': 42, 'saved_at': 7});
    // Even once every readable save is gone.
    await cubit.removeAll({'a', 'b', 'c'});
    final left = jsonDecode(prefs.getString('guest_saves_v1')!) as List;
    expect(left, [
      {'cafe': 'not a map', 'status': 42, 'saved_at': 7},
    ]);
    await cubit.close();
  });

  test('when the phone cannot be read, nothing is written over the saves '
      'and the next load tries again', () async {
    final failing = _FailingStore();
    final cubit = GuestSavesCubit(store: failing, now: () => clock);

    await cubit.load();
    expect(cubit.state.loaded, isTrue);
    // Loaded but unknown: the home-screen widget must not read it as empty.
    expect(cubit.readFailed, isTrue);
    expect(await cubit.set(_a, CafeStatus.wantToTry), isNull);
    await cubit.removeAll({'a'});
    expect(failing.writes, 0);

    failing.fail = false;
    expect(await cubit.set(_a, CafeStatus.wantToTry), isNotNull);
    expect(cubit.readFailed, isFalse);
    expect(failing.writes, 1);
    await cubit.close();
  });
}

class _FailingStore extends GuestSavesStore {
  bool fail = true;
  int writes = 0;

  @override
  Future<List<GuestSave>> read() async {
    if (fail) throw const GuestSavesReadException('disk');
    return const [];
  }

  @override
  Future<void> write(
    List<GuestSave> saves, {
    bool dropUnreadable = false,
  }) async => writes++;
}
