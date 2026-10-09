/// Lets a tab page claim system Back before the tab shell sends it Home.
///
/// Tab pages live in an IndexedStack and stay mounted, so a PopScope inside
/// one would also fire while another tab is showing. Instead the page
/// registers here and [MainShell] asks the current tab first: the Map uses it
/// to close an open cafe card before leaving the tab.
class TabBack {
  TabBack._();

  static final Map<int, bool Function()> _handlers = {};

  /// [handler] returns true when it used the Back press.
  static void register(int tab, bool Function() handler) =>
      _handlers[tab] = handler;

  static void unregister(int tab, bool Function() handler) {
    if (_handlers[tab] == handler) _handlers.remove(tab);
  }

  /// Whether the page on [tab] handled Back itself.
  static bool handle(int tab) => _handlers[tab]?.call() ?? false;
}
