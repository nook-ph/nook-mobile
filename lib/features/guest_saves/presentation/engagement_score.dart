import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:nook/core/analytics/log_app_event.dart';
import 'package:nook/core/analytics/saves_events.dart';
import 'package:nook/core/cafe/domain/entities/cafe_status.dart';
import 'package:nook/core/presentation/session_ask_budget.dart';
import 'package:nook/core/presentation/widgets/guest_sign_in_sheet.dart';
import 'package:nook/core/utils/toast_helper.dart';
import 'package:nook/features/auth/presentation/widgets/sign_in_choices.dart';
import 'package:nook/features/guest_saves/data/engagement_store.dart';
import 'package:nook/features/guest_saves/domain/sign_up_ask_rules.dart';
import 'package:nook/injection_container.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Debug builds only: `--dart-define=NOOK_ASK_THRESHOLD=5` asks sooner, to
/// try the ask without twenty points of tapping. Ignored in release.
const _debugThreshold = String.fromEnvironment('NOOK_ASK_THRESHOLD');

/// The guest's engagement score and the soft "keep your saves" ask it
/// triggers (teardowns brief, section 1: Pinterest's scored ask).
///
/// Guest actions add points ([EngagementAction]; a save once per cafe); at a
/// value moment (right after a save, or opening Saved with 3 or more saves)
/// a guest at or over the threshold who has saves sees the keep-saves
/// sign-in sheet, which can always be dismissed. Each decline backs off
/// further ([SignUpAskRules]), and the sheet shares the session's one ask
/// with the notification pre-prompt ([SessionAskBudget]). Nothing is counted
/// for an account.
///
/// App-wide singleton (`sl`).
class EngagementScore {
  EngagementScore({
    required EngagementStore store,
    DateTime Function()? now,
    bool Function()? isSignedIn,
    Stream<void> Function()? sessionStarts,
    SessionAskBudget? budget,
    double? threshold,
  }) : _store = store,
       _now = now ?? DateTime.now,
       _isSignedIn = isSignedIn,
       _sessionStarts = sessionStarts,
       _budget = budget ?? SessionAskBudget.instance,
       threshold = threshold ?? _defaultThreshold();

  final EngagementStore _store;
  final DateTime Function() _now;
  final bool Function()? _isSignedIn;
  final Stream<void> Function()? _sessionStarts;
  final SessionAskBudget _budget;

  /// The score the first ask needs. 20 in release.
  final double threshold;

  /// How long after choosing a sign-in a session still counts as the ask's
  /// (`signup_ask_completed`): email goes through `/login` and a code.
  static const completionWindow = Duration(minutes: 30);

  static double _defaultThreshold() {
    if (!kDebugMode) return SignUpAskRules.threshold;
    return double.tryParse(_debugThreshold) ?? SignUpAskRules.threshold;
  }

  /// Serialises reads and writes, so quick actions do not lose points.
  Future<void> _queue = Future.value();
  bool _asking = false;

  /// `signup_ask_suppressed` reasons already sent this session.
  final Set<String> _suppressedLogged = {};

  bool get _signedIn {
    final check = _isSignedIn;
    if (check != null) return check();
    try {
      return Supabase.instance.client.auth.currentSession != null;
    } catch (_) {
      return false;
    }
  }

  Stream<void> _sessionStartStream() {
    final custom = _sessionStarts;
    if (custom != null) return custom();
    try {
      return Supabase.instance.client.auth.onAuthStateChange
          .where((s) => s.event == AuthChangeEvent.signedIn)
          .map((_) {});
    } catch (_) {
      return const Stream.empty();
    }
  }

  Future<T> _locked<T>(Future<T> Function() body) {
    final result = _queue.then((_) => body());
    _queue = result.then((_) {}, onError: (_) {});
    return result;
  }

  /// How many asks ended without a sign-in, kept current for the Saved
  /// tab (its keep-saves card shrinks to a row after two, ux finding 6).
  /// Read once with [read] to fill it.
  final ValueNotifier<int> declines = ValueNotifier(0);

  Future<EngagementState> read() => _locked(() async {
    final state = await _store.read();
    declines.value = state.declines;
    return state;
  });

  Future<void> _save(EngagementState state) async {
    await _store.write(state);
    declines.value = state.declines;
  }

  Future<void> _update(EngagementState Function(EngagementState) change) =>
      _locked(() async => _save(change(await _store.read())));

  /// Adds [action]'s points for a guest. Saves go through [recordSave].
  Future<void> record(EngagementAction action) async {
    if (_signedIn) return;
    await _update((s) => s.add(action));
  }

  /// A guest saved [cafeId]: its points, once per cafe.
  Future<void> recordSave(String cafeId) async {
    if (_signedIn) return;
    await _update((s) => s.saved(cafeId));
  }

