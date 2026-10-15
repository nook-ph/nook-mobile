import 'package:flutter/widgets.dart';
import 'package:nook/core/analytics/log_app_event.dart';
import 'package:nook/core/analytics/retention_tracking_events.dart';

/// Logs `empty_state_shown` once when [child] first appears, and again only
/// if the [reason] changes while it stays up. Draws [child] unchanged.
class EmptyStateTracker extends StatefulWidget {
  const EmptyStateTracker({
    super.key,
    required this.screen,
    required this.reason,
    required this.child,
  });

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

  void _log() => logAppEvent(
    EmptyStateEvents.shown,
    properties: {'screen': widget.screen, 'reason': widget.reason},
  );

  @override
  Widget build(BuildContext context) => widget.child;
}
