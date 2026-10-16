import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:nook/core/analytics/auth_events.dart';
import 'package:nook/core/analytics/log_app_event.dart';
import 'package:nook/core/auth/auth_return.dart';
import 'package:nook/features/auth/presentation/bloc/auth_bloc.dart';
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
  if (bloc == null) {
    router.push('/login');
    return;
  }

  // A page pushed straight on the Navigator (a cafe opened from a card) is
  // not in the router's stack: going Home and back would pop it and push
  // whatever the router last knew, a different page. The guest is already
  // on the right page, so stay there instead.
  final route = ModalRoute.of(context);
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
      if (route == null || route.settings is Page || !route.isActive) {
        finishSignInWith(router);
      } else {
        AuthReturn.take();
        logAppEvent(
          'sign_in_finished',
          properties: {'returned_to_origin': true},
        );
      }
    case AuthNeedsUsername():
      // The router holds the account on /username-setup, which finishes
      // with [finishSignIn] and so returns here.
      break;
    case AuthError(:final message):
      AuthReturn.take();
      final shown = router.routerDelegate.navigatorKey.currentContext;
      if (shown != null && shown.mounted) showAuthToast(shown, message);
    default:
      // The provider sheet was closed: nothing to return to.
      AuthReturn.take();
  }
}
