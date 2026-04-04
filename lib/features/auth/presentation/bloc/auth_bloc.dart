import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nook/features/auth/domain/use_cases/check_email_exists_usecase.dart';
import 'package:nook/features/auth/domain/use_cases/get_current_session_usecase.dart';
import 'package:nook/features/auth/domain/use_cases/sign_in_with_facebook.dart';
import 'package:nook/features/auth/domain/use_cases/sign_in_with_google_usecase.dart';
import 'package:nook/features/auth/domain/use_cases/sign_in_with_email_usecase.dart';
import 'package:nook/features/auth/domain/use_cases/sign_out_usecase.dart';
import 'package:nook/features/auth/domain/use_cases/sign_up_with_email_usecase.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final CheckEmailExistsUseCase _checkEmailExistsUseCase;
  final SignUpWithEmailUseCase _signUpWithEmailUseCase;
  final SignInWithEmailUseCase _signInWithEmailUseCase;
  final SignInWithFacebook _signInWithFacebookUseCase;
  final SignInWithGoogleUseCase _signInWithGoogleUseCase;
  final SignOutUseCase _signOutUseCase;
  final GetCurrentSessionUseCase _getCurrentSessionUseCase;
  StreamSubscription? _facebookAuthStateSubscription;
  static const String _googleWebClientId =
      '190651012817-4l9qejfb0uhpr6jstk1hl2b6ish2gjfo.apps.googleusercontent.com';

  AuthBloc({
    required CheckEmailExistsUseCase checkEmailExistsUseCase,
    required SignUpWithEmailUseCase signUpWithEmailUseCase,
    required SignInWithEmailUseCase signInWithEmailUseCase,
    required SignInWithFacebook signInWithFacebookUseCase,
    required SignInWithGoogleUseCase signInWithGoogleUseCase,
    required SignOutUseCase signOutUseCase,
    required GetCurrentSessionUseCase getCurrentSessionUseCase,
  }) : _checkEmailExistsUseCase = checkEmailExistsUseCase,
       _signUpWithEmailUseCase = signUpWithEmailUseCase,
       _signInWithEmailUseCase = signInWithEmailUseCase,
       _signInWithFacebookUseCase = signInWithFacebookUseCase,
       _signInWithGoogleUseCase = signInWithGoogleUseCase,
       _signOutUseCase = signOutUseCase,
       _getCurrentSessionUseCase = getCurrentSessionUseCase,
       super(AuthInitial()) {
    on<AuthCheckEmailEvent>(_onCheckEmail);
    on<AuthSignUpEvent>(_onSignUp);
    on<AuthSignInEvent>(_onSignIn);
    on<AuthSignInWithFacebookEvent>(_onSignInWithFacebook);
    on<AuthSignInWithGoogleEvent>(_onSignInWithGoogle);
    on<AuthFacebookSessionSettledEvent>(_onFacebookSessionSettled);
    on<AuthSignOutEvent>(_onSignOut);
    on<AuthSessionCheckEvent>(_onSessionCheck);
  }

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

      emit(AuthAuthenticated(user));
    } on AuthException catch (e) {
      emit(AuthError(_mapAuthError(e)));
    } on PostgrestException catch (e) {
      emit(AuthError(_mapDatabaseError(e)));
    } catch (_) {
      emit(const AuthError('Connection failed. Check your internet.'));
    }
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

      emit(AuthAuthenticated(user));
    } on AuthException catch (e) {
      emit(AuthError(_mapAuthError(e)));
    } on PostgrestException catch (e) {
      emit(AuthError(_mapDatabaseError(e)));
    } catch (_) {
      emit(const AuthError('Connection failed. Check your internet.'));
    }
  }

  Future<void> _onSignInWithFacebook(
    AuthSignInWithFacebookEvent event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());

    final result = await _signInWithFacebookUseCase();
    await result.fold((failure) async => emit(AuthError(failure.message)), (
      _,
    ) async {
      final session = _getCurrentSessionUseCase();
      if (session?.user != null) {
        emit(AuthAuthenticated(session!.user));
        return;
      }

      await _facebookAuthStateSubscription?.cancel();
      _facebookAuthStateSubscription = Supabase
          .instance
          .client
          .auth
          .onAuthStateChange
          .listen((data) {
            final authEvent = data.event;
            final session = data.session;

            if (authEvent == AuthChangeEvent.signedIn ||
                authEvent == AuthChangeEvent.tokenRefreshed) {
              final user = session?.user;
              if (user != null) {
                add(AuthFacebookSessionSettledEvent(user));
              }
            }
          });
    });
  }

  Future<void> _onFacebookSessionSettled(
    AuthFacebookSessionSettledEvent event,
    Emitter<AuthState> emit,
  ) async {
    await _facebookAuthStateSubscription?.cancel();
    _facebookAuthStateSubscription = null;
    emit(AuthAuthenticated(event.user));
  }

  Future<void> _onSignInWithGoogle(
    AuthSignInWithGoogleEvent event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());

    final result = await _signInWithGoogleUseCase(_googleWebClientId);
    await result.fold((failure) async => emit(AuthError(failure.message)), (
      _,
    ) async {
      final session = _getCurrentSessionUseCase();
      final user = session?.user;
      if (user != null) {
        emit(AuthAuthenticated(user));
        return;
      }

      emit(const AuthUnauthenticated());
    });
  }

  Future<void> _onSignOut(
    AuthSignOutEvent event,
    Emitter<AuthState> emit,
  ) async {
    try {
      emit(AuthLoading());
      await _facebookAuthStateSubscription?.cancel();
      _facebookAuthStateSubscription = null;
      await _signOutUseCase();
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

  @override
  Future<void> close() async {
    await _facebookAuthStateSubscription?.cancel();
    return super.close();
  }

  Future<void> _onSessionCheck(
    AuthSessionCheckEvent event,
    Emitter<AuthState> emit,
  ) async {
    final session = _getCurrentSessionUseCase();

    if (session?.user != null) {
      emit(AuthAuthenticated(session!.user));
      return;
    }

    emit(AuthUnauthenticated());
  }

  String _mapAuthError(AuthException exception) {
    final code = exception.code?.toLowerCase() ?? '';
    final message = exception.message.toLowerCase();

    if (code == 'invalid_credentials' ||
        code == 'invalid_grant' ||
        message.contains('invalid_credentials') ||
        message.contains('invalid login credentials')) {
      return 'Email or password is incorrect';
    }

    if (code == 'email_not_confirmed' ||
        message.contains('email not confirmed')) {
      return 'Please verify your email before logging in';
    }

    if (code == 'user_already_exists' ||
        message.contains('user_already_exists') ||
        message.contains('already registered') ||
        message.contains('user already registered')) {
      return 'An account with this email already exists';
    }

    if (code == 'weak_password' || message.contains('weak_password')) {
      return 'Password must be at least 8 characters';
    }

    if (code == 'over_request_rate_limit' ||
        message.contains('over_request_rate_limit') ||
        message.contains('rate limit')) {
      return 'Too many attempts. Please wait a moment.';
    }

    if (message.contains('network') ||
        message.contains('connection') ||
        message.contains('socket')) {
      return 'Connection failed. Check your internet.';
    }

    return exception.message.isNotEmpty
        ? exception.message
        : 'Connection failed. Check your internet.';
  }

  String _mapDatabaseError(PostgrestException exception) {
    final code = exception.code?.toLowerCase() ?? '';
    final message = exception.message.toLowerCase();

    if (code == '42501' || message.contains('permission denied')) {
      return 'Email check is blocked by database policy. Please update your Supabase RLS policy for profiles.';
    }

    return exception.message.isNotEmpty
        ? exception.message
        : 'Connection failed. Check your internet.';
  }
}

abstract class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

class AuthCheckEmailEvent extends AuthEvent {
  final String email;

  const AuthCheckEmailEvent(this.email);

  @override
  List<Object?> get props => [email];
}

class AuthSignUpEvent extends AuthEvent {
  final String email;
  final String name;
  final String password;

  const AuthSignUpEvent({
    required this.email,
    required this.name,
    required this.password,
  });

  @override
  List<Object?> get props => [email, name, password];
}

class AuthSignInEvent extends AuthEvent {
  final String email;
  final String password;

  const AuthSignInEvent({required this.email, required this.password});

  @override
  List<Object?> get props => [email, password];
}

class AuthSignInWithFacebookEvent extends AuthEvent {
  const AuthSignInWithFacebookEvent();
}

class AuthSignInWithGoogleEvent extends AuthEvent {
  const AuthSignInWithGoogleEvent();
}

class AuthFacebookSessionSettledEvent extends AuthEvent {
  final User user;

  const AuthFacebookSessionSettledEvent(this.user);

  @override
  List<Object?> get props => [user.id, user.email];
}

class AuthSignOutEvent extends AuthEvent {
  const AuthSignOutEvent();
}

class AuthSessionCheckEvent extends AuthEvent {
  const AuthSessionCheckEvent();
}

abstract class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object?> get props => [];
}

class AuthInitial extends AuthState {
  const AuthInitial();
}

class AuthLoading extends AuthState {
  const AuthLoading();
}

class AuthEmailChecked extends AuthState {
  final bool exists;
  final String email;

  const AuthEmailChecked({required this.exists, required this.email});

  @override
  List<Object?> get props => [exists, email];
}

class AuthAuthenticated extends AuthState {
  final User user;

  const AuthAuthenticated(this.user);

  @override
  List<Object?> get props => [user.id, user.email];
}

class AuthUnauthenticated extends AuthState {
  const AuthUnauthenticated();
}

class AuthLoggedOut extends AuthState {
  const AuthLoggedOut();
}

class AuthError extends AuthState {
  final String message;

  const AuthError(this.message);

  @override
  List<Object?> get props => [message];
}
