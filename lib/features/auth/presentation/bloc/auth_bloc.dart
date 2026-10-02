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
import 'package:nook/features/auth/domain/use_cases/resend_signup_otp_usecase.dart';
import 'package:nook/features/auth/domain/use_cases/sign_out_usecase.dart';
import 'package:nook/features/auth/domain/use_cases/sign_up_with_email_usecase.dart';
import 'package:nook/features/auth/domain/use_cases/verify_signup_otp_usecase.dart';

// External Blocs
import 'package:nook/features/lists/bloc/lists_bloc.dart';
import 'package:nook/features/lists/bloc/lists_event.dart';

part 'auth_event.dart';
part 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final CheckEmailExistsUseCase _checkEmailExistsUseCase;
  final SignUpWithEmailUseCase _signUpWithEmailUseCase;
  final SignInWithEmailUseCase _signInWithEmailUseCase;
  final VerifySignupOtpUseCase _verifySignupOtpUseCase;
  final ResendSignupOtpUseCase _resendSignupOtpUseCase;
  final SignInWithAppleUsecase _signInWithAppleUsecase;
  final SignInWithGoogleUseCase _signInWithGoogleUseCase;
  final SignOutUseCase _signOutUseCase;
  final DeleteAccountUseCase _deleteAccountUseCase;
  final GetCurrentSessionUseCase _getCurrentSessionUseCase;
  final ListsBloc listsBloc;
  final Future<Map<String, dynamic>> Function(String userId) _fetchProfile;
  late final StreamSubscription<supabase.AuthState> _authStateSubscription;

  /// True while this bloc is itself signing out. gotrue announces `signedOut`
  /// before its request goes out; the handler that asked for it finishes the
  /// job, so the stream listener must not start a second one.
  bool _signingOut = false;

  /// Set when the username gate let a user in without reading their profile.
  /// The next token refresh runs the gate again.
  bool _usernameUnverified = false;

  AuthBloc({
    required CheckEmailExistsUseCase checkEmailExistsUseCase,
    required SignUpWithEmailUseCase signUpWithEmailUseCase,
    required SignInWithEmailUseCase signInWithEmailUseCase,
    required VerifySignupOtpUseCase verifySignupOtpUseCase,
    required ResendSignupOtpUseCase resendSignupOtpUseCase,
    required SignInWithAppleUsecase signInWithAppleUseCase,
    required SignInWithGoogleUseCase signInWithGoogleUseCase,
    required SignOutUseCase signOutUseCase,
    required DeleteAccountUseCase deleteAccountUseCase,
    required GetCurrentSessionUseCase getCurrentSessionUseCase,
    required this.listsBloc,
    Stream<supabase.AuthState>? authStateChanges,
    Future<Map<String, dynamic>> Function(String userId)? fetchProfile,
  }) : _fetchProfile = fetchProfile ?? _fetchSupabaseProfile,
       _checkEmailExistsUseCase = checkEmailExistsUseCase,
       _signUpWithEmailUseCase = signUpWithEmailUseCase,
       _signInWithEmailUseCase = signInWithEmailUseCase,
       _verifySignupOtpUseCase = verifySignupOtpUseCase,
       _resendSignupOtpUseCase = resendSignupOtpUseCase,
       _signInWithAppleUsecase = signInWithAppleUseCase,
       _signInWithGoogleUseCase = signInWithGoogleUseCase,
       _signOutUseCase = signOutUseCase,
       _deleteAccountUseCase = deleteAccountUseCase,
       _getCurrentSessionUseCase = getCurrentSessionUseCase,
       super(AuthInitial()) {
    on<AuthCheckEmailEvent>(_onCheckEmail);
    on<AuthSignUpEvent>(_onSignUp);
    on<AuthSignInEvent>(_onSignIn);
    on<AuthVerifyOtpEvent>(_onVerifyOtp);
    on<AuthResendOtpEvent>(_onResendOtp);
    on<AuthSignInWithAppleEvent>(_onSignInWithApple);
    on<AuthSignInWithGoogleEvent>(_onSignInWithGoogle);
    on<AuthSignOutEvent>(_onSignOut);
    on<AuthDeleteAccountEvent>(_onDeleteAccount);
    on<AuthUsernameSetEvent>(_onUsernameSet);
    on<AuthPasswordRecoveryEvent>(_onPasswordRecovery);
    on<AuthSessionCheckEvent>(_onSessionCheck);
    on<AuthSessionEndedEvent>(_onSessionEnded);

    _authStateSubscription =
        (authStateChanges ?? Supabase.instance.client.auth.onAuthStateChange)
            .listen(_onSupabaseAuthStateChange);
  }

  // ── Handlers ───────────────────────────────────────────────────────────────

  Future<void> _onCheckEmail(
    AuthCheckEmailEvent event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    // Supabase stores addresses lowercased and `check_email_exists` compares
    // exactly, so "Juan@gmail.com" would read as a new account.
    final email = event.email.trim().toLowerCase();
    try {
      final exists = await _checkEmailExistsUseCase(email);
      emit(AuthEmailChecked(exists: exists, email: email));
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

    if (event == AuthChangeEvent.signedOut) {
      if (_signingOut) return;
      debugPrint('AuthBloc: trigger AuthSessionEndedEvent');
      add(const AuthSessionEndedEvent());
      return;
    }

    if (event == AuthChangeEvent.tokenRefreshed) {
      if (_usernameUnverified && state is AuthAuthenticated) {
        debugPrint('AuthBloc: re-run the username gate');
        add(const AuthSessionCheckEvent());
      }
      return;
    }

    if (event == AuthChangeEvent.signedIn) {
      // Supabase reports the sign-in while the handler that asked for it is
      // still running, and that handler runs the post-login gate itself. A
      // second pass here would repeat the profile fetch, the PostHog
      // identify and the lists load, and emit AuthAuthenticated twice. Only
      // sign-ins nobody is handling (a deep link, say) are checked here.
      final current = state;
      final handledElsewhere =
          current is AuthLoading ||
          (current is AuthAwaitingEmailConfirmation && current.isVerifying) ||
          (current is AuthAuthenticated &&
              current.user.id == data.session?.user.id);
      if (handledElsewhere) return;

      debugPrint('AuthBloc: trigger AuthSessionCheckEvent');
      add(const AuthSessionCheckEvent());
    }
  }

  /// The session ended without the user asking: revoked from another device,
  /// or a refresh token the server no longer accepts.
  Future<void> _onSessionEnded(
    AuthSessionEndedEvent event,
    Emitter<AuthState> emit,
  ) async {
    if (_getCurrentSessionUseCase() != null) return;
    final current = state;
    if (current is AuthUnauthenticated ||
        current is AuthLoggedOut ||
        current is AuthAccountDeleted ||
        current is AuthAwaitingEmailConfirmation) {
      return;
    }
    await _resetPosthogUser();
    _clearListsSession();
    emit(const AuthUnauthenticated());
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
      if (_isEmailNotConfirmed(e)) {
        // The account was created but the code never entered (the app was
        // closed on the code screen). Nothing else leads back there, so park
        // the user on it again and send a fresh code.
        emit(AuthAwaitingEmailConfirmation(email: event.email));
        add(const AuthResendOtpEvent());
        return;
      }
      emit(AuthError(_mapAuthError(e)));
    } on PostgrestException catch (e) {
      emit(AuthError(_mapDatabaseError(e)));
    } catch (_) {
      emit(const AuthError('Connection failed. Check your internet.'));
    }
  }

  Future<void> _onVerifyOtp(
    AuthVerifyOtpEvent event,
    Emitter<AuthState> emit,
  ) async {
    final pending = state;
    if (pending is! AuthAwaitingEmailConfirmation) return;
    if (pending.isVerifying) return;

    emit(pending.copyWith(isVerifying: true, clearError: true));
    try {
      final response = await _verifySignupOtpUseCase(
        email: pending.email,
        token: event.token,
      );

      final user = response.user;
      if (user == null) {
        emit(
          pending.copyWith(
            isVerifying: false,
            error: 'Connection failed. Check your internet.',
          ),
        );
        return;
      }

      // verifyOTP establishes the session, so from here this is the same
      // post-login gate as password sign-in.
      await _identifyPosthogUser(user);
      _initListsSession();
      await _emitAuthSuccess(user, emit);
    } on AuthException catch (e) {
      emit(pending.copyWith(isVerifying: false, error: _mapAuthError(e)));
    } on PostgrestException catch (e) {
      emit(pending.copyWith(isVerifying: false, error: _mapDatabaseError(e)));
    } catch (_) {
      emit(
        pending.copyWith(
          isVerifying: false,
          error: 'Connection failed. Check your internet.',
        ),
      );
    }
  }

  Future<void> _onResendOtp(
    AuthResendOtpEvent event,
    Emitter<AuthState> emit,
  ) async {
    final pending = state;
    if (pending is! AuthAwaitingEmailConfirmation) return;
    if (pending.isResending) return;

    emit(pending.copyWith(isResending: true, clearError: true));
    try {
      await _resendSignupOtpUseCase(email: pending.email);
      emit(
        pending.copyWith(
          isResending: false,
          resendCount: pending.resendCount + 1,
          clearError: true,
        ),
      );
    } on AuthException catch (e) {
      emit(pending.copyWith(isResending: false, error: _mapAuthError(e)));
    } catch (_) {
      emit(
        pending.copyWith(
          isResending: false,
          error: 'Unable to resend the code. Try again.',
        ),
      );
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
    final previous = state;
    _signingOut = true;
    try {
      emit(AuthLoading());
      await _signOutUseCase();
    } catch (e) {
      // gotrue drops the local session before its request, so a failed
      // request (offline, server error) still leaves this device signed out.
      // Only a session that survived is a failed log out.
      if (_getCurrentSessionUseCase() != null) {
        _emitErrorKeepingSession(
          emit,
          previous,
          e is AuthException
              ? _mapAuthError(e)
              : 'Connection failed. Check your internet.',
        );
        return;
      }
    } finally {
      _signingOut = false;
    }
    await _resetPosthogUser();
    _clearListsSession();
    emit(const AuthLoggedOut());
    emit(const AuthUnauthenticated());
  }

  Future<void> _onDeleteAccount(
    AuthDeleteAccountEvent event,
    Emitter<AuthState> emit,
  ) async {
    final previous = state;
    try {
      emit(AuthLoading());
      await _deleteAccountUseCase(password: event.password);
      _signingOut = true;
      try {
        await _signOutUseCase();
      } on AuthException catch (e) {
        debugPrint('AuthBloc: post-delete signOut AuthException: ${e.message}');
      } catch (e) {
        debugPrint('AuthBloc: post-delete signOut error: $e');
      } finally {
        _signingOut = false;
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
      _emitErrorKeepingSession(
        emit,
        previous,
        isInvalidPassword ? 'Incorrect password. Please try again.' : mapped,
      );
    } on PostgrestException catch (e) {
      _emitErrorKeepingSession(emit, previous, _mapDatabaseError(e));
    } on FunctionException catch (e) {
      debugPrint('AuthBloc: delete-user function error status=${e.status}');
      _emitErrorKeepingSession(
        emit,
        previous,
        'Account deletion failed. Please try again later.',
      );
    } catch (e) {
      debugPrint('AuthBloc: delete account error: $e');
      _emitErrorKeepingSession(
        emit,
        previous,
        'Account deletion failed. Please try again later.',
      );
    }
  }

  Future<void> _onUsernameSet(
    AuthUsernameSetEvent event,
    Emitter<AuthState> emit,
  ) async {
    final previous = state;
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
        _emitErrorKeepingSession(emit, previous, 'Invalid username format.');
      } else if (msg.contains('already taken')) {
        _emitErrorKeepingSession(
          emit,
          previous,
          'That username is already taken.',
        );
      } else {
        debugPrint('AuthBloc: set_username error: ${e.message}');
        _emitErrorKeepingSession(
          emit,
          previous,
          'Failed to save username. Try again.',
        );
      }
    } catch (_) {
      _emitErrorKeepingSession(
        emit,
        previous,
        'Failed to save username. Try again.',
      );
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
      final profile = await _fetchProfileWithRetry(user.id);
      _usernameUnverified = false;

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
      // Still let the user in: a returning user who opens the app offline
      // has to reach it. The gate runs again on the next token refresh.
      debugPrint('AuthBloc: emit AuthAuthenticated (profile fetch failed)');
      _usernameUnverified = true;
      emit(AuthAuthenticated(user));
    }
  }

  static const _profileFetchAttempts = 3;

  /// A dropped request must not decide whether the username step is skipped,
  /// so the profile read gets a couple of quick retries first.
  Future<Map<String, dynamic>> _fetchProfileWithRetry(String userId) async {
    for (var attempt = 1; ; attempt++) {
      try {
        return await _fetchProfile(userId);
      } catch (_) {
        if (attempt >= _profileFetchAttempts) rethrow;
        await Future<void>.delayed(Duration(milliseconds: 300 * attempt));
      }
    }
  }

  static Future<Map<String, dynamic>> _fetchSupabaseProfile(String userId) {
    return Supabase.instance.client
        .from('profiles')
        .select('username, full_name, avatar_url')
        .eq('id', userId)
        .single();
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  /// Reports a failed action without losing the signed-in (or username-setup)
  /// state it interrupted: the error is emitted for listeners, then the state
  /// the router and the rest of the app key off is put back.
  void _emitErrorKeepingSession(
    Emitter<AuthState> emit,
    AuthState previous,
    String message,
  ) {
    emit(AuthError(message));
    if (previous is AuthAuthenticated || previous is AuthNeedsUsername) {
      emit(previous);
    }
  }

  bool _isEmailNotConfirmed(AuthException exception) {
    return exception.code?.toLowerCase() == 'email_not_confirmed' ||
        exception.message.toLowerCase().contains('email not confirmed');
  }

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

      // Set-once, from Supabase rather than PostHog's own first-seen date:
      // the activation metric (STICKY_FEATURES.md Phase 0 — "% of new users
      // who rank >= 1 cafe on day 1") needs the real account age. PostHog's
      // person created_at is when the device was first seen, which for a
      // reinstall or a second device is not the same day at all.
      final signupDate = user.createdAt.trim();

      await Posthog().identify(
        userId: user.id,
        userProperties: userProperties.isEmpty ? null : userProperties,
        userPropertiesSetOnce: signupDate.isEmpty
            ? null
            : {'signup_date': signupDate},
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
    // Supabase returns one error for a wrong code and an expired one, so the
    // copy has to cover both rather than guess which it was.
    if (code == 'otp_expired' ||
        code == 'otp_disabled' ||
        message.contains('token has expired') ||
        message.contains('invalid token') ||
        message.contains('token not found')) {
      return 'That code is incorrect or has expired.';
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
    // AuthRetryableFetchException is what gotrue throws when the request never
    // got an answer; its message is the raw socket error.
    if (exception is AuthRetryableFetchException ||
        message.contains('network') ||
        message.contains('connection') ||
        message.contains('socketexception') ||
        message.contains('failed host lookup')) {
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
