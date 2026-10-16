import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/core/cafe/domain/entities/cafe_list.dart';
import 'package:nook/core/cafe/domain/entities/cafe_status.dart';
import 'package:nook/core/cafe/domain/entities/cafe_summary.dart';
import 'package:nook/core/cafe/domain/repositories/i_cafe_repository.dart';
import 'package:nook/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:nook/features/guest_saves/data/guest_saves_store.dart';
import 'package:nook/features/guest_saves/domain/cafe_snapshot.dart';
import 'package:nook/features/guest_saves/presentation/cubit/guest_saves_cubit.dart';
import 'package:nook/features/home_widget/data/home_widget_platform.dart';
import 'package:nook/features/home_widget/presentation/saved_cafes_widget_sync.dart';
import 'package:nook/features/lists/bloc/lists_bloc.dart';
import 'package:nook/features/lists/bloc/lists_event.dart';
import 'package:nook/features/lists/bloc/lists_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../auth/fake_auth_bloc.dart';

class _Platform implements HomeWidgetPlatform {
  final List<Map<String, dynamic>> writes = [];

  Map<String, dynamic>? get last => writes.isEmpty ? null : writes.last;

  @override
  bool get isSupported => true;
  @override
  Future<void> write(String key, String json) async =>
      writes.add(jsonDecode(json) as Map<String, dynamic>);
  @override
  Future<void> redraw() async {}
  @override
  Future<bool> canPin() async => true;
  @override
  Future<void> requestPin() async {}
  @override
  Future<int?> installedCount() async => 1;
  @override
  Future<bool?> notificationsEnabled() async => true;
  @override
  Future<int?> sdkInt() async => 35;
  @override
  Future<Uri?> launchLink() async => null;
  @override
  Stream<Uri?> get clicks => const Stream.empty();
}

class _Repository implements ICafeRepository {
  @override
  Future<List<CafeList>> getUserLists() async => [
    CafeList(
      id: 'wtt',
      name: 'Want to try',
      isDefault: true,
      isPublic: false,
      cafeCount: 1,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
      listType: 'want_to_try',
    ),
  ];

  @override
  Future<List<CafeSummary>> getListCafes(String listId) async => [
    CafeSummary(id: 'acct', name: 'Account cafe', address: '', rating: 0),
  ];

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

class _UnreadableStore extends GuestSavesStore {
  @override
  Future<List<GuestSave>> read() async =>
      throw const GuestSavesReadException('disk');
}

class _FakeListsBloc extends Bloc<ListsEvent, ListsState> implements ListsBloc {
  _FakeListsBloc() : super(ListsInitial());

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late _Platform platform;
  late FakeAuthBloc auth;
  late bool signedIn;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    platform = _Platform();
    auth = FakeAuthBloc();
  });

  Future<void> pump(WidgetTester tester, GuestSavesCubit guest) async {
    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider<GuestSavesCubit>.value(value: guest),
          BlocProvider<ListsBloc>(create: (_) => _FakeListsBloc()),
          BlocProvider<AuthBloc>.value(value: auth),
        ],
        child: SavedCafesWidgetSync(
          platform: platform,
          isSignedIn: () => signedIn,
          repository: _Repository(),
          child: const SizedBox(),
        ),
      ),
    );
    await settle(tester);
  }

  testWidgets('signing out with unreadable guest saves empties the widget '
      'instead of leaving the account\'s cafes', (tester) async {
    signedIn = true;
    await pump(tester, GuestSavesCubit(store: _UnreadableStore()));
    expect((platform.last!['names'] as Map).keys, ['acct']);

    signedIn = false;
    auth.push(const AuthLoggedOut());
    await settle(tester);
    expect(platform.last!['names'], isEmpty);
  });

  testWidgets('the [] cleared on sign-out is not taken for the next '
      'account\'s list', (tester) async {
    signedIn = false;
    final guest = GuestSavesCubit(store: GuestSavesStore());
    await pump(tester, guest);
    await guest.set(
      const CafeSnapshot(id: 'g1', name: 'Guest cafe'),
      CafeStatus.wantToTry,
    );
    await settle(tester);
    expect((platform.last!['names'] as Map).keys, ['g1']);
    final writes = platform.writes.length;

    // A session exists, but the account's list has not been read yet.
    signedIn = true;
    await guest.set(
      const CafeSnapshot(id: 'g2', name: 'Guest cafe 2'),
      CafeStatus.wantToTry,
    );
    await settle(tester);
    expect(platform.writes.length, writes, reason: 'no write of an empty list');
  });
}

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump(const Duration(milliseconds: 500));
  }
}
