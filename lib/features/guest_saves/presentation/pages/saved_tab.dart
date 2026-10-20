import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nook/core/bloc/features/navigation/bloc/navigation_bloc.dart';
import 'package:nook/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:nook/features/guest_saves/presentation/pages/guest_saved_page.dart';
import 'package:nook/features/lists/presentation/pages/list_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;

/// The Saved tab: the account's lists when signed in, the saves kept on
/// this phone otherwise. Switches the moment the session changes.
class SavedTab extends StatelessWidget {
  const SavedTab({super.key});

  static bool _signedIn() =>
      Supabase.instance.client.auth.currentSession != null;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      buildWhen: (previous, current) =>
          current is AuthAuthenticated ||
          current is AuthLoggedOut ||
          current is AuthUnauthenticated ||
          current is AuthAccountDeleted,
      builder: (context, _) {
        if (_signedIn()) return const ListsPage(showBackButton: false);
        return GuestSavedPage(
          onBrowse: () =>
              context.read<NavigationBloc>().add(TabChange(tabIndex: 0)),
        );
      },
    );
  }
}
