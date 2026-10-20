import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:nook/core/analytics/auth_events.dart';
import 'package:nook/core/analytics/log_app_event.dart';
import 'package:nook/core/auth/auth_return.dart';
import 'package:nook/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:nook/features/cafe_details/presentation/guest_action_replay.dart';
import 'package:nook/features/auth/presentation/widgets/auth_ui.dart';
import 'package:nook/features/auth/presentation/widgets/sign_in_choices.dart';

/// Acts on what a guest picked in a sign-in sheet, from the page that opened
/// it ([context]); the sheet is already closed.
///
/// - Email opens `/login`, as the sheets always did.
/// - Google or Apple signs in where the guest is. A new account goes on to
///   the username step (the router sends it there); either way the guest
///   then comes back to this page through [finishSignIn], which also lets a
///   cafe page finish the Save or Been they tapped ([GuestActionReplay]).
///
/// [beforeSignIn] runs just before either path starts, for the caller to
/// remember what to finish afterwards.
Future<void> continueSignInFromSheet(
  BuildContext context,
  SignInChoice? choice, {
  VoidCallback? beforeSignIn,
}) async {
  if (choice == null || !context.mounted) return;

  AuthBloc? bloc;
  if (choice != SignInChoice.email) {
    try {
      bloc = context.read<AuthBloc>();
    } on ProviderNotFoundException {
      bloc = null;
    }
  }

  beforeSignIn?.call();
  final router = GoRouter.of(context);
  // A page pushed straight on the Navigator (a cafe opened from a card) is
  // not in the router's stack: going Home and back would pop it and push
  // whatever the router last knew, a different page. An in-place sign-in
  // stays on it instead. The email and username steps leave through the
  // router and lose it, so what it would have finished on reopening is
  // dropped rather than left to fire on a later visit.
  final route = ModalRoute.of(context);
  final outsideRouter = route != null && route.settings is! Page;
  if (bloc == null) {
    if (outsideRouter) GuestActionReplay.clear();
    router.push('/login');
    return;
  }

  AuthReturn.rememberCurrent(router);
  bloc.add(
    choice == SignInChoice.apple
        ? const AuthSignInWithAppleEvent(surface: AuthSurface.sheet)
        : const AuthSignInWithGoogleEvent(surface: AuthSurface.sheet),
  );

  final AuthState outcome;
  try {
    outcome = await bloc.stream.firstWhere(
      (s) =>
          s is AuthAuthenticated ||
          s is AuthNeedsUsername ||
          s is AuthUnauthenticated ||
          s is AuthError,
    );
  } on StateError {
    return; // The bloc closed.
  }

  switch (outcome) {
    case AuthAuthenticated():
      if (!outsideRouter || !route.isActive) {
        finishSignInWith(router);
      } else {
        AuthReturn.take();
        logAppEvent(
          'sign_in_finished',
          properties: {'returned_to_origin': true},
        );
        // The page under the sheet is not built again, so an action it
        // would have finished on opening (Save, a review) is not replayed:
        // drop it rather than let it fire on a later visit. The guest taps
        // it again, signed in.
        GuestActionReplay.clear();
      }
    case AuthNeedsUsername():
      // The router holds the account on /username-setup, which finishes
      // with [finishSignIn] and so returns here (or, from a page outside
      // the router, to the router's last page).
      if (outsideRouter) GuestActionReplay.clear();
    case AuthError(:final message):
      AuthReturn.take();
      // Nothing to finish: a later sign-in from elsewhere must not replay it.
      GuestActionReplay.clear();
      final shown = router.routerDelegate.navigatorKey.currentContext;
      if (shown != null && shown.mounted) showAuthToast(shown, message);
    default:
      // The provider sheet was closed: nothing to return to or finish.
      AuthReturn.take();
      GuestActionReplay.clear();
  }
}