  /// A guest's save of [cafeId] was removed or undone: the points go back.
  Future<void> recordUnsave(String cafeId) async {
    if (_signedIn) return;
    await _update((s) => s.unsaved(cafeId));
  }

  /// A session started (launch, or back after [SignUpAskRules.sessionGap]).
  Future<void> recordSession() async {
    _suppressedLogged.clear();
    if (_signedIn) return;
    await _update((s) => s.session(_now()));
  }

  /// Why a guest with [savesCount] saves would not be asked right now
  /// ([SignUpAskBlock]), or null when they would.
  Future<String?> blockedBy({required int savesCount}) async {
    if (_signedIn || _asking) return SignUpAskBlock.sessionBudget;
    if (!_budget.canShowScoreAsk) return SignUpAskBlock.sessionBudget;
    final state = await read();
    return SignUpAskRules.blockedBy(
      state,
      now: _now(),
      savesCount: savesCount,
      threshold: threshold,
    );
  }

  /// Whether a guest with [savesCount] saves would be asked right now.
  Future<bool> wouldAsk({required int savesCount}) async =>
      await blockedBy(savesCount: savesCount) == null;

  void _logSuppressed(String reason, String trigger) {
    if (reason == SignUpAskBlock.noSaves) return;
    if (!_suppressedLogged.add(reason)) return;
    logAppEvent(
      SavesEvents.signUpAskSuppressed,
      properties: {'reason': reason, 'trigger': trigger},
    );
  }

  /// Shows the keep-saves sheet when the rules allow it, at [trigger] (a
  /// [SignUpAskTrigger] value). [savesCount]: the guest's saves now.
  /// [saved]: the save that just happened, which the sheet's first line
  /// confirms. Returns what happened.
  Future<SignUpAskResult> maybeAsk(
    BuildContext context, {
    required String trigger,
    required int savesCount,
    SignUpAskSave? saved,
    Future<SignUpAskAnswer> Function(BuildContext context, SignUpAskCopy copy)?
    showSheet,
    bool Function()? stillWanted,
  }) async {
    // An ask already on screen is not a suppression: nothing to log.
    if (_signedIn || _asking) return SignUpAskResult.notShown;
    final blocked = await blockedBy(savesCount: savesCount);
    if (blocked != null) {
      _logSuppressed(blocked, trigger);
      return SignUpAskResult.notShown;
    }
    if (!context.mounted || _asking) return SignUpAskResult.notShown;
    _asking = true;
    try {
      // Checked again after every wait: the page may have gone, another
      // sheet may have taken the session meanwhile (the Directions ask),
      // or the caller's moment may have passed (Saved left for a tab).
      bool canShow() =>
          context.mounted &&
          _budget.canShowScoreAsk &&
          (stillWanted?.call() ?? true);
      // One locked step, so points recorded meanwhile are not written over.
      // The session is taken before the write, so nothing can slip in
      // between; an ask that did not get this far counts nowhere.
      final asked = await _locked(() async {
        final before = await _store.read();
        if (!canShow()) return null;
        _budget.spend(SessionAskKind.signUpAsk);
        final shown = before.asked(_now(), savesCount: savesCount);
        await _save(shown);
        return (before, shown);
      });
      if (asked == null) return SignUpAskResult.notShown;
      final (before, shown) = asked;
      final props = {
        'trigger': trigger,
        'score': before.score,
        'ask_number': shown.asks,
      };
      logAppEvent(SavesEvents.signUpAskShown, properties: props);
      if (!context.mounted) return SignUpAskResult.shownStillGuest;
      dismissToasts();
      final copy = SignUpAskCopy.forAsk(
        askNumber: shown.asks,
        savesCount: savesCount,
        saved: saved,
      );
      final answer = await (showSheet ?? _showKeepSavesSheet)(context, copy);
      final provider = answer.provider;
      if (provider != null) {
        logAppEvent(
          SavesEvents.signUpAskAccepted,
          properties: {...props, 'provider': provider},
        );
      }
      if (_signedIn) {
        _logCompleted(props, provider);
        return SignUpAskResult.signedIn;
      }
      // Not signed in (yet): backs off like a decline. Email may still
      // finish on /login; the session then logs the completion.
      final lowered = await _locked(() async {
        final next = (await _store.read()).dismissed(
          stay: answer.dismissal == GuestSheetDismissal.stayOnPhone,
        );
        await _save(next);
        return next;
      });
      if (provider != null) {
        // Email goes on to `/login` and may finish there. A Google or Apple
        // sign-in that ended without a session was cancelled: a later
        // sign-in from elsewhere is not this ask's, and the person stays
        // here, where the save is still confirmed.
        if (provider == SignInChoice.email.name) {
          _awaitCompletion(props, provider);
          return SignUpAskResult.signInStarted;
        }
        return SignUpAskResult.shownStillGuest;
      } else {
        logAppEvent(
          SavesEvents.signUpAskDismissed,
          properties: {
            ...props,
            'score_after': lowered.score,
            'how': (answer.dismissal ?? GuestSheetDismissal.swipeOrBack).wire,
            'saves_count': savesCount,
          },
        );
      }
      return SignUpAskResult.shownStillGuest;
    } finally {
      _asking = false;
    }
  }

