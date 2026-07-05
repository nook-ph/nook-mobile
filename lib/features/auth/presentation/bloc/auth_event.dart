part of 'auth_bloc.dart';

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

class AuthPasswordRecoveryEvent extends AuthEvent {
  const AuthPasswordRecoveryEvent();
}

class AuthSignInWithAppleEvent extends AuthEvent {
  const AuthSignInWithAppleEvent();
}

class AuthSignInWithGoogleEvent extends AuthEvent {
  const AuthSignInWithGoogleEvent();
}

class AuthSignOutEvent extends AuthEvent {
  const AuthSignOutEvent();
}

class AuthDeleteAccountEvent extends AuthEvent {
  final String? password;

  const AuthDeleteAccountEvent({this.password});

  @override
  List<Object?> get props => [password];
}

class AuthSessionCheckEvent extends AuthEvent {
  const AuthSessionCheckEvent();
}

class AuthUsernameSetEvent extends AuthEvent {
  final String username;
  const AuthUsernameSetEvent(this.username);

  @override
  List<Object?> get props => [username];
}
