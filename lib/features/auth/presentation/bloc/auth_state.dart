part of 'auth_bloc.dart';

abstract class AuthState extends Equatable {
  const AuthState();
  @override
  List<Object?> get props => [];
}

class AuthInitial extends AuthState {}

class AuthLoading extends AuthState {}

class AuthEmailChecked extends AuthState {
  final bool exists;
  final String email;
  const AuthEmailChecked({required this.exists, required this.email});

  @override
  List<Object?> get props => [exists, email];
}

class AuthPasswordRecovery extends AuthState {}

class AuthNeedsUsername extends AuthState {
  final User user;
  final String? fullName, avatarUrl;
  const AuthNeedsUsername({required this.user, this.fullName, this.avatarUrl});

  @override
  List<Object?> get props => [user.id, fullName, avatarUrl];
}

/// The account exists but is unconfirmed. The user is parked on
/// `/email-confirmation` entering the code from the signup email.
///
/// Verifying and resending stay *inside* this state rather than emitting
/// AuthLoading/AuthError, for two reasons: the router keys its redirect off the
/// state subclass (a transient AuthLoading would drop the redirect), and the
/// screen reads [email] from here — a state change that lost it would blank the
/// page mid-flow.
class AuthAwaitingEmailConfirmation extends AuthState {
  final String email;
  final bool isVerifying;
  final bool isResending;
  final String? error;

  /// Bumped on every successful resend. Two resends otherwise produce equal
  /// states, and Equatable would swallow the second — leaving the screen unable
  /// to restart its cooldown.
  final int resendCount;

  const AuthAwaitingEmailConfirmation({
    required this.email,
    this.isVerifying = false,
    this.isResending = false,
    this.error,
    this.resendCount = 0,
  });

  AuthAwaitingEmailConfirmation copyWith({
    bool? isVerifying,
    bool? isResending,
    String? error,
    bool clearError = false,
    int? resendCount,
  }) {
    return AuthAwaitingEmailConfirmation(
      email: email,
      isVerifying: isVerifying ?? this.isVerifying,
      isResending: isResending ?? this.isResending,
      error: clearError ? null : (error ?? this.error),
      resendCount: resendCount ?? this.resendCount,
    );
  }

  @override
  List<Object?> get props => [
    email,
    isVerifying,
    isResending,
    error,
    resendCount,
  ];
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

class AuthAccountDeleted extends AuthState {
  const AuthAccountDeleted();
}

class AuthError extends AuthState {
  final String message;
  const AuthError(this.message);

  @override
  List<Object?> get props => [message];
}
