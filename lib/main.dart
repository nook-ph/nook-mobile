import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/rendering.dart';
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
import 'package:nook/features/crawl/presentation/deep_link/crawl_deep_link_handler.dart';
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
    authOptions: FlutterAuthClientOptions(authFlowType: AuthFlowType.implicit),
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
  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSubscription;
  GoRouter? _router;

  @override
  void initState() {
    super.initState();
    _initAppLinks();
  }

  Future<void> _initAppLinks() async {
    _linkSubscription = _appLinks.uriLinkStream.listen(
      _handleIncomingLink,
      onError: (Object error, StackTrace stackTrace) {
        if (kDebugMode) {
          debugPrint('App link error: $error');
        }
      },
    );

    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        _handleIncomingLink(initialUri);
      }
    } catch (error) {
      if (kDebugMode) {
        debugPrint('Failed to read initial app link: $error');
      }
    }
  }

  Future<void> _handleIncomingLink(Uri uri) async {
    final isLoginCallback =
        uri.scheme == 'ph.nook.app' && uri.host == 'login-callback';

    if (isLoginCallback) {
      try {
        await Supabase.instance.client.auth.getSessionFromUrl(uri);
      } on AuthException catch (error) {
        if (kDebugMode) {
          debugPrint('Login callback failed: ${error.message}');
        }
      } catch (error) {
        if (kDebugMode) {
          debugPrint('Login callback failed: $error');
        }
      }
      return;
    }

    if (CrawlDeepLinkHandler.canHandle(uri)) {
      final parsed = CrawlDeepLinkHandler.parse(uri);
      if (parsed != null && _router != null) {
        _router!.go('/crawl/${parsed.crawlId}/stop/${parsed.stopId}/claim');
      }
      return;
    }
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    super.dispose();
  }

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
