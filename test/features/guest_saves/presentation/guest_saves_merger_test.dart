import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nook/core/analytics/saves_events.dart';
import 'package:nook/core/cafe/domain/entities/cafe_status.dart';
import 'package:nook/core/cafe/domain/repositories/i_cafe_repository.dart';
import 'package:nook/core/cafe/domain/use_cases/get_cafe_statuses_usecase.dart';
import 'package:nook/core/cafe/domain/use_cases/set_cafe_status_usecase.dart';
import 'package:nook/core/cafe/presentation/cafe_status_cubit.dart';
import 'package:nook/features/guest_saves/data/guest_saves_store.dart';
import 'package:nook/features/guest_saves/domain/cafe_snapshot.dart';
import 'package:nook/features/guest_saves/presentation/cubit/guest_saves_cubit.dart';
import 'package:nook/features/guest_saves/presentation/guest_saves_merger.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/analytics/recording_analytics.dart';

class _StatusRepository implements ICafeRepository {
  Map<String, CafeStatus> server = {};
  bool failRead = false;
  Set<String> failWriteFor = {};
  final List<String> writes = [];

  @override
  Future<Map<String, CafeStatus>> getCafeStatuses(List<String> cafeIds) async {
    if (failRead) throw Exception('offline');
    return {
      for (final id in cafeIds)
        if (server[id] != null) id: server[id]!,
    };
  }

  @override
  Future<CafeStatus> setCafeStatus(String cafeId, CafeStatus status) async {
    if (failWriteFor.contains(cafeId)) throw Exception('offline');
    writes.add(cafeId);
    return server[cafeId] = status;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

CafeSnapshot _cafe(String id) => CafeSnapshot(id: id, name: 'Cafe $id');

void main() {
  late RecordingAnalytics analytics;
  late _StatusRepository repo;
  late CafeStatusCubit statuses;
  late GuestSavesCubit saves;
  late GuestSavesMerger merger;
  var clock = DateTime.utc(2026, 10, 1);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    analytics = RecordingAnalytics.install(addTearDown);
    repo = _StatusRepository();
    statuses = CafeStatusCubit(
      getCafeStatusesUseCase: GetCafeStatusesUseCase(repo),
      setCafeStatusUseCase: SetCafeStatusUseCase(repo),
    );
    clock = DateTime.utc(2026, 10, 1);
    saves = GuestSavesCubit(
      store: GuestSavesStore(),
      now: () => clock = clock.add(const Duration(minutes: 1)),
    );
    merger = GuestSavesMerger(saves: saves, statuses: statuses);
  });

  tearDown(() async {
    await saves.close();
    await statuses.close();
  });

  test('pushes every save through set_cafe_status, oldest first, and '
      'clears the phone', () async {
    await saves.set(_cafe('a'), CafeStatus.wantToTry);
    await saves.set(_cafe('b'), CafeStatus.been);
    analytics.events.clear();

    final merged = (await merger.merge()).added;

    expect(merged, 2);
    expect(repo.writes, ['a', 'b']);
    expect(repo.server, {'a': CafeStatus.wantToTry, 'b': CafeStatus.been});
    expect(saves.state.isEmpty, isTrue);
    expect(await GuestSavesStore().read(), isEmpty);
    expect(analytics.names, [SavesEvents.guestSavesMerged]);
    expect(analytics.propertiesOf(SavesEvents.guestSavesMerged), {
      'count': 2,
      'moved': 2,
      'failed': 0,
    });
  });

  test('a cafe the account already has keeps the account status and is '
      'not counted', () async {
    repo.server = {'a': CafeStatus.been};
    await saves.set(_cafe('a'), CafeStatus.wantToTry);
    await saves.set(_cafe('b'), CafeStatus.wantToTry);

    final result = await merger.merge();

    expect(result.added, 1);
    // Both are in the account now, so both count as moved for the toast.
    expect(result.moved, 2);
    expect(result.failed, 0);
    expect(repo.writes, ['b']);
    expect(repo.server['a'], CafeStatus.been);
    expect(saves.state.isEmpty, isTrue);
  });

  test("a phone Been moves the account's Want to try on to Been; an "
      "account Been is never written over", () async {
    repo.server = {'a': CafeStatus.wantToTry, 'b': CafeStatus.been};
    await saves.set(_cafe('a'), CafeStatus.been);
    await saves.set(_cafe('b'), CafeStatus.wantToTry);

    final result = await merger.merge();

    expect(repo.writes, ['a']);
    expect(repo.server, {'a': CafeStatus.been, 'b': CafeStatus.been});
    expect(result.added, 1);
    expect(result.moved, 2);
    expect(saves.state.isEmpty, isTrue);
  });

