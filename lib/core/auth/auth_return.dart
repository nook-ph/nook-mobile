import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// Where to send someone once they finish signing in: the page they were on
/// when they opened the login screen (a cafe, a list, search results).
///
/// Every auth screen used to send a newly signed-in user to `/`, so a guest
/// who tapped Save on a cafe and made an account landed on Home and had to
/// find the cafe again (docs/ux/signup.md, finding 2). The login screen now
/// records the page under it when it opens, and [finishSignIn] goes back
/// there.
class AuthReturn {
  AuthReturn._();

  static String? _target;

  /// Remembers the page under the login screen. Called once, when the login
  /// screen opens. The tabs (`/`) are not recorded: Home is where
  /// [finishSignIn] lands anyway.
  static void rememberOrigin(GoRouter router) {
    final config = router.routerDelegate.currentConfiguration;
    final matches = config.matches;
    // Only a pushed login screen has a page under it. One reached with `go`
    // (from settings after sign-out, or back from a later auth step) keeps
    // whatever was recorded when the flow began.
    if (matches.length < 2 || matches.last is! ImperativeRouteMatch) return;
    _target = null;
    final below = matches[matches.length - 2];
    // A pushed page carries its own location; the base of the stack uses the
    // configuration's.
    final location =
        (below is ImperativeRouteMatch ? below.matches.uri : config.uri)
            .toString();
    if (location == '/' || location.startsWith('/login')) return;
    _target = location;
  }

  /// The recorded page, cleared so it is used once.
  static String? take() {
    final target = _target;
    _target = null;
    return target;
  }
}

/// Ends sign-in: Home, then the page the guest started from on top of it, so
/// Back from that page still leads Home.
void finishSignIn(BuildContext context) {
  final router = GoRouter.of(context);
  final target = AuthReturn.take();
  router.go('/');
  if (target != null) {
    // After the frame that applies `go`, so the push lands on Home's stack.
    WidgetsBinding.instance.addPostFrameCallback((_) => router.push(target));
  }
}
