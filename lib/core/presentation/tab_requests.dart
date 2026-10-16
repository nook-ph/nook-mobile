import 'package:flutter/foundation.dart';

/// Lets anything ask the tab shell to show one of its tabs, from wherever
/// it is (a toast's "View" on a cafe page, a merge confirmation after
/// sign-in). [MainShell] pops back to itself and switches tabs.
///
/// A notifier rather than the shell's NavigationBloc, which lives inside the
/// shell and cannot be read from pages pushed above it.
abstract final class TabRequests {
  static final ValueNotifier<TabRequest?> _requests = ValueNotifier(null);

  static ValueListenable<TabRequest?> get requests => _requests;

  /// Shows [tab] (a `MainShell` index), closing pages pushed over the shell.
  static void open(int tab) => _requests.value = TabRequest(tab);
}

/// One request; a new instance each time, so the same tab asked for twice
/// still notifies.
class TabRequest {
  TabRequest(this.tab);

  final int tab;
}
