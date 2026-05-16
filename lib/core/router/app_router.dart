import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:go_router/go_router.dart';
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
    debugLogDiagnostics: true,
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
            location == '/change-password' || // ← add this
            isAuthRoute) {
          debugPrint('Redirect authenticated -> /');
          return '/';
        }
        debugPrint('No redirect (authenticated)');
        return null;
      }

      if (authState is AuthUnauthenticated || authState is AuthLoggedOut) {
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
                AppInitial() => const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
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
          return UsernameSetupScreen(
            fullName: extra?['fullName'] as String?,
            avatarUrl: extra?['avatarUrl'] as String?,
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

      GoRoute(
        path: '/search',
        builder: (context, state) {
          final query = state.uri.queryParameters['q'] ?? '';
          return SearchResultsPage(query: query);
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
