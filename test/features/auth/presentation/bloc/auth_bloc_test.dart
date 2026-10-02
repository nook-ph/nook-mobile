import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/core/cafe/domain/entities/cafe_list.dart';
import 'package:nook/features/auth/domain/repository/auth_repository.dart';
import 'package:nook/features/auth/domain/use_cases/check_email_exists_usecase.dart';
import 'package:nook/features/auth/domain/use_cases/delete_account_usecase.dart';
import 'package:nook/features/auth/domain/use_cases/get_current_session_usecase.dart';
import 'package:nook/features/auth/domain/use_cases/resend_signup_otp_usecase.dart';
import 'package:nook/features/auth/domain/use_cases/sign_in_with_apple_usecase.dart';
import 'package:nook/features/auth/domain/use_cases/sign_in_with_email_usecase.dart';
import 'package:nook/features/auth/domain/use_cases/sign_in_with_google_usecase.dart';
import 'package:nook/features/auth/domain/use_cases/sign_out_usecase.dart';
import 'package:nook/features/auth/domain/use_cases/sign_up_with_email_usecase.dart';
import 'package:nook/features/auth/domain/use_cases/verify_signup_otp_usecase.dart';
import 'package:nook/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:nook/features/lists/bloc/lists_bloc.dart';
import 'package:nook/features/lists/bloc/lists_event.dart';
import 'package:nook/features/lists/bloc/lists_state.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

const _user = User(
  id: 'user-1',
  appMetadata: {},
  userMetadata: {},
  aud: 'authenticated',
  email: 'maria.cruz@gmail.com',
  createdAt: '2026-09-01T00:00:00Z',
);

final _session = Session(
  accessToken: 'token',
  tokenType: 'bearer',
  user: _user,
);

class _FakeAuthRepository implements AuthRepository {
  Session? session;

  /// Thrown by [signOut] after the local session is dropped, the way gotrue
  /// fails when the request cannot be sent.
  Object? signOutError;

  /// When false a failed [signOut] leaves the session in place.
  bool signOutDropsSession = true;

  Object? signInError;
  Object? deleteError;
  final List<String> checkedEmails = [];
  final List<String> resentTo = [];
  int signOuts = 0;

  /// Runs in the middle of [signOut], after the session is gone.
  void Function()? duringSignOut;

  @override
  Future<bool> emailExists(String email) async {
    checkedEmails.add(email);
    return true;
  }

