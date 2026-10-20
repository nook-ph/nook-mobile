// PostHog events for the sign-in funnel, sent through `logAppEvent`. They
// sit beside the step events added with "Measure sign-up and empty searches"
// (`auth_email_checked`, `signup_details_submitted`, `signup_code_submitted`,
// `signup_username_set`, `sign_in_finished`), which keep their names: these
// three frame the whole attempt, those say how far inside it someone got.
// No email, name or username goes in the properties.

/// Sign-in funnel events.
abstract final class AuthEvents {
  /// Someone chose a way to sign in: tapped Google or Apple, or Continue
  /// with an email typed. Properties: `method` (one of [AuthMethod]),
  /// `surface` (one of [AuthSurface]).
  static const signinStarted = 'signin_started';

  /// The attempt ended signed in, past the username step when there was
  /// one. Properties: `method`, `surface`, `new_account` (the attempt made
  /// an account rather than opening one).
  static const signinCompleted = 'signin_completed';

  /// Someone left a step without finishing it. Properties: `step` (one of
  /// [AuthStep]), `reason` (one of [AuthAbandonReason]), and `method` when
  /// it is known. Sent at most once per visit to a step. A step left for the
  /// background and later finished still counts once here, so read it next
  /// to [signinCompleted], not on its own.
  static const signinStepAbandoned = 'signin_step_abandoned';
}

/// How someone signed in, for [AuthEvents].
abstract final class AuthMethod {
  static const google = 'google';
  static const apple = 'apple';
  static const email = 'email';
}

/// Where a sign-in started, for [AuthEvents.signinStarted].
abstract final class AuthSurface {
  /// The "Log in or sign up" page.
  static const login = 'login';

  /// A guest sign-in sheet (Save, Been, a tab, a crawl), signing in in place.
  static const sheet = 'sheet';
}

/// A step of the sign-in flow, for [AuthEvents.signinStepAbandoned].
abstract final class AuthStep {
  /// The Google or Apple sheet, closed without signing in.
  static const provider = 'provider';

  /// "Log in" (password) for an existing email account.
  static const password = 'password';

  /// "Create your account" (name and password).
  static const details = 'details';

  /// "Enter your code" (the emailed OTP).
  static const otp = 'otp';

  /// "Pick a username".
  static const username = 'username';
}

/// Why a step counts as abandoned.
abstract final class AuthAbandonReason {
  /// The page closed without the step finishing (Back, Go back, a redirect).
  static const left = 'left';

  /// The app went to the background while the step was open.
  static const background = 'background';

  /// The provider sheet was closed.
  static const cancelled = 'cancelled';

  /// "Use a different account" on the username step.
  static const switchedAccount = 'switched_account';
}
