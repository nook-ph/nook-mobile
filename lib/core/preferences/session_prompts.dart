/// Whether this app run has already put a prompt in front of the user: a
/// sheet, a pre-prompt, a nudge toast or an inline offer. Prompts that only
/// make sense at app open (the saver survey) check it so they never stack on
/// another one. In memory only: a new launch starts with none shown.
///
/// The app had no shared ask budget before; the prompts that existed when
/// this was added call [noteShown] where they log their `*_shown` event.
abstract final class SessionPrompts {
  static bool _shown = false;

  /// Something was shown this run.
  static bool get anyShown => _shown;

  /// Records that a prompt was shown this run.
  static void noteShown() => _shown = true;

  /// True, and records it, when nothing has been shown this run yet; false
  /// otherwise. For a prompt that wants to be the only one.
  static bool claim() {
    if (_shown) return false;
    _shown = true;
    return true;
  }

  /// Tests start each case with a fresh run.
  static void resetForTest() => _shown = false;
}
