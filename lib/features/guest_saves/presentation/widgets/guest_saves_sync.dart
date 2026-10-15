import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nook/core/cafe/presentation/cafe_status_cubit.dart';
import 'package:nook/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:nook/features/guest_saves/presentation/cubit/guest_saves_cubit.dart';
import 'package:nook/features/guest_saves/presentation/cubit/recently_viewed_cubit.dart';
import 'package:nook/features/guest_saves/presentation/guest_saves_merger.dart';
import 'package:nook/features/lists/bloc/lists_bloc.dart';
import 'package:nook/features/lists/bloc/lists_event.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;

/// Keeps a guest's on-phone saves in step with the session, app-wide:
///
/// - while signed out, they are the statuses every badge and pill shows;
/// - on sign-in (and on any launch that is signed in with saves left over
///   from a failed attempt) they are moved to the account, in the
///   background: signing in never waits for it.
///
/// Sits under `main.dart`'s providers, below the listener that resets the
/// status cache on sign-out, so its own work lands after that reset.
class GuestSavesSync extends StatefulWidget {
  const GuestSavesSync({super.key, required this.child, this.isSignedIn});

  final Widget child;

  /// Defaults to the Supabase session; tests pass their own.
  final bool Function()? isSignedIn;

  @override
  State<GuestSavesSync> createState() => _GuestSavesSyncState();
}

class _GuestSavesSyncState extends State<GuestSavesSync> {
  late final GuestSavesMerger _merger = GuestSavesMerger(
    saves: context.read<GuestSavesCubit>(),
    statuses: context.read<CafeStatusCubit>(),
  );

  bool get _signedIn =>
      widget.isSignedIn?.call() ??
      Supabase.instance.client.auth.currentSession != null;

  @override
  void initState() {
    super.initState();
    unawaited(context.read<RecentlyViewedCubit>().load());
    final saves = context.read<GuestSavesCubit>();
    unawaited(
      saves.load().then((_) {
        if (!mounted) return;
        if (_signedIn) {
          _merge();
        } else {
          _mirror();
        }
      }),
    );
  }

  void _mirror() {
    if (!mounted || _signedIn) return;
    context.read<CafeStatusCubit>().showLocal(
      context.read<GuestSavesCubit>().state.statusMap,
    );
  }

  Future<void> _merge() async {
    final lists = context.read<ListsBloc>();
    final merged = await _merger.merge();
    // Saved-tab counts and previews come from the lists.
    if (merged > 0 && mounted) lists.add(LoadUserLists());
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<AuthBloc, AuthState>(
          listenWhen: (previous, current) =>
              current is AuthAuthenticated && previous is! AuthAuthenticated,
          listener: (_, _) => unawaited(_merge()),
        ),
        BlocListener<AuthBloc, AuthState>(
          listenWhen: (_, current) =>
              current is AuthLoggedOut ||
              current is AuthUnauthenticated ||
              current is AuthAccountDeleted,
          listener: (context, state) {
            if (state is AuthLoggedOut || state is AuthAccountDeleted) {
              context.read<RecentlyViewedCubit>().clear();
            }
            // After the app's own listener has reset the status cache.
            scheduleMicrotask(_mirror);
          },
        ),
        BlocListener<GuestSavesCubit, GuestSavesState>(
          listener: (_, _) => _mirror(),
        ),
      ],
      child: widget.child,
    );
  }
}
