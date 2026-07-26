import 'dart:async';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:posthog_flutter/posthog_flutter.dart';
import 'package:nook/core/analytics/analytics_config.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

// Use Cases
import 'package:nook/features/auth/domain/use_cases/check_email_exists_usecase.dart';
import 'package:nook/features/auth/domain/use_cases/delete_account_usecase.dart';
import 'package:nook/features/auth/domain/use_cases/get_current_session_usecase.dart';
import 'package:nook/features/auth/domain/use_cases/sign_in_with_apple_usecase.dart';
import 'package:nook/features/auth/domain/use_cases/sign_in_with_google_usecase.dart';
import 'package:nook/features/auth/domain/use_cases/sign_in_with_email_usecase.dart';
import 'package:nook/features/auth/domain/use_cases/sign_out_usecase.dart';
import 'package:nook/features/auth/domain/use_cases/sign_up_with_email_usecase.dart';

// External Blocs
import 'package:nook/features/lists/bloc/lists_bloc.dart';
import 'package:nook/features/lists/bloc/lists_event.dart';

part 'auth_event.dart';
part 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final CheckEmailExistsUseCase _checkEmailExistsUseCase;
  final SignUpWithEmailUseCase _signUpWithEmailUseCase;
  final SignInWithEmailUseCase _signInWithEmailUseCase;
  final SignInWithAppleUsecase _signInWithAppleUsecase;
  final SignInWithGoogleUseCase _signInWithGoogleUseCase;
  final SignOutUseCase _signOutUseCase;
  final DeleteAccountUseCase _deleteAccountUseCase;
  final GetCurrentSessionUseCase _getCurrentSessionUseCase;
  final ListsBloc listsBloc;
  late final StreamSubscription<supabase.AuthState> _authStateSubscription;

  AuthBloc({
    required CheckEmailExistsUseCase checkEmailExistsUseCase,
    required SignUpWithEmailUseCase signUpWithEmailUseCase,
    required SignInWithEmailUseCase signInWithEmailUseCase,
    required SignInWithAppleUsecase signInWithAppleUseCase,
    required SignInWithGoogleUseCase signInWithGoogleUseCase,
    required SignOutUseCase signOutUseCase,
    required DeleteAccountUseCase deleteAccountUseCase,
    required GetCurrentSessionUseCase getCurrentSessionUseCase,
    required this.listsBloc,
  }) : _checkEmailExistsUseCase = checkEmailExistsUseCase,
       _signUpWithEmailUseCase = signUpWithEmailUseCase,
       _signInWithEmailUseCase = signInWithEmailUseCase,
       _signInWithAppleUsecase = signInWithAppleUseCase,
       _signInWithGoogleUseCase = signInWithGoogleUseCase,
       _signOutUseCase = signOutUseCase,
       _deleteAccountUseCase = deleteAccountUseCase,
       _getCurrentSessionUseCase = getCurrentSessionUseCase,
       super(AuthInitial()) {
    on<AuthCheckEmailEvent>(_onCheckEmail);
    on<AuthSignUpEvent>(_onSignUp);
    on<AuthSignInEvent>(_onSignIn);
    on<AuthSignInWithAppleEvent>(_onSignInWithApple);
    on<AuthSignInWithGoogleEvent>(_onSignInWithGoogle);
    on<AuthSignOutEvent>(_onSignOut);
    on<AuthDeleteAccountEvent>(_onDeleteAccount);
    on<AuthUsernameSetEvent>(_onUsernameSet);
    on<AuthPasswordRecoveryEvent>(_onPasswordRecovery);
    on<AuthSessionCheckEvent>(_onSessionCheck);

    _authStateSubscription = Supabase.instance.client.auth.onAuthStateChange
        .listen(_onSupabaseAuthStateChange);
  }

  // ── Handlers ───────────────────────────────────────────────────────────────

  Future<void> _onCheckEmail(
    AuthCheckEmailEvent event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      final exists = await _checkEmailExistsUseCase(event.email);
      emit(AuthEmailChecked(exists: exists, email: event.email));
    } on AuthException catch (e) {
      emit(AuthError(_mapAuthError(e)));
    } on PostgrestException catch (e) {
      emit(AuthError(_mapDatabaseError(e)));
    } catch (_) {
      emit(const AuthError('Connection failed. Check your internet.'));
    }
  }

  void _onSupabaseAuthStateChange(supabase.AuthState data) {
    final event = data.event;
    debugPrint('AuthBloc: supabase auth event=$event');

    if (event == AuthChangeEvent.passwordRecovery) {
      debugPrint('AuthBloc: trigger AuthPasswordRecoveryEvent');
      add(const AuthPasswordRecoveryEvent());
      return;
    }

    if (event == AuthChangeEvent.userUpdated) {
      if (state is AuthPasswordRecovery) {
        debugPrint('AuthBloc: password updated, re-check session');
        add(const AuthSessionCheckEvent());
      }
      return;
    }

    if (event == AuthChangeEvent.signedIn) {
      debugPrint('AuthBloc: trigger AuthSessionCheckEvent');
      add(const AuthSessionCheckEvent());
    }
  }

  Future<void> _onPasswordRecovery(
    AuthPasswordRecoveryEvent event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthPasswordRecovery());
  }

  Future<void> _onSignUp(AuthSignUpEvent event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      final response = await _signUpWithEmailUseCase(
        email: event.email,
        name: event.name,
        password: event.password,
      );

      final user = response.user;
      if (user == null) {
        emit(const AuthError('Connection failed. Check your internet.'));
        return;
      }

      if (response.session == null) {
        emit(AuthAwaitingEmailConfirmation(email: event.email));
        return;
      }

      await _identifyPosthogUser(user);
      _initListsSession();
      await _emitAuthSuccess(user, emit);
    } on AuthException catch (e) {
      emit(AuthError(_mapAuthError(e)));
    } on PostgrestException catch (e) {
      emit(AuthError(_mapDatabaseError(e)));
    } catch (_) {
      emit(const AuthError('Connection failed. Check your internet.'));
    }
  }

  @override
  Future<void> close() async {
    await _authStateSubscription.cancel();
    return super.close();
  }

  Future<void> _onSignIn(AuthSignInEvent event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      final response = await _signInWithEmailUseCase(
        email: event.email,
        password: event.password,
      );

      final user = response.user;
      if (user == null) {
        emit(const AuthError('Connection failed. Check your internet.'));
        return;
      }

      await _identifyPosthogUser(user);
      _initListsSession();
      await _emitAuthSuccess(user, emit);
    } on AuthException catch (e) {
      emit(AuthError(_mapAuthError(e)));
    } on PostgrestException catch (e) {
      emit(AuthError(_mapDatabaseError(e)));
    } catch (_) {
      emit(const AuthError('Connection failed. Check your internet.'));
    }
  }

  Future<void> _onSignInWithApple(
    AuthSignInWithAppleEvent event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    final result = await _signInWithAppleUsecase();
    await result.fold(
      (failure) async {
        if (failure.message == 'CANCELED') {
          emit(const AuthUnauthenticated());
          return;
        }
        emit(AuthError(failure.message));
      },
      (_) async {
        final user = _getCurrentSessionUseCase()?.user;
        if (user != null) {
          await _identifyPosthogUser(user);
          _initListsSession();
          await _emitAuthSuccess(user, emit);
          return;
        }
        emit(const AuthUnauthenticated());
      },
    );
  }

  Future<void> _onSignInWithGoogle(
    AuthSignInWithGoogleEvent event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    final result = await _signInWithGoogleUseCase();
    await result.fold(
      (failure) async {
        if (failure.message == 'CANCELED') {
          emit(const AuthUnauthenticated());
          return;
        }
        emit(AuthError(failure.message));
      },
      (_) async {
        final user = _getCurrentSessionUseCase()?.user;
        if (user != null) {
          await _identifyPosthogUser(user);
          _initListsSession();
          await _emitAuthSuccess(user, emit);
          return;
        }
        emit(const AuthUnauthenticated());
      },
    );
  }

  Future<void> _onSignOut(
    AuthSignOutEvent event,
    Emitter<AuthState> emit,
  ) async {
    try {
      emit(AuthLoading());
      await _signOutUseCase();
      await _resetPosthogUser();
      _clearListsSession();
      emit(const AuthLoggedOut());
      emit(const AuthUnauthenticated());
    } on AuthException catch (e) {
      emit(AuthError(_mapAuthError(e)));
    } on PostgrestException catch (e) {
      emit(AuthError(_mapDatabaseError(e)));
    } catch (_) {
      emit(const AuthError('Connection failed. Check your internet.'));
    }
  }

  Future<void> _onDeleteAccount(
    AuthDeleteAccountEvent event,
    Emitter<AuthState> emit,
  ) async {
    try {
      emit(AuthLoading());
      await _deleteAccountUseCase(password: event.password);
      try {
        await _signOutUseCase();
      } on AuthException catch (e) {
        debugPrint('AuthBloc: post-delete signOut AuthException: ${e.message}');
      } catch (e) {
        debugPrint('AuthBloc: post-delete signOut error: $e');
      }
      await _resetPosthogUser();
      _clearListsSession();
      emit(const AuthAccountDeleted());
      emit(const AuthUnauthenticated());
    } on AuthException catch (e) {
      final mapped = _mapAuthError(e);
      final isInvalidPassword =
          e.code == 'invalid_credentials' ||
          e.code == 'invalid_grant' ||
          e.message.toLowerCase().contains('invalid login credentials') ||
          e.message.toLowerCase().contains('invalid password');
      emit(
        AuthError(
          isInvalidPassword ? 'Incorrect password. Please try again.' : mapped,
        ),
      );
    } on PostgrestException catch (e) {
      emit(AuthError(_mapDatabaseError(e)));
    } on FunctionException catch (e) {
      debugPrint('AuthBloc: delete-user function error status=${e.status}');
      emit(const AuthError('Account deletion failed. Please try again later.'));
    } catch (e) {
      debugPrint('AuthBloc: delete account error: $e');
      emit(const AuthError('Account deletion failed. Please try again later.'));
    }
  }

  Future<void> _onUsernameSet(
    AuthUsernameSetEvent event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        emit(const AuthUnauthenticated());
        return;
      }

      await Supabase.instance.client.rpc(
        'set_username',
        params: {'p_username': event.username},
      );

      emit(AuthAuthenticated(user));
    } on PostgrestException catch (e) {
      final msg = e.message.toLowerCase();
      if (msg.contains('invalid username format')) {
        emit(const AuthError('Invalid username format.'));
      } else if (msg.contains('already taken')) {
        emit(const AuthError('That username is already taken.'));
      } else {
        emit(AuthError(_mapDatabaseError(e)));
      }
    } catch (_) {
      emit(const AuthError('Failed to save username. Try again.'));
    }
  }

  Future<void> _onSessionCheck(
    AuthSessionCheckEvent event,
    Emitter<AuthState> emit,
  ) async {
    final user = _getCurrentSessionUseCase()?.user;
    debugPrint('AuthBloc: session check user=${user?.id} email=${user?.email}');
    if (user != null) {
      await _identifyPosthogUser(user);
      _initListsSession();
      await _emitAuthSuccess(user, emit);
      return;
    }
    emit(const AuthUnauthenticated());
  }

  // ── Shared Success Gate ───────────────────────────────────────────────────

  Future<void> _emitAuthSuccess(User user, Emitter<AuthState> emit) async {
    try {
      final profile = await Supabase.instance.client
          .from('profiles')
          .select('username, full_name, avatar_url')
          .eq('id', user.id)
          .single();

      final username = profile['username'] as String?;

      if (username == null || username.trim().isEmpty) {
        debugPrint('AuthBloc: emit AuthNeedsUsername');
        emit(
          AuthNeedsUsername(
            user: user,
            fullName: profile['full_name'] as String?,
            avatarUrl: profile['avatar_url'] as String?,
          ),
        );
      } else {
        debugPrint('AuthBloc: emit AuthAuthenticated');
        emit(AuthAuthenticated(user));
      }
    } catch (_) {
      debugPrint('AuthBloc: emit AuthAuthenticated (profile fetch failed)');
      emit(AuthAuthenticated(user));
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  void _initListsSession() => listsBloc.add(LoadUserLists());

  void _clearListsSession() {
    listsBloc.defaultListId = null;
    listsBloc.userLists = const [];
  }

  Future<void> _identifyPosthogUser(User user) async {
    // identify() creates the person record, so this has to be gated too —
    // otherwise dev sign-ins mint PostHog persons for real user accounts.
    if (!kAnalyticsEnabled) return;

    try {
      final email = user.email?.trim();
      final metadata = user.userMetadata;
      final rawName = metadata?['name'] ?? metadata?['full_name'];
      final name = rawName is String ? rawName.trim() : null;

      final userProperties = <String, Object>{
        if (email != null && email.isNotEmpty) 'email': email,
        if (name != null && name.isNotEmpty) 'name': name,
      };

      await Posthog().identify(
        userId: user.id,
        userProperties: userProperties.isEmpty ? null : userProperties,
      );
    } catch (_) {}
  }

  Future<void> _resetPosthogUser() async {
    if (!kAnalyticsEnabled) return;

    try {
      await Posthog().reset();
    } catch (_) {}
  }

  String _mapAuthError(AuthException exception) {
    final code = exception.code?.toLowerCase() ?? '';
    final message = exception.message.toLowerCase();

    if (code == 'invalid_credentials' ||
        code == 'invalid_grant' ||
        message.contains('invalid login credentials')) {
      return 'Email or password is incorrect';
    }
    if (code == 'email_not_confirmed' ||
        message.contains('email not confirmed')) {
      return 'Please verify your email before logging in';
    }
    if (code == 'user_already_exists' ||
        message.contains('already registered')) {
      return 'An account with this email already exists';
    }
    if (code == 'weak_password') {
      return 'Password must be at least 8 characters';
    }
    if (code == 'over_request_rate_limit' || message.contains('rate limit')) {
      return 'Too many attempts. Please wait a moment.';
    }
    if (message.contains('network') || message.contains('connection')) {
      return 'Connection failed. Check your internet.';
    }
    return exception.message.isNotEmpty
        ? exception.message
        : 'Connection failed.';
  }

  String _mapDatabaseError(PostgrestException exception) {
    final code = exception.code?.toLowerCase() ?? '';
    final message = exception.message.toLowerCase();

    if (code == '42501' || message.contains('permission denied')) {
      return 'Email check is blocked by database policy.';
    }
    return exception.message.isNotEmpty
        ? exception.message
        : 'Connection failed.';
  }
}
