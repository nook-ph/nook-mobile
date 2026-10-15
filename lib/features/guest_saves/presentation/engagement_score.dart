import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:nook/core/analytics/log_app_event.dart';
import 'package:nook/core/analytics/saves_events.dart';
import 'package:nook/core/utils/toast_helper.dart';
import 'package:nook/features/guest_saves/data/engagement_store.dart';
import 'package:nook/features/guest_saves/domain/sign_up_ask_rules.dart';
import 'package:nook/features/guest_saves/presentation/save_actions.dart';
import 'package:nook/injection_container.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Debug builds only: `--dart-define=NOOK_ASK_THRESHOLD=5` asks sooner, to
/// try the ask without twenty points of tapping. Ignored in release.
const _debugThreshold = String.fromEnvironment('NOOK_ASK_THRESHOLD');

/// The guest's engagement score and the soft "keep your saves" ask it
/// triggers (teardowns brief, section 1: Pinterest's scored ask).
///
/// Guest actions add points ([EngagementAction]); at a value moment (right
/// after a save, or coming back to Home) a guest at or over the threshold
/// who has saves sees the keep-saves sign-in sheet, which can always be
/// dismissed. Each dismissal takes [SignUpAskRules.dismissPenalty] off; at
/// most one ask a week, three in all. Nothing is counted for an account.
///
/// App-wide singleton (`sl`).
class EngagementScore {
  EngagementScore({
    required EngagementStore store,
    DateTime Function()? now,
    bool Function()? isSignedIn,
    double? threshold,
  }) : _store = store,
       _now = now ?? DateTime.now,
       _isSignedIn = isSignedIn,
       threshold = threshold ?? _defaultThreshold();

  final EngagementStore _store;
  final DateTime Function() _now;
  final bool Function()? _isSignedIn;

  /// The score the ask needs. 20 in release.
  final double threshold;

  static double _defaultThreshold() {
    if (!kDebugMode) return SignUpAskRules.threshold;
    return double.tryParse(_debugThreshold) ?? SignUpAskRules.threshold;
  }

  /// Serialises reads and writes, so quick actions do not lose points.
  Future<void> _queue = Future.value();
  bool _asking = false;

  bool get _signedIn {
    final check = _isSignedIn;
    if (check != null) return check();
    try {
      return Supabase.instance.client.auth.currentSession != null;
    } catch (_) {
      return false;
    }
  }

  Future<T> _locked<T>(Future<T> Function() body) {
    final result = _queue.then((_) => body());
    _queue = result.then((_) {}, onError: (_) {});
    return result;
  }

  Future<EngagementState> read() => _locked(_store.read);

  /// Adds [action]'s points for a guest.
  Future<void> record(EngagementAction action) async {
    if (_signedIn) return;
    await _locked(() async {
      await _store.write((await _store.read()).add(action));
    });
  }

  /// A session started (launch, or back after [SignUpAskRules.sessionGap]).
  Future<void> recordSession() async {
    if (_signedIn) return;
    await _locked(() async {
      await _store.write((await _store.read()).session(_now()));
    });
  }

  /// Whether a guest with [hasSaves] would be asked right now.
  Future<bool> wouldAsk({required bool hasSaves}) async {
    if (_signedIn || _asking) return false;
    final state = await read();
    return SignUpAskRules.shouldAsk(
      state,
      now: _now(),
      hasSaves: hasSaves,
      threshold: threshold,
    );
  }

  /// Shows the keep-saves sheet when the rules allow it, at [trigger] (a
  /// [SignUpAskTrigger] value). Returns whether it was shown.
  Future<bool> maybeAsk(
    BuildContext context, {
    required String trigger,
    required bool hasSaves,
    Future<SignUpAskAnswer> Function(BuildContext context)? showSheet,
  }) async {
    if (!await wouldAsk(hasSaves: hasSaves)) return false;
    if (!context.mounted || _asking) return false;
    _asking = true;
    try {
      final before = await read();
      final shown = before.asked(_now());
      await _locked(() => _store.write(shown));
      final props = {
        'trigger': trigger,
        'score': before.score,
        'ask_number': shown.asks,
      };
      logAppEvent(SavesEvents.signUpAskShown, properties: props);
      if (!context.mounted) return true;
      dismissToasts();
      final answer = await (showSheet ?? _showKeepSavesSheet)(context);
      if (answer.accepted) {
        logAppEvent(
          SavesEvents.signUpAskAccepted,
          properties: {...props, 'provider': ?answer.provider},
        );
      } else {
        final lowered = await _locked(() async {
          final next = (await _store.read()).dismissed();
          await _store.write(next);
          return next;
        });
        logAppEvent(
          SavesEvents.signUpAskDismissed,
          properties: {...props, 'score_after': lowered.score},
        );
      }
      return true;
    } finally {
      _asking = false;
    }
  }

  static Future<SignUpAskAnswer> _showKeepSavesSheet(
    BuildContext context,
  ) async {
    final choice = await openKeepSavesSignIn(
      context,
      KeepSavesSurface.engagementAsk,
    );
    return SignUpAskAnswer(accepted: choice != null, provider: choice?.name);
  }
}

/// How the ask ended.
class SignUpAskAnswer {
  const SignUpAskAnswer({required this.accepted, this.provider});

  /// A sign-in was chosen.
  final bool accepted;

  /// `google`, `apple` or `email`.
  final String? provider;
}

/// Values of `trigger` on the sign-up ask events.
abstract final class SignUpAskTrigger {
  /// Right after a guest save.
  static const afterSave = 'after_save';

  /// Coming back to Home.
  static const homeReturn = 'home_return';
}

/// Records [action] for the app's score, if there is one. Fire and forget.
void recordEngagement(EngagementAction action) {
  if (!sl.isRegistered<EngagementScore>()) return;
  unawaited(sl<EngagementScore>().record(action));
}
