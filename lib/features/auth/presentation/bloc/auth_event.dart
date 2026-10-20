part of 'auth_bloc.dart';

abstract class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

class AuthCheckEmailEvent extends AuthEvent {
  final String email;

  /// Where the attempt started, for the sign-in funnel ([AuthSurface]).
  final String surface;

  const AuthCheckEmailEvent(this.email, {this.surface = AuthSurface.login});

  @override
  List<Object?> get props => [email, surface];
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

/// Confirms the pending signup with the code from the email. The email comes
/// from [AuthAwaitingEmailConfirmation], never from the caller — the code is
/// only valid for the address it was sent to.
class AuthVerifyOtpEvent extends AuthEvent {
  final String token;
  const AuthVerifyOtpEvent(this.token);

  @override
  List<Object?> get props => [token];
}

class AuthResendOtpEvent extends AuthEvent {
  const AuthResendOtpEvent();
}

class AuthPasswordRecoveryEvent extends AuthEvent {
  const AuthPasswordRecoveryEvent();
}

class AuthSignInWithAppleEvent extends AuthEvent {
  /// Where the attempt started, for the sign-in funnel ([AuthSurface]).
  final String surface;

  const AuthSignInWithAppleEvent({this.surface = AuthSurface.login});

  @override
  List<Object?> get props => [surface];
}

class AuthSignInWithGoogleEvent extends AuthEvent {
  /// Where the attempt started, for the sign-in funnel ([AuthSurface]).
  final String surface;

  const AuthSignInWithGoogleEvent({this.surface = AuthSurface.login});

  @override
  List<Object?> get props => [surface];
}

/// The auth stream reported an error: a link that could not be used.
class AuthLinkFailedEvent extends AuthEvent {
  final String message;

  const AuthLinkFailedEvent(this.message);

  @override
  List<Object?> get props => [message];
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

/// Supabase reported `signedOut` and this bloc did not ask for it.
class AuthSessionEndedEvent extends AuthEvent {
  const AuthSessionEndedEvent();
}

class AuthUsernameSetEvent extends AuthEvent {
  final String username;
  const AuthUsernameSetEvent(this.username);

  @override
  List<Object?> get props => [username];
}
