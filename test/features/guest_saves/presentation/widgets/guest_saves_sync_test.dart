import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/core/analytics/saves_events.dart';
import 'package:nook/core/cafe/domain/entities/cafe_status.dart';
import 'package:nook/core/presentation/session_ask_budget.dart';
import 'package:nook/core/cafe/domain/repositories/i_cafe_repository.dart';
import 'package:nook/core/cafe/domain/use_cases/get_cafe_statuses_usecase.dart';
import 'package:nook/core/cafe/domain/use_cases/set_cafe_status_usecase.dart';
import 'package:nook/core/cafe/presentation/cafe_status_cubit.dart';
import 'package:nook/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:nook/features/guest_saves/data/guest_saves_store.dart';
import 'package:nook/features/guest_saves/domain/cafe_snapshot.dart';
import 'package:nook/features/guest_saves/presentation/cubit/guest_saves_cubit.dart';
import 'package:nook/features/guest_saves/presentation/cubit/recently_viewed_cubit.dart';
import 'package:nook/features/guest_saves/presentation/widgets/guest_saves_sync.dart';
import 'package:nook/features/guest_saves/presentation/widgets/merge_ask_sheet.dart';
import 'package:nook/features/lists/bloc/lists_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;

import '../../../../core/analytics/recording_analytics.dart';
import '../../../auth/fake_auth_bloc.dart';
import '../../../profile/profile_test_support.dart';

class _Repo implements ICafeRepository {
  final Map<String, CafeStatus> server = {};
  final List<String> writes = [];
  bool failRead = false;
  Set<String> failWriteFor = {};

  @override
  Future<Map<String, CafeStatus>> getCafeStatuses(List<String> ids) async {
    if (failRead) throw Exception('offline');
    return {
      for (final id in ids)
        if (server[id] != null) id: server[id]!,
    };
  }

