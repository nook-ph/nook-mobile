import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:nook/core/analytics/log_app_event.dart';
import 'package:nook/core/analytics/retention_tracking_events.dart';
import 'package:nook/core/analytics/screen_tracking.dart';

/// Logs `home_rail_impression` for [rail] the first time at least
/// [minVisibleFraction] of [child] is on screen during a Home visit.
///
/// A visit is one Home `$screen` ([ScreenTracker.visits]): leaving Home for a
/// cafe or another tab and coming back counts again; scrolling a rail out of
/// view and back, a pull-to-refresh, or the feed rebuilding does not.
///
/// No visibility package: it measures its own box against the screen after a
/// frame, again whenever the page scrolls, and when Home becomes the screen.
class HomeRailImpression extends StatefulWidget {
  const HomeRailImpression({
    super.key,
    required this.rail,
    required this.child,
    this.minVisibleFraction = 0.5,
  });

  final String rail;
  final Widget child;
  final double minVisibleFraction;

  /// The visit each rail was last logged in, kept outside the widget so a
  /// rebuilt rail does not log twice in one visit.
  static final Map<String, int> _loggedInVisit = {};

  @visibleForTesting
  static void resetForTest() => _loggedInVisit.clear();

  @override
  State<HomeRailImpression> createState() => _HomeRailImpressionState();
}

class _HomeRailImpressionState extends State<HomeRailImpression> {
  ScrollPosition? _position;
  bool _scheduled = false;

  ValueListenable<int> get _visits => ScreenTracker.instance.visits;

  @override
  void initState() {
    super.initState();
    _visits.addListener(_schedule);
    _schedule();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final position = Scrollable.maybeOf(context, axis: Axis.vertical)?.position;
    if (position != _position) {
      _position?.removeListener(_schedule);
      _position = position?..addListener(_schedule);
    }
    _schedule();
  }

  @override
  void didUpdateWidget(HomeRailImpression oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.rail != widget.rail) _schedule();
  }

  @override
  void dispose() {
    _visits.removeListener(_schedule);
    _position?.removeListener(_schedule);
    super.dispose();
  }

  void _schedule() {
    if (_scheduled || !mounted) return;
    if (_alreadyLogged) return;
    _scheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      _check();
    });
    // A listener can fire while no frame is coming (a tab switch that
    // changes nothing on screen); make sure one does.
    SchedulerBinding.instance.ensureVisualUpdate();
  }

  bool get _alreadyLogged =>
      HomeRailImpression._loggedInVisit[widget.rail] == _visits.value;

  void _check() {
    if (!mounted || _alreadyLogged) return;
    final current = ScreenTracker.instance.current;
    // Null only before the first screen is reported (widget tests).
    if (current != null && current != ScreenNames.home) return;
    if (!TickerMode.valuesOf(context).enabled) return;
    if (!_isVisible()) return;

    HomeRailImpression._loggedInVisit[widget.rail] = _visits.value;
    logAppEvent(HomeRailEvents.impression, properties: {'rail': widget.rail});
  }

  bool _isVisible() {
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return false;
    final size = box.size;
    if (size.isEmpty) return false;
    final top = box.localToGlobal(Offset.zero).dy;
    final screenHeight = MediaQuery.sizeOf(context).height;
    final visible =
        math.min(top + size.height, screenHeight) - math.max(top, 0.0);
    return visible >= size.height * widget.minVisibleFraction;
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
