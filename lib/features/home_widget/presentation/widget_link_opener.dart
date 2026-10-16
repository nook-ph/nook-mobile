import 'package:flutter/widgets.dart';
import 'package:nook/features/home_widget/presentation/widget_links.dart';

/// Opens the home-screen widget's links ([WidgetLinks.pending]) once the
/// tab shell is on screen: at a cold start from the widget, and whenever the
/// widget is tapped while the app is open.
class WidgetLinkOpener extends StatefulWidget {
  const WidgetLinkOpener({
    super.key,
    required this.onLink,
    required this.child,
  });

  /// Opens the link; false when it was dropped instead.
  final bool Function(WidgetLink link) onLink;
  final Widget child;

  @override
  State<WidgetLinkOpener> createState() => _WidgetLinkOpenerState();
}

class _WidgetLinkOpenerState extends State<WidgetLinkOpener> {
  @override
  void initState() {
    super.initState();
    WidgetLinks.openerAttached();
    WidgetLinks.pending.addListener(_schedule);
    _schedule();
  }

  @override
  void dispose() {
    WidgetLinks.pending.removeListener(_schedule);
    WidgetLinks.openerDetached();
    super.dispose();
  }

  void _schedule() {
    if (WidgetLinks.pending.value == null) return;
    // After the frame the redirect to Home builds, so the cafe goes on top.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final link = WidgetLinks.take();
      if (link == null) return;
      WidgetLinks.logTap(link, blocked: !widget.onLink(link));
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
