import 'package:flutter/widgets.dart';
import 'package:nook/core/analytics/log_app_event.dart';
import 'package:nook/core/analytics/screen_tracking.dart';

/// Counts taps and says when a run of them is a rage tap: [minTaps] taps,
/// each within [maxGap] of the last and [maxDistance] (Manhattan, logical
/// pixels) of the first. The same thresholds as PostHog's native iOS
/// detector, so counts stay comparable with the old `$rageclick` data.
class RageTapCounter {
  RageTapCounter({
    this.minTaps = 3,
    this.maxGap = const Duration(seconds: 1),
    this.maxDistance = 30,
  });

  final int minTaps;
  final Duration maxGap;
  final double maxDistance;

  Offset? _anchor;
  Duration? _last;
  int _count = 0;

  /// Records a tap at [position] at time [at]; true when it completes a run.
  /// The run then starts over, so one burst reports once.
  bool add(Offset position, Duration at) {
    final anchor = _anchor;
    final last = _last;
    final continues =
        anchor != null &&
        last != null &&
        at - last <= maxGap &&
        (position.dx - anchor.dx).abs() + (position.dy - anchor.dy).abs() <=
            maxDistance;

    if (continues) {
      _count++;
    } else {
      _anchor = position;
      _count = 1;
    }
    _last = at;

    if (_count >= minTaps) {
      _anchor = null;
      _last = null;
      _count = 0;
      return true;
    }
    return false;
  }
}

/// Sends `$rageclick` for rapid repeated taps anywhere in the app.
///
/// Replaces the native iOS detector (turned off in `main.dart`), which only
/// sees the Flutter host view: every event it sent had `$screen_name`
/// "Flutter" and no element, so none could be traced to a screen. This one
/// stamps the screen from [ScreenTracker] and the tap position, and also runs
/// on Android, which had no rage taps at all.
class RageTapDetector extends StatefulWidget {
  const RageTapDetector({super.key, required this.child});

  final Widget child;

  @override
  State<RageTapDetector> createState() => _RageTapDetectorState();
}

class _RageTapDetectorState extends State<RageTapDetector> {
  /// A press that moves further than this is a drag or scroll, not a tap.
  static const _tapSlop = 18.0;

  /// A press held longer than this is a long-press.
  static const _maxPress = Duration(milliseconds: 500);

  final _counter = RageTapCounter();
  final Map<int, ({Offset position, Duration at})> _downs = {};

  void _onDown(PointerDownEvent event) {
    _downs[event.pointer] = (position: event.position, at: event.timeStamp);
  }

  void _onUp(PointerUpEvent event) {
    final down = _downs.remove(event.pointer);
    if (down == null) return;
    if ((event.position - down.position).distance > _tapSlop) return;
    if (event.timeStamp - down.at > _maxPress) return;
    if (!_counter.add(event.position, event.timeStamp)) return;

    final screen = ScreenTracker.instance.current;
    logAppEvent(
      r'$rageclick',
      properties: {
        r'$touch_x': event.position.dx.roundToDouble(),
        r'$touch_y': event.position.dy.roundToDouble(),
        r'$event_type': 'touch',
        r'$screen_name': ?screen,
      },
    );
  }

  void _onCancel(PointerCancelEvent event) => _downs.remove(event.pointer);

  @override
  Widget build(BuildContext context) {
    // Translucent and passive: sees every pointer without taking part in the
    // gesture arena, so no tap is delayed or swallowed.
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _onDown,
      onPointerUp: _onUp,
      onPointerCancel: _onCancel,
      child: widget.child,
    );
  }
}
