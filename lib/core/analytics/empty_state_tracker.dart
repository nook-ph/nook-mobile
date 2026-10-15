import 'package:flutter/widgets.dart';
import 'package:nook/core/analytics/log_app_event.dart';
import 'package:nook/core/analytics/retention_tracking_events.dart';

/// Logs `empty_state_shown` once when [child] first appears, and again only
/// if the [reason] changes while it stays up. Draws [child] unchanged.
///
/// With [sticky], "once" outlives the widget: a screen that swaps the empty
/// state for a skeleton on every reload (the map, on each pan) logs a reason
/// again only after [reset] says results came back in between.
class EmptyStateTracker extends StatefulWidget {
  const EmptyStateTracker({
    super.key,
    required this.screen,
    required this.reason,
    required this.child,
    this.sticky = false,
  });

  /// The last reason logged per [screen] by a [sticky] tracker.
  static final Map<String, String> _lastSticky = {};

  /// [screen] showed results: its next empty state is a new one.
  static void reset(String screen) => _lastSticky.remove(screen);

  /// Remember the logged reason across remounts until [reset].
  final bool sticky;

  /// `map`, `search`, `list_detail`.
  final String screen;

  /// Why it is empty: `no_cafes_in_area`, `filtered`, `no_match`,
  /// `outside_cebu`, `empty_list`, `load_error_<type>`.
  final String reason;

  final Widget child;

  @override
  State<EmptyStateTracker> createState() => _EmptyStateTrackerState();
}

class _EmptyStateTrackerState extends State<EmptyStateTracker> {
  @override
  void initState() {
    super.initState();
    _log();
  }

  @override
  void didUpdateWidget(EmptyStateTracker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reason != widget.reason ||
        oldWidget.screen != widget.screen) {
      _log();
    }
  }

  void _log() {
    if (widget.sticky) {
      final last = EmptyStateTracker._lastSticky[widget.screen];
      if (last == widget.reason) return;
      EmptyStateTracker._lastSticky[widget.screen] = widget.reason;
    }
    logAppEvent(
      EmptyStateEvents.shown,
      properties: {'screen': widget.screen, 'reason': widget.reason},
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
