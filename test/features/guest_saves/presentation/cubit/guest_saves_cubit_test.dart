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

  test('removing a save logs nothing', () async {
    final cubit = newCubit();
    await cubit.set(_a, CafeStatus.wantToTry);
    analytics.events.clear();

    await cubit.set(_a, CafeStatus.none);

    expect(analytics.events, isEmpty);
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

    expect(await cubit.claimKeepSavesPrompt(), isTrue);
    expect(await cubit.claimKeepSavesPrompt(), isFalse);
    expect(await newCubit().claimKeepSavesPrompt(), isFalse);
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
}
