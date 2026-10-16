import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nook/core/analytics/screen_tracking.dart';
import 'package:nook/features/guest_saves/presentation/cubit/guest_saves_cubit.dart';
import 'package:nook/features/guest_saves/presentation/engagement_score.dart';
import 'package:nook/injection_container.dart';

/// Opening Saved (the tab, or Your places' See all) with [minSaves] or more
/// saves is one of the two moments the engagement score may ask a guest to
/// keep their saves; the other is right after a save. It replaced the
/// return to Home (ux finding 3): here the sheet is about exactly what is on
/// screen. Only when Saved is reached from another tab or at launch, not on
/// the way back from a cafe page; never over a sheet; once Saved has
/// settled.
///
/// Draws nothing; sits on the guest Saved page.
class SignUpAskOnSaved extends StatefulWidget {
  const SignUpAskOnSaved({super.key, this.score, this.tracker});

  /// Defaults to the app's; tests pass their own.
  final EngagementScore? score;
  final ScreenTracker? tracker;

  /// Saves needed before opening Saved counts as a value moment.
  static const minSaves = 3;

  /// Saved has to stay on screen this long first.
  static const settle = Duration(milliseconds: 600);

  @override
  State<SignUpAskOnSaved> createState() => _SignUpAskOnSavedState();
}

class _SignUpAskOnSavedState extends State<SignUpAskOnSaved> {
  ScreenTracker get _tracker => widget.tracker ?? ScreenTracker.instance;

  EngagementScore? get _score =>
      widget.score ??
      (sl.isRegistered<EngagementScore>() ? sl<EngagementScore>() : null);

  /// The screen before the current one, to tell a tab switch from a pop.
  String? _previous;
  late String? _current = _tracker.current;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _tracker.visits.addListener(_onVisit);
    // Built lazily, the page appears on its first opening.
    if (_current == ScreenNames.saved) _schedule(_tracker.visits.value);
  }

  @override
  void dispose() {
    _tracker.visits.removeListener(_onVisit);
    _timer?.cancel();
    super.dispose();
  }

  void _onVisit() {
    _previous = _current;
    _current = _tracker.current;
    _timer?.cancel();
    if (_current != ScreenNames.saved) return;
    final previous = _previous;
    final fromTab = previous == null || ScreenNames.tabs.contains(previous);
    if (fromTab) _schedule(_tracker.visits.value);
  }

  void _schedule(int visit) {
    _timer?.cancel();
    _timer = Timer(SignUpAskOnSaved.settle, () => _maybeAsk(visit));
  }

  Future<void> _maybeAsk(int visit) async {
    final score = _score;
    if (!mounted || score == null) return;
    if (_tracker.visits.value != visit ||
        _tracker.current != ScreenNames.saved) {
      return;
    }
    // Still this visit of Saved, on top: the reads below wait, and the tab
    // stays mounted behind another one.
    bool stillHere() =>
        mounted &&
        _tracker.visits.value == visit &&
        _tracker.current == ScreenNames.saved &&
        (ModalRoute.of(context)?.isCurrent ?? true);
    if (!stillHere()) return;
    final saves = context.read<GuestSavesCubit>();
    await saves.load();
    if (!mounted || !stillHere()) return;
    final count = saves.state.saves.length;
    if (count < SignUpAskOnSaved.minSaves) return;
    await score.maybeAsk(
      context,
      trigger: SignUpAskTrigger.savedOpen,
      savesCount: count,
      stillWanted: stillHere,
    );
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
