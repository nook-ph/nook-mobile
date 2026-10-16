import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Calls [onSeen] once, when at least [minFraction] of [child] has been on
/// screen for [dwell]: inside its scroll view's viewport, on the tab that is
/// showing (an IndexedStack's hidden tabs have tickers off) and on the route
/// that is on top.
///
/// For counting an offer as seen only when it was: a card laid out below the
/// fold, or on a tab nobody opened, is not a show.
class OnScreenDetector extends StatefulWidget {
  const OnScreenDetector({
    super.key,
    required this.child,
    required this.onSeen,
    this.minFraction = 0.5,
    this.dwell = const Duration(seconds: 1),
  });

  final Widget child;
  final VoidCallback onSeen;
  final double minFraction;
  final Duration dwell;

  /// How much of [item] lies inside [viewport], 0 to 1.
  @visibleForTesting
  static double visibleFraction(Rect item, Rect viewport) {
    if (item.isEmpty) return 0;
    final overlap = item.intersect(viewport);
    if (overlap.width <= 0 || overlap.height <= 0) return 0;
    return (overlap.width * overlap.height) / (item.width * item.height);
  }

  @override
  State<OnScreenDetector> createState() => _OnScreenDetectorState();
}

class _OnScreenDetectorState extends State<OnScreenDetector> {
  ScrollPosition? _position;
  ValueListenable<TickerModeData>? _tickers;
  Timer? _timer;
  bool _seen = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final position = Scrollable.maybeOf(context)?.position;
    if (position != _position) {
      _position?.removeListener(_checkAfterFrame);
      _position = position?..addListener(_checkAfterFrame);
    }
    final tickers = TickerMode.getValuesNotifier(context);
    if (tickers != _tickers) {
      _tickers?.removeListener(_checkAfterFrame);
      _tickers = tickers..addListener(_checkAfterFrame);
    }
    _checkAfterFrame();
  }

  @override
  void didUpdateWidget(OnScreenDetector oldWidget) {
    super.didUpdateWidget(oldWidget);
    _checkAfterFrame();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _position?.removeListener(_checkAfterFrame);
    _tickers?.removeListener(_checkAfterFrame);
    super.dispose();
  }

  bool _checkQueued = false;

  /// Positions are only current once the scroll or tab change is laid out.
  void _checkAfterFrame() {
    if (_seen || _checkQueued) return;
    _checkQueued = true;
    WidgetsBinding.instance
      ..addPostFrameCallback((_) {
        _checkQueued = false;
        _check();
      })
      ..ensureVisualUpdate();
  }

  bool _onScreen() {
    if (!mounted) return false;
    if (!(_tickers?.value.enabled ?? true)) return false;
    if (!(ModalRoute.of(context)?.isCurrent ?? true)) return false;
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return false;
    final item = box.localToGlobal(Offset.zero) & box.size;
    Rect viewport = Offset.zero & MediaQuery.sizeOf(context);
    final scrollBox = _position?.context.notificationContext
        ?.findRenderObject();
    if (scrollBox is RenderBox && scrollBox.attached && scrollBox.hasSize) {
      viewport = viewport.intersect(
        scrollBox.localToGlobal(Offset.zero) & scrollBox.size,
      );
    }
    return OnScreenDetector.visibleFraction(item, viewport) >=
        widget.minFraction;
  }

  void _check() {
    if (_seen) return;
    if (!_onScreen()) {
      _timer?.cancel();
      _timer = null;
      return;
    }
    _timer ??= Timer(widget.dwell, () {
      _timer = null;
      if (_seen || !_onScreen()) return;
      _seen = true;
      _position?.removeListener(_checkAfterFrame);
      widget.onSeen();
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
