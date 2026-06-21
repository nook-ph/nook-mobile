import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:go_router/go_router.dart';
import 'package:nook/utils/theme/theme.dart';
import 'package:nook/core/app_bloc.dart';
import 'package:nook/core/app_event.dart';
import 'package:nook/core/app_state.dart';
import 'package:nook/core/filters/cubit/filter_cubit.dart';
import 'package:nook/core/router/app_router.dart';
import 'package:nook/features/auth/auth_injection.dart';
import 'package:nook/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:nook/features/lists/bloc/lists_bloc.dart';
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
    authOptions: FlutterAuthClientOptions(authFlowType: AuthFlowType.pkce),
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

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  GoRouter? _router;

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<AppBloc>(
          create: (context) => AppBloc()..add(AppStarted()),
        ),
        BlocProvider<ListsBloc>(create: (_) => sl<ListsBloc>()),
        BlocProvider<FilterCubit>(create: (_) => sl<FilterCubit>()),
        BlocProvider<AuthBloc>(
          create: (context) =>
              AuthInjection.createAuthBloc(listsBloc: context.read<ListsBloc>())
                ..add(const AuthSessionCheckEvent()),
        ),
      ],
      child: Builder(
        builder: (context) {
          _router ??= createAppRouter(context.read<AuthBloc>());

          return MaterialApp.router(
            debugShowCheckedModeBanner: false,
            title: 'Nook',
            theme: TAppTheme.lightTheme,
            routerConfig: _router,
            builder: (context, child) => child ?? const SizedBox.shrink(),
          );
        },
      ),
    );
  }
}
