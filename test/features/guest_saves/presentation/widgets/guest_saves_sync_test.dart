import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/core/cafe/domain/entities/cafe_status.dart';
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
import 'package:nook/features/lists/bloc/lists_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;

import '../../../../core/analytics/recording_analytics.dart';
import '../../../auth/fake_auth_bloc.dart';
import '../../../profile/profile_test_support.dart';

class _Repo implements ICafeRepository {
  final Map<String, CafeStatus> server = {};
  final List<String> writes = [];

  @override
  Future<Map<String, CafeStatus>> getCafeStatuses(List<String> ids) async => {
    for (final id in ids)
      if (server[id] != null) id: server[id]!,
  };

  @override
  Future<CafeStatus> setCafeStatus(String id, CafeStatus status) async {
    writes.add(id);
    return server[id] = status;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    RecordingAnalytics.install(addTearDown);
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
