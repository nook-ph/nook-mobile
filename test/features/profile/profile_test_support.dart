import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/core/block/block_cubit.dart';
import 'package:nook/core/cafe/domain/entities/cafe_details.dart';
import 'package:nook/core/cafe/domain/entities/cafe_list.dart';
import 'package:nook/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:nook/features/lists/bloc/lists_bloc.dart';
import 'package:nook/features/lists/bloc/lists_event.dart';
import 'package:nook/features/lists/bloc/lists_state.dart';
import 'package:nook/features/profile/bloc/avatar_upload_bloc.dart';
import 'package:nook/features/profile/bloc/avatar_upload_event.dart';
import 'package:nook/features/profile/bloc/avatar_upload_state.dart';
import 'package:nook/features/profile/presentation/cubit/profile_cubit.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show User, UserIdentity;

import '../auth/auth_test_host.dart';
import '../auth/fake_auth_bloc.dart';

/// Stands in for [ProfileCubit]: holds whatever state the test pushes and
/// records what the page asked of it.
class FakeProfileCubit extends Cubit<ProfileState> implements ProfileCubit {
  FakeProfileCubit(super.initialState);

  int loads = 0;
  int refreshes = 0;
  final List<String> deleted = [];
  final List<({String? name, String? username, String? bio})> edits = [];

  /// Thrown by the next [deleteReview] / [editProfile] when set.
  Object? failure;

  /// Thrown only by an [editProfile] that changes the username.
  Object? usernameFailure;

  void push(ProfileState state) => emit(state);

  @override
  Future<void> loadProfile({bool refresh = false}) async {
    loads++;
    if (refresh) refreshes++;
  }

  @override
  void clear() => emit(const ProfileUnauthenticated());

  @override
  Future<void> deleteReview(String reviewId) async {
    final error = failure;
    if (error != null) throw error;
    deleted.add(reviewId);
    final current = state;
    if (current is! ProfileLoaded) return;
    emit(
      profile(
        reviews: [
          for (final review in current.reviews)
            if (review.id != reviewId) review,
        ],
      ),
    );
  }

  @override
  Future<void> editProfile({
    String? name,
    String? username,
    String? bio,
    String? avatarUrl,
  }) async {
    final error = failure ?? (username == null ? null : usernameFailure);
    if (error != null) throw error;
    edits.add((name: name, username: username, bio: bio));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Stands in for the app-wide [ListsBloc]: records events and lets the test
/// push states.
class FakeListsBloc extends Bloc<ListsEvent, ListsState> implements ListsBloc {
  FakeListsBloc([ListsState? initial]) : super(initial ?? ListsInitial()) {
    on<ListsEvent>((event, _) => events.add(event));
    final first = state;
    if (first is ListsLoaded) userLists = first.lists;
  }

  final List<ListsEvent> events = [];

  @override
  List<CafeList> userLists = const [];

  @override
  Map<String, List<String>> listPreviews = const {};

  void push(ListsState state) {
    if (state is ListsLoaded) userLists = state.lists;
    emit(state);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeAvatarUploadBloc extends Bloc<AvatarUploadEvent, AvatarUploadState>
    implements AvatarUploadBloc {
  FakeAvatarUploadBloc() : super(const AvatarUploadInitial()) {
    on<AvatarUploadEvent>((event, _) => events.add(event));
  }

  final List<AvatarUploadEvent> events = [];

  void push(AvatarUploadState state) => emit(state);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Stands in for [BlockCubit]: records unblocks, or throws [failure].
class FakeBlockCubit extends Cubit<Set<String>> implements BlockCubit {
  FakeBlockCubit() : super(const {});

  final List<String> unblocked = [];
  Object? failure;

  @override
  Future<void> unblock(String userId) async {
    final error = failure;
    if (error != null) throw error;
    unblocked.add(userId);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

WrittenReview review(
  String id, {
  String cafe = 'Tadaima',
  int rating = 5,
  String text = 'Stayed four hours on one latte.',
  DateTime? at,
}) {
  final when = at ?? DateTime(2026, 5, 23);
  return WrittenReview(
    id: id,
    cafeId: 'cafe-$id',
    cafeName: cafe,
    rating: rating,
    content: text,
    createdAt: when,
    updatedAt: when,
  );
}

CafeList cafeList(String id, String name, {int places = 0}) {
  final when = DateTime(2026, 5, 1);
  return CafeList(
    id: id,
    name: name,
    isDefault: false,
    isPublic: false,
    cafeCount: places,
    createdAt: when,
    updatedAt: when,
    listType: 'custom',
  );
}

ProfileLoaded profile({
  String name = 'Sai',
  String username = 'saiimonn_',
  String bio = 'Cebu. Remote most days.',
  List<WrittenReview> reviews = const [],
  DateTime? lastUsernameChange,
  bool reviewsFailed = false,
}) {
  return ProfileLoaded(
    name: name,
    username: username,
    email: 'sai@example.com',
    bio: bio,
    userId: 'user-1',
    lastUsernameChange: lastUsernameChange,
    reviews: reviews,
    reviewsFailed: reviewsFailed,
  );
}

/// A Supabase user who signs in with [provider] ('email', 'google', 'apple').
User userWith(String provider) {
  return User(
    id: 'user-1',
    appMetadata: {'provider': provider},
    userMetadata: const {},
    aud: 'authenticated',
    createdAt: '2026-01-01T00:00:00Z',
    email: 'sai@example.com',
    identities: [
      UserIdentity(
        id: 'identity-1',
        userId: 'user-1',
        identityData: const {},
        identityId: 'identity-1',
        provider: provider,
        createdAt: '2026-01-01T00:00:00Z',
        lastSignInAt: '2026-01-01T00:00:00Z',
      ),
    ],
  );
}

/// Hosts [page] under a router (so `/login` resolves) with the blocs the
/// profile screens read. Blocs left out get an idle fake.
Widget profileHost({
  required Widget page,
  AuthBloc? auth,
  ProfileCubit? cubit,
  ListsBloc? lists,
  AvatarUploadBloc? avatar,
  BlockCubit? block,
}) {
  return authTestHost(
    bloc: auth ?? FakeAuthBloc(),
    page: MultiBlocProvider(
      providers: [
        BlocProvider<ProfileCubit>.value(
          value: cubit ?? FakeProfileCubit(profile()),
        ),
        BlocProvider<ListsBloc>.value(value: lists ?? FakeListsBloc()),
        BlocProvider<AvatarUploadBloc>.value(
          value: avatar ?? FakeAvatarUploadBloc(),
        ),
        BlocProvider<BlockCubit>.value(value: block ?? FakeBlockCubit()),
      ],
      child: page,
    ),
  );
}

/// Lets a toast run out, so its timer is not left pending when the test ends.
Future<void> letToastExpire(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 6));
  await tester.pumpAndSettle();
}