  void _logCompleted(Map<String, Object> props, String? provider) {
    logAppEvent(
      SavesEvents.signUpAskCompleted,
      properties: {...props, 'provider': ?provider},
    );
  }

  /// A sign-in chosen from the ask that has not started a session yet (email
  /// goes on through `/login`): completed if one starts within
  /// [completionWindow].
  void _awaitCompletion(Map<String, Object> props, String provider) {
    unawaited(
      _sessionStartStream().first
          .timeout(completionWindow)
          .then((_) => _logCompleted(props, provider))
          .catchError((Object _) {}),
    );
  }

  static Future<SignUpAskAnswer> _showKeepSavesSheet(
    BuildContext context,
    SignUpAskCopy copy,
  ) async {
    final outcome = await GuestSignInSheet.showDetailed(
      context,
      icon: LucideIcons.bookmark,
      title: copy.title,
      reason: copy.reason,
      confirmation: copy.confirmation,
      stayLabel: copy.stayLabel,
      trigger: 'keep_saves_${KeepSavesSurface.engagementAsk}',
      pushed: true,
    );
    return SignUpAskAnswer(
      provider: outcome.choice?.name,
      dismissal: outcome.dismissedBy,
    );
  }
}

/// The save a sheet opened after, for its confirmation line.
class SignUpAskSave {
  const SignUpAskSave({required this.cafeName, required this.status});

  final String cafeName;
  final CafeStatus status;
}

/// The sheet's words for one ask (ux findings 1 and 4).
class SignUpAskCopy {
  const SignUpAskCopy({
    required this.title,
    required this.reason,
    this.confirmation,
    this.stayLabel,
  });

  /// Ask 1 names the count; later asks state the stake and offer
  /// [stayOnPhoneLabel], which ends score asks.
  factory SignUpAskCopy.forAsk({
    required int askNumber,
    required int savesCount,
    SignUpAskSave? saved,
  }) {
    final repeat = askNumber >= 2;
    return SignUpAskCopy(
      title: repeat ? stakeTitle(savesCount) : keepTitle(savesCount),
      reason: repeat ? stakeReason : firstReason,
      confirmation: saved == null ? null : confirmationFor(saved),
      stayLabel: repeat ? stayOnPhoneLabel : null,
    );
  }

  final String title;
  final String reason;
  final String? confirmation;
  final String? stayLabel;

  static String keepTitle(int n) => n == 1
      ? 'Keep your cafe on any phone'
      : 'Keep your $n cafes on any phone';

  static String stakeTitle(int n) => n == 1
      ? 'Your cafe is only on this phone'
      : 'Your $n cafes are only on this phone';

  static const firstReason =
      'Sign in and everything you saved on this phone moves to your account.';
  static const stakeReason =
      'Sign in and they move to your account, so a new phone keeps them.';
  static const stayOnPhoneLabel = 'Keep using on this phone';

  /// "Flavour Coffee saved", "Flavour Coffee added to Been".
  static String confirmationFor(SignUpAskSave saved) {
    final name = saved.cafeName.trim().isEmpty ? 'Cafe' : saved.cafeName.trim();
    return saved.status == CafeStatus.been
        ? '$name added to Been'
        : '$name saved';
  }
}

/// How the sheet ended.
class SignUpAskAnswer {
  const SignUpAskAnswer({this.provider, this.dismissal});

  /// `google`, `apple` or `email` when a sign-in was chosen (it may not
  /// have finished: see `signup_ask_completed`).
  final String? provider;

  /// How it was dismissed, when no sign-in was chosen.
  final GuestSheetDismissal? dismissal;
}

/// What [EngagementScore.maybeAsk] did.
enum SignUpAskResult {
  notShown,

  /// Shown, and the person is still a guest: the caller confirms the save
  /// as usual.
  shownStillGuest,

  /// Shown, and a session started from it.
  signedIn,

  /// Shown, and a sign-in was chosen that goes on elsewhere (email on
  /// `/login`): no session yet, and the caller's page is no longer on top.
  signInStarted;

  bool get shown => this != notShown;
}

/// Values of `trigger` on the sign-up ask events.
abstract final class SignUpAskTrigger {
  /// Right after a guest save.
  static const afterSave = 'after_save';

  /// Opening Saved (the tab, or Your places' See all) with
  /// three or more saves (`SignUpAskOnSaved`).
  static const savedOpen = 'saved_open';
}

/// Records [action] for the app's score, if there is one. Fire and forget.
void recordEngagement(EngagementAction action) {
  if (!sl.isRegistered<EngagementScore>()) return;
  unawaited(sl<EngagementScore>().record(action));
}
