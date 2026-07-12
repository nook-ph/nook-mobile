import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:go_router/go_router.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:nook/utils/theme/theme.dart';
import 'package:nook/core/app_bloc.dart';
import 'package:nook/core/app_event.dart';
import 'package:nook/core/auth/google_auth_state.dart';
import 'package:nook/core/block/block_cubit.dart';
import 'package:nook/core/constants/app_constants.dart';
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

  await GoogleSignIn.instance.initialize(
    serverClientId: AppConstants.googleServerClientId,
    nonce: _googleSignInNonce(),
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

String _googleSignInNonce() {
  final random = Random.secure();
  final rawNonceBytes = List<int>.generate(32, (_) => random.nextInt(256));
  final rawNonce = base64Url.encode(rawNonceBytes).replaceAll('=', '');
  final nonceDigest = sha256.convert(utf8.encode(rawNonce)).toString();

  GoogleAuthState.nonce = rawNonce;
  debugPrint(
    'GoogleAuth: rawNonce[0..8]=${rawNonce.substring(0, rawNonce.length.clamp(0, 8))}… '
    'nonceDigest[0..8]=${nonceDigest.substring(0, nonceDigest.length.clamp(0, 8))}…',
  );
  return nonceDigest;
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
        BlocProvider<BlockCubit>(create: (_) => sl<BlockCubit>()),
        BlocProvider<AuthBloc>(
          create: (context) =>
              AuthInjection.createAuthBloc(listsBloc: context.read<ListsBloc>())
                ..add(const AuthSessionCheckEvent()),
        ),
      ],
      child: Builder(
        builder: (context) {
          _router ??= createAppRouter(context.read<AuthBloc>());

          // Keep the app-wide blocked-users cache in sync with the session so
          // blocked authors are filtered out of feeds immediately.
          return BlocListener<AuthBloc, AuthState>(
            listenWhen: (previous, current) =>
                current is AuthAuthenticated ||
                current is AuthLoggedOut ||
                current is AuthUnauthenticated ||
                current is AuthAccountDeleted,
            listener: (context, state) {
              final blockCubit = context.read<BlockCubit>();
              if (state is AuthAuthenticated) {
                blockCubit.load();
              } else {
                blockCubit.clear();
              }
            },
            child: MaterialApp.router(
              debugShowCheckedModeBanner: false,
              title: 'Nook',
              theme: TAppTheme.lightTheme,
              routerConfig: _router,
              builder: (context, child) => child ?? const SizedBox.shrink(),
            ),
          );
        },
      ),
    );
  }
}