  @override
  Future<CafeStatus> setCafeStatus(String id, CafeStatus status) async {
    if (failWriteFor.contains(id)) throw Exception('offline');
    writes.add(id);
    return server[id] = status;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

User _user(String id) => User(
  id: id,
  appMetadata: const {},
  userMetadata: const {},
  aud: 'authenticated',
  createdAt: '2026-10-16T00:00:00Z',
);

CafeSnapshot _cafe(String id) => CafeSnapshot(id: id, name: 'Cafe $id');

/// The app around [GuestSavesSync], with a navigator for the toast and the
/// merge ask, and a session the test switches.
class _Harness {
  _Harness(this.tester, {AuthState? initial})
    : auth = FakeAuthBloc(initial ?? const AuthUnauthenticated());

  final WidgetTester tester;
  final repo = _Repo();
  final saves = GuestSavesCubit(store: GuestSavesStore());
  late final statuses = CafeStatusCubit(
    getCafeStatusesUseCase: GetCafeStatusesUseCase(repo),
    setCafeStatusUseCase: SetCafeStatusUseCase(repo),
    hasSession: () => signedIn,
  );
  final recent = RecentlyViewedCubit(store: RecentlyViewedStore());
  final FakeAuthBloc auth;
  final lists = FakeListsBloc();
  final navigator = GlobalKey<NavigatorState>();
  bool signedIn = false;

  Future<void> pump() async {
    addTearDown(() async {
      await saves.close();
      await statuses.close();
      await recent.close();
      await auth.close();
      await lists.close();
    });
    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider<GuestSavesCubit>.value(value: saves),
          BlocProvider<CafeStatusCubit>.value(value: statuses),
          BlocProvider<RecentlyViewedCubit>.value(value: recent),
          BlocProvider<AuthBloc>.value(value: auth),
          BlocProvider<ListsBloc>.value(value: lists),
        ],
        child: GuestSavesSync(
          isSignedIn: () => signedIn,
          toastContext: () => navigator.currentContext,
          child: MaterialApp(
            navigatorKey: navigator,
            home: const Scaffold(body: SizedBox()),
          ),
        ),
      ),
    );
    await settle();
  }

  /// Lets the merge, the store and the ask's waits run.
  Future<void> settle() async {
    for (var i = 0; i < 12; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> signIn(String id) async {
    signedIn = true;
    auth.push(AuthAuthenticated(_user(id)));
    await settle();
  }

  Future<void> signOut() async {
    signedIn = false;
    auth.push(const AuthLoggedOut());
    await settle();
  }

  /// A merge into [id] that fails at the status read, leaving every save
  /// on the phone marked as [id]'s; then a sign-out.
  Future<void> failedMergeFor(String id) async {
    repo.failRead = true;
    await signIn(id);
    repo.failRead = false;
    await signOut();
    await clearToasts();
  }

  Future<void> clearToasts() async {
    await tester.pump(const Duration(seconds: 10));
    await tester.pumpAndSettle();
  }
}

void main() {
  late RecordingAnalytics analytics;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    SessionAskBudget.instance.resetForTest();
    analytics = RecordingAnalytics.install(addTearDown);
  });

  testWidgets('sign-out keeps the saves a merge could not move as guest '
      'saves, and not the ones it moved', (tester) async {
    final app = _Harness(tester);
    await tester.runAsync(() async {
      await app.saves.set(_cafe('a'), CafeStatus.wantToTry);
      await app.saves.set(_cafe('b'), CafeStatus.been);
    });
    await app.pump();
    app.repo.failWriteFor = {'a'};

    await app.signIn('u1');
    expect(app.repo.server, {'b': CafeStatus.been});
    await app.signOut();

    expect([for (final s in app.saves.state.saves) s.cafeId], ['a']);
    // Shown again as the guest's: the badges, pills and Your places read
    // these.
    expect(app.statuses.state.local, {'a': CafeStatus.wantToTry});
    final stored = await tester.runAsync(() => GuestSavesStore().read());
    expect([for (final s in stored!) s.cafeId], ['a']);
    await app.clearToasts();
  });

  testWidgets('a status read that failed at sign-in moves nothing, and '
      'sign-out keeps every save', (tester) async {
    final app = _Harness(tester);
    await tester.runAsync(() async {
      await app.saves.set(_cafe('a'), CafeStatus.wantToTry);
      await app.saves.set(_cafe('b'), CafeStatus.been);
    });
    await app.pump();

    await app.failedMergeFor('u1');

    expect(app.saves.state.saves, hasLength(2));
    expect(app.statuses.state.local, {
      'a': CafeStatus.wantToTry,
      'b': CafeStatus.been,
    });
  });

  testWidgets('the same account signing back in takes its leftovers with '
      'no ask', (tester) async {
    final app = _Harness(tester);
    await tester.runAsync(
      () => app.saves.set(_cafe('a'), CafeStatus.wantToTry),
    );
    await app.pump();
    await app.failedMergeFor('u1');

    await app.signIn('u1');

    expect(find.text(MergeAskSheet.titleFor(1)), findsNothing);
    expect(app.repo.server, {'a': CafeStatus.wantToTry});
    expect(app.saves.state.isEmpty, isTrue);
    expect(find.text('Moved 1 cafe to your account'), findsOneWidget);
    expect(analytics.names, isNot(contains(SavesEvents.guestSavesMergeAsked)));
    await app.clearToasts();
  });

  testWidgets('saves made while signed out move into whoever signs in, '
      'with no ask', (tester) async {
    final app = _Harness(tester);
    await tester.runAsync(
      () => app.saves.set(_cafe('a'), CafeStatus.wantToTry),
    );
    await app.pump();

    await app.signIn('u2');

    expect(find.byType(MergeAskSheet), findsNothing);
    expect(app.repo.server, {'a': CafeStatus.wantToTry});
    await app.clearToasts();
  });

  testWidgets('another account asks first; Add them moves the saves', (
    tester,
  ) async {
    final app = _Harness(tester);
    await tester.runAsync(() async {
      await app.saves.set(_cafe('a'), CafeStatus.wantToTry);
      await app.saves.set(_cafe('b'), CafeStatus.been);
    });
    await app.pump();
    await app.failedMergeFor('u1');
    analytics.events.clear();

    await app.signIn('u2');

    // Nothing moved before the answer.
    expect(app.repo.writes, isEmpty);
    expect(find.text(MergeAskSheet.titleFor(2)), findsOneWidget);
    expect(
      find.text(
        'Cafe b and Cafe a were saved on this phone before. Add them to '
        'your account?',
      ),
      findsOneWidget,
    );
    expect(analytics.propertiesOf(SavesEvents.guestSavesMergeAsked), {
      'count': 2,
    });
    expect(SessionAskBudget.instance.spentBy, SessionAskKind.mergeAsk);

    await tester.tap(find.text(MergeAskSheet.addLabel));
    await app.settle();

    expect(find.byType(MergeAskSheet), findsNothing);
    expect(app.repo.server, {'a': CafeStatus.wantToTry, 'b': CafeStatus.been});
    expect(app.saves.state.isEmpty, isTrue);
    expect(analytics.propertiesOf(SavesEvents.guestSavesMergeAnswered), {
      'count': 2,
      'answer': 'add',
    });
    expect(find.text('Moved 2 cafes to your account'), findsOneWidget);
    await app.clearToasts();
  });

  testWidgets('Not now keeps them on the phone, not this account\'s, and '
      'is not asked again this sign-in', (tester) async {
    final app = _Harness(tester);
    await tester.runAsync(
      () => app.saves.set(_cafe('a'), CafeStatus.wantToTry),
    );
    await app.pump();
    await app.failedMergeFor('u1');
    // A guest save made after that sign-out moves without asking.
    await tester.runAsync(() => app.saves.set(_cafe('c'), CafeStatus.been));
    await app.settle();

    await app.signIn('u2');
    expect(app.repo.server, {'c': CafeStatus.been});
    expect(find.text(MergeAskSheet.titleFor(1)), findsOneWidget);

    await tester.tap(find.text(MergeAskSheet.notNowLabel));
    await app.settle();

    expect(app.repo.server, {'c': CafeStatus.been});
    expect(app.saves.state.saves.single.cafeId, 'a');
    expect(app.saves.state.saves.single.owner, 'u1');
    expect(analytics.propertiesOf(SavesEvents.guestSavesMergeAnswered), {
      'count': 1,
      'answer': 'not_now',
    });
    await app.clearToasts();

    // The same session again (a relaunch restores it): no second ask.
    app.auth.push(AuthLoading());
    await app.settle();
    app.auth.push(AuthAuthenticated(_user('u2')));
    await app.settle();
    expect(find.byType(MergeAskSheet), findsNothing);

    // After a sign-out the saves are guest saves again, and the next
    // sign-in asks again.
    await app.signOut();
    expect(app.statuses.state.local, {'a': CafeStatus.wantToTry});
    await app.signIn('u2');
    expect(find.byType(MergeAskSheet), findsOneWidget);
    await tester.tap(find.text(MergeAskSheet.notNowLabel));
    await app.settle();
    await app.clearToasts();
  });

  testWidgets('the ask waits for a sheet already open to close', (
    tester,
  ) async {
    final app = _Harness(tester);
    await tester.runAsync(
      () => app.saves.set(_cafe('a'), CafeStatus.wantToTry),
    );
    await app.pump();
    await app.failedMergeFor('u1');

    unawaited(
      showModalBottomSheet<void>(
        context: app.navigator.currentContext!,
        builder: (_) => const SizedBox(height: 200, child: Text('other sheet')),
      ),
    );
    await tester.pumpAndSettle();
    await app.signIn('u2');

    expect(find.text('other sheet'), findsOneWidget);
    expect(find.byType(MergeAskSheet), findsNothing);

    app.navigator.currentState!.pop();
    await app.settle();
    await app.settle();

    expect(find.text('other sheet'), findsNothing);
    expect(find.byType(MergeAskSheet), findsOneWidget);
    await tester.tap(find.text(MergeAskSheet.notNowLabel));
    await app.settle();
    await app.clearToasts();
  });

  testWidgets('a sign-in reported twice asks once, and Add them still '
      'moves the saves', (tester) async {
    final app = _Harness(tester);
    await tester.runAsync(
      () => app.saves.set(_cafe('a'), CafeStatus.wantToTry),
    );
    await app.pump();
    await app.failedMergeFor('u1');
    analytics.events.clear();

    // The auth state put back after an error: AuthAuthenticated again.
    app.signedIn = true;
    app.auth.push(AuthAuthenticated(_user('u2')));
    app.auth.push(const AuthError('x'));
    app.auth.push(AuthAuthenticated(_user('u2')));
    await app.settle();
    await app.settle();

    expect(find.byType(MergeAskSheet), findsOneWidget);
    await tester.tap(find.text(MergeAskSheet.addOneLabel));
    await app.settle();
    await app.settle();

    expect(find.byType(MergeAskSheet), findsNothing);
    expect(
      analytics.names.where((n) => n == SavesEvents.guestSavesMergeAsked),
      hasLength(1),
    );
    expect(app.repo.server, {'a': CafeStatus.wantToTry});
    expect(app.saves.state.isEmpty, isTrue);
    await app.clearToasts();
  });

  testWidgets('the toast counts a save that failed twice once', (tester) async {
    final app = _Harness(tester);
    await tester.runAsync(
      () => app.saves.set(_cafe('a'), CafeStatus.wantToTry),
    );
    await app.pump();
    await app.failedMergeFor('u1');
    await tester.runAsync(() => app.saves.set(_cafe('c'), CafeStatus.been));
    await app.settle();
    app.repo.failWriteFor = {'c'};

    await app.signIn('u2');
    await tester.tap(find.text(MergeAskSheet.addOneLabel));
    await app.settle();

    expect(app.repo.server, {'a': CafeStatus.wantToTry});
    // a moved; c failed in both merges but is one cafe.
    expect(find.text('Moved 1 of 2 cafes to your account'), findsOneWidget);
    await app.clearToasts();
  });

  testWidgets('a sheet that stays open does not hold back the merge toast', (
    tester,
  ) async {
    final app = _Harness(tester);
    await tester.runAsync(
      () => app.saves.set(_cafe('a'), CafeStatus.wantToTry),
    );
    await app.pump();
    await app.failedMergeFor('u1');
    await tester.runAsync(() => app.saves.set(_cafe('c'), CafeStatus.been));
    await app.settle();

    unawaited(
      showModalBottomSheet<void>(
        context: app.navigator.currentContext!,
        builder: (_) => const SizedBox(height: 200, child: Text('other sheet')),
      ),
    );
    await tester.pumpAndSettle();
    await app.signIn('u2');
    expect(find.text('Moved 1 cafe to your account'), findsNothing);

    await tester.pump(mergeAskMaxWait);
    await app.settle();

    expect(find.text('Moved 1 cafe to your account'), findsOneWidget);
    expect(find.byType(MergeAskSheet), findsNothing);
    // Not counted as asked: the next launch asks.
    expect(await tester.runAsync(app.saves.mergeAskedFor), isNull);
    app.navigator.currentState!.pop();
    await app.clearToasts();
  });

  testWidgets('an ask still waiting for an account that signed out does '
      'not hold back the next account\'s', (tester) async {
    final app = _Harness(tester);
    await tester.runAsync(
      () => app.saves.set(_cafe('a'), CafeStatus.wantToTry),
    );
    await app.pump();
    await app.failedMergeFor('u1');

    unawaited(
      showModalBottomSheet<void>(
        context: app.navigator.currentContext!,
        builder: (_) => const SizedBox(height: 200, child: Text('other sheet')),
      ),
    );
    await tester.pumpAndSettle();
    await app.signIn('u2');
    await app.signOut();
    await app.signIn('u3');

    app.navigator.currentState!.pop();
    await app.settle();
    await app.settle();

    expect(find.byType(MergeAskSheet), findsOneWidget);
    await tester.tap(find.text(MergeAskSheet.addOneLabel));
    await app.settle();
    await app.settle();
    expect(find.byType(MergeAskSheet), findsNothing);
    expect(app.repo.server, {'a': CafeStatus.wantToTry});
    await app.clearToasts();
  });

  testWidgets('signing out and back in while the ask waits asks once, '
      'for the new sign-in', (tester) async {
    final app = _Harness(tester);
    await tester.runAsync(
      () => app.saves.set(_cafe('a'), CafeStatus.wantToTry),
    );
    await app.pump();
    await app.failedMergeFor('u1');
    analytics.events.clear();

    unawaited(
      showModalBottomSheet<void>(
        context: app.navigator.currentContext!,
        builder: (_) => const SizedBox(height: 200, child: Text('other sheet')),
      ),
    );
    await tester.pumpAndSettle();
    await app.signIn('u2');
    await app.signOut();
    // Signed out for a moment, a guest save is made.
    await tester.runAsync(() => app.saves.set(_cafe('d'), CafeStatus.been));
    await app.signIn('u2');

    app.navigator.currentState!.pop();
    await app.settle();
    await app.settle();

    expect(find.byType(MergeAskSheet), findsOneWidget);
    await tester.tap(find.text(MergeAskSheet.addOneLabel));
    await app.settle();
    await app.settle();
    expect(
      analytics.names.where((n) => n == SavesEvents.guestSavesMergeAsked),
      hasLength(1),
    );
    expect(app.repo.server, {'a': CafeStatus.wantToTry, 'd': CafeStatus.been});
    // One toast for the sign-in, with both.
    expect(find.text('Moved 2 cafes to your account'), findsOneWidget);
    await app.clearToasts();
  });

  testWidgets('a launch mid sign-up (username step) moves nothing until '
      'the account is finished', (tester) async {
    final repo = _Repo();
    final saves = GuestSavesCubit(store: GuestSavesStore());
    final statuses = CafeStatusCubit(
      getCafeStatusesUseCase: GetCafeStatusesUseCase(repo),
      setCafeStatusUseCase: SetCafeStatusUseCase(repo),
      hasSession: () => true,
    );
    final recent = RecentlyViewedCubit(store: RecentlyViewedStore());
    final auth = FakeAuthBloc(
      AuthNeedsUsername(
        user: User(
          id: 'u',
          appMetadata: const {},
          userMetadata: const {},
          aud: 'authenticated',
          createdAt: '2026-10-16T00:00:00Z',
        ),
      ),
    );
    final lists = FakeListsBloc();
    addTearDown(() async {
      await saves.close();
      await statuses.close();
      await recent.close();
      await auth.close();
      await lists.close();
    });
    await tester.runAsync(
      () => saves.set(
        const CafeSnapshot(id: 'a', name: 'Cafe a'),
        CafeStatus.wantToTry,
      ),
    );

    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider<GuestSavesCubit>.value(value: saves),
          BlocProvider<CafeStatusCubit>.value(value: statuses),
          BlocProvider<RecentlyViewedCubit>.value(value: recent),
          BlocProvider<AuthBloc>.value(value: auth),
          BlocProvider<ListsBloc>.value(value: lists),
        ],
        child: GuestSavesSync(isSignedIn: () => true, child: const SizedBox()),
      ),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump();
    expect(repo.writes, isEmpty);
    expect(saves.state.statusFor('a'), CafeStatus.wantToTry);

    auth.push(
      AuthAuthenticated(
        User(
          id: 'u',
          appMetadata: const {},
          userMetadata: const {},
          aud: 'authenticated',
          createdAt: '2026-10-16T00:00:00Z',
        ),
      ),
    );
    for (var i = 0; i < 5; i++) {
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
    }
    expect(repo.writes, ['a']);
    expect(saves.state.isEmpty, isTrue);
  });
}
