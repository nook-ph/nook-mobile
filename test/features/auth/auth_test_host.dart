import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:nook/features/auth/presentation/bloc/auth_bloc.dart';

/// Every route an auth page can send the user to, drawn as its own path so a
/// test can tell where it landed.
const _stubPaths = [
  '/',
  '/login',
  '/login-password',
  '/signup-details',
  '/email-confirmation',
  '/username-setup',
  '/forgot-password',
];

/// Hosts [page] at `/page` (stacked over `/` so it can pop) with [bloc]
/// provided, the way the app's router does.
Widget authTestHost({
  required Widget page,
  required AuthBloc bloc,
  Object? extra,
}) {
  final router = GoRouter(
    initialLocation: '/page',
    initialExtra: extra,
    routes: [
      for (final path in _stubPaths)
        GoRoute(
          path: path,
          builder: (_, _) => Scaffold(body: Text('route:$path')),
          // `/page` sits on top of `/`, so the page under test can pop.
          routes: [
            if (path == '/') GoRoute(path: 'page', builder: (_, _) => page),
          ],
        ),
    ],
  );
  return BlocProvider<AuthBloc>.value(
    value: bloc,
    child: MaterialApp.router(routerConfig: router),
  );
}