  test('the guest overlay does not make saves look already merged', () async {
    await saves.set(_cafe('a'), CafeStatus.wantToTry);
    statuses.showLocal(saves.state.statusMap);

    expect((await merger.merge()).added, 1);
    expect(repo.writes, ['a']);
    expect(statuses.state.local, isEmpty);
  });

  test('a failed read at sign-in does not trust statuses "known" from a '
      'guest read, so the account\'s Been is never overwritten', () async {
    // As a guest, Home read the feed's statuses: the server answers a
    // signed-out read with nothing, so every cafe is "known" as none.
    await statuses.loadFor(['a']);
    expect(statuses.state.isKnown('a'), isTrue);
    await saves.set(_cafe('a'), CafeStatus.wantToTry);
    // Signed in to an account that has 'a' as Been; the merge's read fails.
    repo.server = {'a': CafeStatus.been};
    repo.failRead = true;

    final result = await merger.merge();

    expect(result.added, 0);
    expect(result.failed, 1);
    expect(repo.writes, isEmpty);
    expect(repo.server['a'], CafeStatus.been);
    expect(saves.state.statusFor('a'), CafeStatus.wantToTry);
  });

  test('a signed-out status read caches nothing, so "known: none" never '
      'outlives the sign-in', () async {
    var signedIn = false;
    final guarded = CafeStatusCubit(
      getCafeStatusesUseCase: GetCafeStatusesUseCase(repo),
      setCafeStatusUseCase: SetCafeStatusUseCase(repo),
      hasSession: () => signedIn,
    );
    addTearDown(guarded.close);
    repo.server = {'x': CafeStatus.been};

    expect(await guarded.loadFor(['x']), isFalse);
    expect(guarded.state.isKnown('x'), isFalse);

    signedIn = true;
    expect(await guarded.loadFor(['x']), isTrue);
    expect(guarded.state.statusFor('x'), CafeStatus.been);
  });

  test(
    'a failed read writes nothing and keeps the saves for next launch',
    () async {
      repo.failRead = true;
      await saves.set(_cafe('a'), CafeStatus.wantToTry);
      analytics.events.clear();

      final result = await merger.merge();
      expect(result.added, 0);
      expect(result.failed, 1);
      expect(repo.writes, isEmpty);
      expect(saves.state.statusFor('a'), CafeStatus.wantToTry);
      // Reported, so failed moves can be counted.
      expect(analytics.propertiesOf(SavesEvents.guestSavesMerged), {
        'count': 0,
        'moved': 0,
        'failed': 1,
      });
    },
  );

  test('a failed write keeps only that save; a retry finishes it', () async {
    repo.failWriteFor = {'b'};
    await saves.set(_cafe('a'), CafeStatus.wantToTry);
    await saves.set(_cafe('b'), CafeStatus.been);

    final first = await merger.merge();
    expect(first.added, 1);
    expect(first.failed, 1);
    expect(first.total, 2);
    expect([for (final s in saves.state.saves) s.cafeId], ['b']);

    repo.failWriteFor = {};
    expect((await merger.merge()).added, 1);
    expect(saves.state.isEmpty, isTrue);
    expect(repo.server, {'a': CafeStatus.wantToTry, 'b': CafeStatus.been});
  });

  test('nothing to merge logs nothing', () async {
    expect((await merger.merge()).isEmpty, isTrue);
    expect(analytics.events, isEmpty);
  });

  test('a sign-out after a failed merge drops the leftovers, so the next '
      'account does not get them', () async {
    await saves.set(_cafe('a'), CafeStatus.wantToTry);
    repo.failRead = true;

    expect((await merger.merge()).added, 0);
    expect(saves.state.saves, hasLength(1));

    await merger.discardLeftovers();

    expect(saves.state.isEmpty, isTrue);
    expect(await GuestSavesStore().read(), isEmpty);
  });

  test(
    'the sign-out discard also drops entries this build cannot read',
    () async {
      SharedPreferences.setMockInitialValues({
        'guest_saves_v1': jsonEncode([
          {
            'cafe': {'id': 'a', 'name': 'Cafe A'},
            'status': 'want_to_try',
            'saved_at': '2026-09-01T00:00:00Z',
          },
          {
            'cafe': {'id': 'x'},
            'status': 'from_a_newer_build',
          },
        ]),
      });
      repo.failRead = true;
      expect((await merger.merge()).failed, 1);

      await merger.discardLeftovers();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('guest_saves_v1'), isNull);
    },
  );

  test('a sign-out with no merge tried keeps the guest\'s saves', () async {
    await saves.set(_cafe('a'), CafeStatus.wantToTry);

    await merger.discardLeftovers();

    expect(saves.state.saves, hasLength(1));
  });
}
