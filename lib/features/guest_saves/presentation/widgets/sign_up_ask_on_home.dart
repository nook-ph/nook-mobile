import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nook/core/analytics/screen_tracking.dart';
import 'package:nook/features/guest_saves/presentation/cubit/guest_saves_cubit.dart';
import 'package:nook/features/guest_saves/presentation/engagement_score.dart';
import 'package:nook/injection_container.dart';

/// Coming back to Home is one of the two moments the engagement score may
/// ask a guest to keep their saves (the other is right after a save). Not
/// the first Home of the launch, never over a sheet or the keyboard, and
/// only once Home has settled, so it never interrupts something under way.
///
/// Draws nothing; sits in Home's feed.
class SignUpAskOnHome extends StatefulWidget {
  const SignUpAskOnHome({super.key, this.score, this.tracker});

  /// Defaults to the app's; tests pass their own.
  final EngagementScore? score;
  final ScreenTracker? tracker;

  /// Home has to stay on screen this long first.
  static const settle = Duration(milliseconds: 900);

  @override
  State<SignUpAskOnHome> createState() => _SignUpAskOnHomeState();
}

class _SignUpAskOnHomeState extends State<SignUpAskOnHome> {
  ScreenTracker get _tracker => widget.tracker ?? ScreenTracker.instance;

  EngagementScore? get _score =>
      widget.score ??
      (sl.isRegistered<EngagementScore>() ? sl<EngagementScore>() : null);

  /// The Home showing when this was built is the launch's (or the feed's
  /// first load), not a return.
  late int _seenVisit = _tracker.visits.value;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _tracker.visits.addListener(_onVisit);
  }

  @override
  void dispose() {
    _tracker.visits.removeListener(_onVisit);
    _timer?.cancel();
    super.dispose();
  }

  void _onVisit() {
    final visit = _tracker.visits.value;
    if (visit == _seenVisit) return;
    _seenVisit = visit;
    _timer?.cancel();
    if (_tracker.current != ScreenNames.home) return;
    _timer = Timer(SignUpAskOnHome.settle, () => _maybeAsk(visit));
  }

  Future<void> _maybeAsk(int visit) async {
    final score = _score;
    if (!mounted || score == null) return;
    // Still the same Home visit, nothing over it, not typing.
    if (_tracker.visits.value != visit ||
        _tracker.current != ScreenNames.home) {
      return;
    }
    if (!(ModalRoute.of(context)?.isCurrent ?? true)) return;
    if (MediaQuery.viewInsetsOf(context).bottom > 0) return;
    final saves = context.read<GuestSavesCubit>();
    await saves.load();
    if (!mounted) return;
    await score.maybeAsk(
      context,
      trigger: SignUpAskTrigger.homeReturn,
      hasSaves: !saves.state.isEmpty,
    );
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
