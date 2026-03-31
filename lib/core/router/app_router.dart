import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:go_router/go_router.dart';
import 'package:nook/core/app_bloc.dart';
import 'package:nook/core/app_state.dart';
import 'package:nook/core/presentation/pages/main_screen.dart';
import 'package:nook/features/auth/presentation/pages/email_entry_page.dart';
import 'package:nook/features/onboarding/presentation/pages/onboarding_page.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  routes: [
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
    GoRoute(
      path: '/login',
      builder: (context, state) => const EmailEntryScreen(),
    ),
  ],
);
