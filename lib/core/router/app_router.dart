import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:go_router/go_router.dart';
import 'package:nook/features/public_profile/presentation/pages/public_profile_page.dart';
import 'package:nook/core/app_bloc.dart';
import 'package:nook/core/app_state.dart';
import 'package:nook/core/presentation/pages/main_screen.dart';
import 'package:nook/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:nook/features/auth/presentation/pages/email_entry_page.dart';
import 'package:nook/features/auth/presentation/pages/email_confirmation_pending_page.dart';
import 'package:nook/features/auth/presentation/pages/change_email_page.dart';
import 'package:nook/features/auth/presentation/pages/change_password_page.dart';
import 'package:nook/features/auth/presentation/pages/forgot_password_page.dart';
import 'package:nook/features/auth/presentation/pages/login_page.dart';
import 'package:nook/features/auth/presentation/pages/signup_details_page.dart';
import 'package:nook/features/auth/presentation/pages/username_setup_page.dart';
import 'package:nook/features/search/presentation/pages/search_results_page.dart';
import 'package:nook/features/cafe_details/presentation/pages/cafe_details_page.dart';
import 'package:nook/features/onboarding/presentation/pages/onboarding_page.dart';

GoRouter createAppRouter(AuthBloc authBloc) {
  return GoRouter(
    initialLocation: '/',
    debugLogDiagnostics: kDebugMode,
    refreshListenable: GoRouterRefreshStream(authBloc.stream),
    redirect: (context, state) {
      final authState = authBloc.state;
      final location = state.uri.path;
      debugPrint('GoRouter redirect check: location=$location auth=$authState');

      final isAuthRoute =
          location == '/login' ||
          location == '/login-password' ||
          location == '/signup-details';

      final isProtectedRoute =
          location == '/change-email' || location == '/change-password';

      if (authState is AuthAwaitingEmailConfirmation) {
        debugPrint('Redirect -> /email-confirmation');
        return location == '/email-confirmation' ? null : '/email-confirmation';
      }

      if (authState is AuthNeedsUsername) {
        debugPrint('Redirect -> /username-setup');
        return location == '/username-setup' ? null : '/username-setup';
      }

      if (authState is AuthPasswordRecovery) {
        return location == '/change-password' ? null : '/change-password';
      }

      if (authState is AuthAuthenticated) {
        if (location == '/username-setup' ||
            location == '/email-confirmation' ||
            isAuthRoute) {
          debugPrint('Redirect authenticated -> /');
          return '/';
        }
        debugPrint('No redirect (authenticated)');
        return null;
      }

      if (authState is AuthUnauthenticated || authState is AuthLoggedOut) {
        if (isProtectedRoute) {
          debugPrint('Redirect unauthenticated from protected route -> /login');
          return '/login';
        }
        debugPrint('No redirect (unauthenticated)');
        return null;
      }

      debugPrint('No redirect (fallback)');
      return null;
    },
    routes: [
      /// 1. Root Route (Auth & Onboarding Logic)
      GoRoute(
        path: '/',
        builder: (context, state) {
          return BlocConsumer<AppBloc, AppState>(
            listener: (context, state) {
              if (state is! AppInitial) {
                FlutterNativeSplash.remove();
              }
            },
            builder: (context, state) {
              return switch (state) {
                ShowOnboarding() => const OnboardingPage(),
                ShowHome() => const MainScreen(),
                // Logo with a small spinner while the session is checked,
                // so the hand-off from the native splash is not a bare
                // spinner on white.
                AppInitial() => Scaffold(
                  backgroundColor: Colors.white,
                  body: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Figma: the wordmark sits in a 79.2 x 44 box and
                        // fills its width.
                        SizedBox(
                          width: 79.2,
                          height: 44,
                          child: Image.asset(
                            'assets/logos/logoT.png',
                            fit: BoxFit.contain,
                            cacheWidth:
                                (79.2 * MediaQuery.devicePixelRatioOf(context))
                                    .ceil(),
                          ),
                        ),
                        const SizedBox(height: 20),
                        const SizedBox.square(
                          dimension: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Color(0xFF344E41),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              };
            },
          );
        },
      ),

      /// 2. Authentication Routes
      GoRoute(
        path: '/login',
        builder: (context, state) => const EmailEntryScreen(),
      ),

      GoRoute(
        path: '/login-password',
        builder: (context, state) {
          final email = state.extra as String? ?? '';
          return LoginPasswordScreen(email: email);
        },
      ),

      GoRoute(
        path: '/change-email',
        builder: (context, state) {
          final email = state.extra as String?;
          return ChangeEmailScreen(currentEmail: email);
        },
      ),

      GoRoute(
        path: '/change-password',
        builder: (context, state) => const ChangePasswordScreen(),
      ),

      GoRoute(
        path: '/forgot-password',
        builder: (context, state) => const ForgotPasswordScreen(),
      ),

      GoRoute(
        path: '/signup-details',
        builder: (context, state) {
          final email = state.extra as String? ?? '';
          return SignupDetailsScreen(email: email);
        },
      ),

      GoRoute(
        path: '/email-confirmation',
        builder: (context, state) => const EmailConfirmationPendingScreen(),
      ),

      GoRoute(
        path: '/username-setup',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          // The redirect after the email code carries no extra, so fall back
          // to the auth state: it holds the name typed at sign-up, which the
          // screen turns into a suggested username instead of a blank field.
          final auth = authBloc.state;
          final needs = auth is AuthNeedsUsername ? auth : null;
          return UsernameSetupScreen(
            fullName: extra?['fullName'] as String? ?? needs?.fullName,
            avatarUrl: extra?['avatarUrl'] as String? ?? needs?.avatarUrl,
          );
        },
      ),

      /// 3. Cafe Details (Deep Link Target)
      GoRoute(
        path: '/cafe/:id',
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          return CafeDetailsPage(cafeId: id);
        },
      ),

      /// A person's public profile; the web's `/u/<username>`.
      GoRoute(
        path: '/u/:username',
        builder: (context, state) =>
            PublicProfilePage(username: state.pathParameters['username']),
      ),

      GoRoute(
        path: '/search',
        builder: (context, state) {
          final query = state.uri.queryParameters['q'] ?? '';
          // A Home shelf's "See all" opens the full list in its order.
          final sort = state.uri.queryParameters['sort'];
          return SearchResultsPage(query: query, sort: sort);
        },
      ),
    ],
  );
}

class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    _subscription = stream.listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
