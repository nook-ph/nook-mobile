import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:go_router/go_router.dart';
import 'package:nook/core/app_bloc.dart';
import 'package:nook/core/app_state.dart';
import 'package:nook/core/presentation/pages/main_screen.dart';
import 'package:nook/features/auth/presentation/pages/email_entry_page.dart';
import 'package:nook/features/auth/presentation/pages/login_page.dart';
import 'package:nook/features/auth/presentation/pages/signup_details_page.dart';
import 'package:nook/features/search/presentation/pages/search_results_page.dart';
import 'package:nook/features/cafe_details/presentation/pages/cafe_details_page.dart';
import 'package:nook/features/onboarding/presentation/pages/onboarding_page.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  // This helps you see navigation errors in the terminal
  debugLogDiagnostics: true,
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
      path: '/signup-details',
      builder: (context, state) {
        final email = state.extra as String? ?? '';
        return SignupDetailsScreen(email: email);
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
        return const SearchResultsPage(query: '');
      },
    ),
  ],
);
