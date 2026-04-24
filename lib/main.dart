import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:nook/core/app_bloc.dart';
import 'package:nook/core/app_event.dart';
import 'package:nook/core/app_state.dart';
import 'package:nook/core/router/app_router.dart';
import 'package:nook/features/auth/auth_injection.dart';
import 'package:nook/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:nook/features/favorites/bloc/favorites_bloc.dart';
import 'package:nook/features/favorites/bloc/favorites_events.dart';
import 'package:nook/injection_container.dart';
import 'package:posthog_flutter/posthog_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;

void main() async {
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  await dotenv.load(fileName: ".env");

  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_KEY']!,
  );

  final posthogToken = dotenv.env['POSTHOG_PROJECT_TOKEN']?.trim() ?? '';
  if (posthogToken.isNotEmpty) {
    final config = PostHogConfig(posthogToken)
      ..host = dotenv.env['POSTHOG_HOST']?.trim() ?? 'https://us.i.posthog.com'
      ..debug = kDebugMode;

    await Posthog().setup(config);
  } else {
    debugPrint('PostHog setup skipped: missing POSTHOG_PROJECT_TOKEN in .env');
  }

  await initDependencies();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<AppBloc>(
          create: (context) => AppBloc()..add(AppStarted()),
        ),
        BlocProvider<AuthBloc>(
          create: (context) =>
              AuthInjection.createAuthBloc()
                ..add(const AuthSessionCheckEvent()),
        ),
        BlocProvider<FavoritesBloc>(
          create: (_) => sl<FavoritesBloc>()..add(LoadFavoritesEvent()),
        ),
      ],
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        title: 'Nook',
        routerConfig: appRouter,
        builder: (context, child) {
          return BlocListener<AuthBloc, AuthState>(
            listenWhen: (previous, current) {
              return current is AuthAuthenticated || current is AuthLoggedOut;
            },
            listener: (context, state) {
              final appState = context.read<AppBloc>().state;
              if (appState is! ShowHome) {
                return;
              }

              if (state is AuthAuthenticated) {
                appRouter.go('/');
                context.read<FavoritesBloc>().add(
                  LoadFavoritesEvent(userId: state.user.id),
                );
              } else if (state is AuthLoggedOut) {
                appRouter.go('/login');
                context.read<FavoritesBloc>().add(LoadFavoritesEvent());
              }
            },
            child: child ?? const SizedBox.shrink(),
          );
        },
      ),
    );
  }
}
