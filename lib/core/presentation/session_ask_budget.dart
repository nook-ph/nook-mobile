import 'package:flutter/foundation.dart';

/// The app's one "ask per session" (ux finding 2). Every sheet the app opens
/// by itself spends it: the saver survey, the notification pre-prompt, the
/// engagement score's keep-saves sheet, the Map's first-visit location ask.
/// So a session never carries two such sheets. Toasts, like the first-save
/// line or the directions save nudge, do not spend it.
///
/// Three levels, from strongest:
/// - [spend]: a pushed sheet showed; no other pushed sheet this session.
/// - [blockScoreAsks]: the person opened a sign-in (or location) sheet
///   themselves, or was offered the save nudge at a trip's end. They have
///   just seen the offer, or just been asked something: no score ask this
///   session. Other sheets may still show.
/// - [noteShown]: an inline offer was on screen (the Saved tab's keep-saves
///   card, Home's first "See cafes near you" row). It blocks nothing but the
///   saver survey, which wants to be the only thing asked ([claim]).
///
/// A session is the app's process, renewed by [newSession] when the app
/// comes back after the session gap (`GuestSavesSync`).
class SessionAskBudget {
  @visibleForTesting
  SessionAskBudget();

  static final SessionAskBudget instance = SessionAskBudget();

  String? _spentBy;
  String? _scoreAsksBlockedBy;
  String? _notedBy;

  /// What spent the sheet budget this session, or null while unspent.
  String? get spentBy => _spentBy;

  /// Whether a pushed sheet may still show this session.
  bool get canShowSheet => _spentBy == null;

  /// Whether a score ask may still show this session.
  bool get canShowScoreAsk => _spentBy == null && _scoreAsksBlockedBy == null;

  /// Whether anything at all was put in front of the person this session:
  /// a pushed sheet, a sheet they opened, the save nudge or an inline offer.
  bool get anyShown =>
      _spentBy != null || _scoreAsksBlockedBy != null || _notedBy != null;

  /// A pushed sheet ([kind], e.g. `signup_ask`, `notification_preprompt`)
  /// showed: no other this session.
  void spend(String kind) => _spentBy ??= kind;

  /// The person opened a sign-in sheet themselves ([kind]), or was offered
  /// something at a trip's end: no score ask this session.
  void blockScoreAsks(String kind) => _scoreAsksBlockedBy ??= kind;

  /// An inline offer ([kind]) was shown: it counts as this session's prompt
  /// for [claim], and spends nothing.
  void noteShown(String kind) => _notedBy ??= kind;

  /// For an ask that wants to be the only one this session (the saver
  /// survey): true, and spends the budget, when nothing at all was shown
  /// yet ([anyShown]); false otherwise, spending nothing.
  bool claim(String kind) {
    if (anyShown) return false;
    spend(kind);
    return true;
  }

  /// A new session: the budget is whole again.
  void newSession() {
    _spentBy = null;
    _scoreAsksBlockedBy = null;
    _notedBy = null;
  }

  @visibleForTesting
  void resetForTest() => newSession();
}

/// Values of [SessionAskBudget.spend], [SessionAskBudget.blockScoreAsks]
/// and [SessionAskBudget.noteShown].
abstract final class SessionAskKind {
  // Pushed sheets (spend).
  static const signUpAsk = 'signup_ask';
  static const notificationPrePrompt = 'notification_preprompt';
  static const saverSurvey = 'saver_survey';
  static const mapLocationAsk = 'map_location_ask';

  // Opened by the person, or a trip's-end offer (block score asks).
  static const pullSignIn = 'pull_sign_in';
  static const directionsNudge = 'directions_nudge';
  static const homeLocationAsk = 'home_location_ask';

  // Inline offers and other prompts (noted).
  static const keepSavesCard = 'keep_saves_card';
  static const homeLocationRow = 'home_location_row';
  static const locationPrompt = 'location_prompt';
}