  @override
  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    final error = signInError;
    if (error != null) throw error;
    session = _session;
    return AuthResponse(session: _session, user: _user);
  }

  @override
  Future<void> resendSignupOtp({required String email}) async {
    resentTo.add(email);
  }

  @override
  Future<void> signOut() async {
    signOuts++;
    if (signOutDropsSession) session = null;
    duringSignOut?.call();
    await Future<void>.delayed(Duration.zero);
    final error = signOutError;
    if (error != null) throw error;
  }

  @override
  Future<void> deleteAccount({String? password}) async {
    final error = deleteError;
    if (error != null) throw error;
  }

  @override
  Session? getCurrentSession() => session;

  @override
  Future<Either<Failure, void>> signInWithApple() async => const Right(null);

  @override
  Future<Either<Failure, void>> signInWithGoogle() async => const Right(null);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeListsBloc extends Bloc<ListsEvent, ListsState> implements ListsBloc {
  _FakeListsBloc() : super(ListsInitial()) {
    on<ListsEvent>((event, _) => events.add(event));
  }

  final List<ListsEvent> events = [];

  @override
  String? defaultListId = 'default-list';

  @override
  List<CafeList> userLists = const [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late _FakeAuthRepository repository;
  late _FakeListsBloc listsBloc;
  late StreamController<supabase.AuthState> authEvents;
  late Future<Map<String, dynamic>> Function(String userId) fetchProfile;
  late AuthBloc bloc;
  late List<AuthState> states;

  AuthBloc build() {
    final created = AuthBloc(
      checkEmailExistsUseCase: CheckEmailExistsUseCase(repository),
      signUpWithEmailUseCase: SignUpWithEmailUseCase(repository),
      signInWithEmailUseCase: SignInWithEmailUseCase(repository),
      verifySignupOtpUseCase: VerifySignupOtpUseCase(repository),
      resendSignupOtpUseCase: ResendSignupOtpUseCase(repository),
      signInWithAppleUseCase: SignInWithAppleUsecase(repository),
      signInWithGoogleUseCase: SignInWithGoogleUseCase(repository),
      signOutUseCase: SignOutUseCase(repository),
      deleteAccountUseCase: DeleteAccountUseCase(repository),
      getCurrentSessionUseCase: GetCurrentSessionUseCase(repository),
      listsBloc: listsBloc,
      authStateChanges: authEvents.stream,
      fetchProfile: (userId) => fetchProfile(userId),
    );
    created.stream.listen(states.add);
    return created;
  }

  /// Lets queued events and their awaits run.
  Future<void> settle([Duration wait = const Duration(milliseconds: 20)]) =>
      Future<void>.delayed(wait);

  /// Puts the bloc in [AuthAuthenticated] the way a cold start does.
  Future<void> signIn() async {
    repository.session = _session;
    bloc.add(const AuthSessionCheckEvent());
    await settle();
    expect(bloc.state, isA<AuthAuthenticated>());
    states.clear();
  }

  setUp(() {
    repository = _FakeAuthRepository();
    listsBloc = _FakeListsBloc();
    authEvents = StreamController<supabase.AuthState>.broadcast();
    fetchProfile = (_) async => {'username': 'maria', 'full_name': 'Maria'};
    states = [];
    bloc = build();
  });

  tearDown(() async {
    await bloc.close();
    await listsBloc.close();
    await authEvents.close();
  });

  group('sign out', () {
    test('a request that fails after the session is gone still logs out '
        '(A-1)', () async {
      await signIn();
      repository.signOutError = AuthRetryableFetchException(
        message: 'ClientException with SocketException: Failed host lookup',
      );

      bloc.add(const AuthSignOutEvent());
      await settle();

      expect(states, [
        isA<AuthLoading>(),
        const AuthLoggedOut(),
        const AuthUnauthenticated(),
      ]);
      expect(listsBloc.defaultListId, isNull);
    });

    test(
      'a failure that leaves the session keeps the user signed in',
      () async {
        await signIn();
        repository
          ..signOutDropsSession = false
          ..signOutError = const AuthException('boom');

        bloc.add(const AuthSignOutEvent());
        await settle();

        expect(states, [
          isA<AuthLoading>(),
          const AuthError('boom'),
          isA<AuthAuthenticated>(),
        ]);
        expect(listsBloc.defaultListId, 'default-list');
      },
    );

    test('its own signedOut event does not start a second clean-up', () async {
      await signIn();
      repository.duringSignOut = () => authEvents.add(
        const supabase.AuthState(AuthChangeEvent.signedOut, null),
      );

      bloc.add(const AuthSignOutEvent());
      await settle();

      expect(states, [
        isA<AuthLoading>(),
        const AuthLoggedOut(),
        const AuthUnauthenticated(),
      ]);
    });
  });

  group('signedOut from Supabase (A-2)', () {
    test('ends the session in the app', () async {
      await signIn();
      repository.session = null;

      authEvents.add(const supabase.AuthState(AuthChangeEvent.signedOut, null));
      await settle();

      expect(states, [const AuthUnauthenticated()]);
      expect(listsBloc.defaultListId, isNull);
    });

    test('is ignored while a session still exists', () async {
      await signIn();

      authEvents.add(const supabase.AuthState(AuthChangeEvent.signedOut, null));
      await settle();

      expect(states, isEmpty);
    });
  });

  test('an unconfirmed account goes back to the code screen with a fresh '
      'code (A-3)', () async {
    repository.signInError = const AuthException(
      'Email not confirmed',
      code: 'email_not_confirmed',
    );

    bloc.add(
      const AuthSignInEvent(email: 'maria.cruz@gmail.com', password: 'pw'),
    );
    await settle();

    expect(repository.resentTo, ['maria.cruz@gmail.com']);
    final state = bloc.state;
    expect(state, isA<AuthAwaitingEmailConfirmation>());
    state as AuthAwaitingEmailConfirmation;
    expect(state.email, 'maria.cruz@gmail.com');
    expect(state.resendCount, 1);
    expect(states.whereType<AuthError>(), isEmpty);
  });

  test('the email is checked lowercased (A-4)', () async {
    bloc.add(const AuthCheckEmailEvent(' Juan@Gmail.com '));
    await settle();

    expect(repository.checkedEmails, ['juan@gmail.com']);
    expect(
      bloc.state,
      const AuthEmailChecked(exists: true, email: 'juan@gmail.com'),
    );
  });

  test('a failed delete leaves the user signed in (A-7)', () async {
    await signIn();
    repository.deleteError = const AuthException(
      'Invalid login credentials',
      code: 'invalid_credentials',
    );

    bloc.add(const AuthDeleteAccountEvent(password: 'wrong'));
    await settle();

    expect(states, [
      isA<AuthLoading>(),
      const AuthError('Incorrect password. Please try again.'),
      isA<AuthAuthenticated>(),
    ]);
    expect(repository.signOuts, 0);
  });

  group('username gate (A-8)', () {
    test('a dropped profile read is retried before deciding', () async {
      var calls = 0;
      fetchProfile = (_) async {
        if (++calls < 3) throw Exception('offline');
        return {'username': null, 'full_name': 'Maria'};
      };
      repository.session = _session;

      bloc.add(const AuthSessionCheckEvent());
      await settle(const Duration(milliseconds: 1200));

      expect(calls, 3);
      expect(bloc.state, isA<AuthNeedsUsername>());
      expect(states.whereType<AuthAuthenticated>(), isEmpty);
    });

    test('a user let in unverified is re-checked on token refresh', () async {
      var online = false;
      fetchProfile = (_) async {
        if (!online) throw Exception('offline');
        return {'username': null, 'full_name': 'Maria'};
      };
      repository.session = _session;

      bloc.add(const AuthSessionCheckEvent());
      await settle(const Duration(milliseconds: 1200));
      expect(bloc.state, isA<AuthAuthenticated>());

      online = true;
      authEvents.add(
        supabase.AuthState(AuthChangeEvent.tokenRefreshed, _session),
      );
      await settle();
      expect(bloc.state, isA<AuthNeedsUsername>());
    });

    test('a verified user is not re-checked on token refresh', () async {
      var calls = 0;
      fetchProfile = (_) async {
        calls++;
        return {'username': 'maria'};
      };
      await signIn();

      authEvents.add(
        supabase.AuthState(AuthChangeEvent.tokenRefreshed, _session),
      );
      await settle();
      expect(calls, 1);
    });
  });

  test('a failed username save keeps the username step (A-11)', () async {
    fetchProfile = (_) async => {'username': null, 'full_name': 'Maria'};
    repository.session = _session;
    bloc.add(const AuthSessionCheckEvent());
    await settle();
    expect(bloc.state, isA<AuthNeedsUsername>());
    states.clear();

    // Supabase is not initialised under test, so the save itself throws.
    bloc.add(const AuthUsernameSetEvent('maria'));
    await settle();

    expect(states, [
      isA<AuthLoading>(),
      const AuthError('Failed to save username. Try again.'),
      isA<AuthNeedsUsername>(),
    ]);
  });

  test('an unanswered request is not shown as a raw socket error '
      '(A-13)', () async {
    repository.signInError = AuthRetryableFetchException(
      message: "ClientException with SocketException: Failed host lookup: 'x'",
    );

    bloc.add(const AuthSignInEvent(email: 'a@b.co', password: 'pw'));
    await settle();

    expect(
      bloc.state,
      const AuthError('Connection failed. Check your internet.'),
    );
  });
}
