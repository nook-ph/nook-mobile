import 'package:nook/features/cafe_details/presentation/widgets/cafe_guest_sign_in_sheet.dart';

/// The cafe action a guest tapped before they were asked to sign in, so the
/// cafe page can finish it once they are back signed in (Save, Been, Want to
/// try, Write a review). Sign-in already returns them to the cafe
/// ([finishSignIn]); without this they then had to tap the same thing again.
///
/// One pending action at a time, used once, and only for a short while: a
/// guest who gave up on signing in and came back to the cafe much later
/// should not see it act on its own.
class GuestActionReplay {
  GuestActionReplay._();

  /// The actions that are replayed. Report and Helpful act on one review and
  /// stay a tap away.
  static const replayable = {
    CafeGuestAction.been,
    CafeGuestAction.wantToTry,
    CafeGuestAction.saveToList,
    CafeGuestAction.writeReview,
  };

  static const maxAge = Duration(minutes: 30);

  static ({CafeGuestAction action, String cafeId, DateTime at})? _pending;

  /// Overridable clock for tests.
  static DateTime Function() now = DateTime.now;

  /// Called when the guest chooses to sign in from the action's sheet.
  static void remember(CafeGuestAction action, String cafeId) {
    if (!replayable.contains(action) || cafeId.isEmpty) return;
    _pending = (action: action, cafeId: cafeId, at: now());
  }

  /// True, once, when [action] on [cafeId] is waiting and still fresh.
  /// Any pending action for another cafe or action is left alone.
  static bool take(CafeGuestAction action, String cafeId) {
    final p = _pending;
    if (p == null || p.action != action || p.cafeId != cafeId) return false;
    _pending = null;
    return now().difference(p.at) <= maxAge;
  }

  /// The pending action for [cafeId] among [actions], taken; null if none.
  static CafeGuestAction? takeAny(
    Iterable<CafeGuestAction> actions,
    String cafeId,
  ) {
    for (final a in actions) {
      if (take(a, cafeId)) return a;
    }
    return null;
  }

  /// Sign-out, or the guest dismissed sign-in for good.
  static void clear() => _pending = null;
}
