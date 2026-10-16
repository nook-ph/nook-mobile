import 'package:flutter/foundation.dart';

/// One pushed ask per session (ux finding 2): the notification pre-prompt
/// before Maps and the engagement score's keep-saves sheet share it, so a
/// trip never carries two sheets. Toasts, like the directions save nudge,
/// do not spend it.
///
/// Score asks also stand down for the rest of a session once the person
/// opened a sign-in sheet themselves (the Profile tab, a review wall) or was
/// offered the save nudge: they have just seen the offer, or just been
/// asked something.
///
/// A session is the app's process, renewed by [newSession] when the app
/// comes back after the session gap (`GuestSavesSync`).
class SessionAskBudget {
  SessionAskBudget._();

  static final SessionAskBudget instance = SessionAskBudget._();

  String? _spentBy;
  String? _scoreAsksBlockedBy;

  /// What spent the sheet budget this session, or null while unspent.
  String? get spentBy => _spentBy;

  /// Whether a pushed sheet may still show this session.
  bool get canShowSheet => _spentBy == null;

  /// Whether a score ask may still show this session.
  bool get canShowScoreAsk => _spentBy == null && _scoreAsksBlockedBy == null;

  /// A pushed sheet ([kind], e.g. `signup_ask`, `notification_preprompt`)
  /// showed: no other this session.
  void spend(String kind) => _spentBy ??= kind;

  /// The person opened a sign-in sheet themselves ([kind]), or was offered
  /// something at a trip's end: no score ask this session.
  void blockScoreAsks(String kind) => _scoreAsksBlockedBy ??= kind;

  /// A new session: the budget is whole again.
  void newSession() {
    _spentBy = null;
    _scoreAsksBlockedBy = null;
  }

  @visibleForTesting
  void resetForTest() => newSession();
}

/// Values of [SessionAskBudget.spend] and [SessionAskBudget.blockScoreAsks].
abstract final class SessionAskKind {
  static const signUpAsk = 'signup_ask';
  static const notificationPrePrompt = 'notification_preprompt';
  static const pullSignIn = 'pull_sign_in';
  static const directionsNudge = 'directions_nudge';
}
