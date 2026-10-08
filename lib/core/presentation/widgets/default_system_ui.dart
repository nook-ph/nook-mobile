import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Dark status-bar icons wherever a page doesn't choose its own.
///
/// The photo viewers ask for light icons over their black ground. Pages
/// without an AppBar (Home, Profile) set nothing, so once a viewer closed
/// its light icons stayed: white on white app-wide. Sitting under the
/// Navigator, this is the region found when nothing above it claims the
/// status bar, while any route's own region (a viewer's, an AppBar's) still
/// wins while it is on screen.
class DefaultSystemUi extends StatelessWidget {
  const DefaultSystemUi({super.key, required this.child});

  final Widget child;

  static final style = SystemUiOverlayStyle.dark.copyWith(
    statusBarColor: Colors.transparent,
  );

  @override
  Widget build(BuildContext context) =>
      AnnotatedRegion<SystemUiOverlayStyle>(value: style, child: child);
}
