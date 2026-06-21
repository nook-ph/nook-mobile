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

class AuthAwaitingEmailConfirmation extends AuthState {
  final String email;

  const AuthAwaitingEmailConfirmation({required this.email});

  @override
  List<Object?> get props => [email];
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
