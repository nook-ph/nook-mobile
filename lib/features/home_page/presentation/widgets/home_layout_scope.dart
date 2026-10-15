import 'package:flutter/widgets.dart';

/// The published Home layout's version for the rails below it, so their
/// analytics events can say which layout the person saw. Absent (or null)
/// on the built-in Home: events then carry no `layout_version`.
class HomeLayoutScope extends InheritedWidget {
  const HomeLayoutScope({
    super.key,
    required this.version,
    required super.child,
  });

  final String? version;

  static String? versionOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<HomeLayoutScope>()?.version;

  /// [properties] plus `layout_version` when a layout is in force.
  static Map<String, Object> withVersion(
    BuildContext context,
    Map<String, Object> properties,
  ) {
    final version = versionOf(context);
    return version == null
        ? properties
        : {...properties, 'layout_version': version};
  }

  @override
  bool updateShouldNotify(HomeLayoutScope oldWidget) =>
      version != oldWidget.version;
}
