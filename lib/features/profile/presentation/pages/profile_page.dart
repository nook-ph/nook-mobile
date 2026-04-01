import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:nook/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    final name = (user?.userMetadata?['full_name'] as String?) ?? 'No name';
    final email = user?.email ?? user?.userMetadata?['email'] ?? 'No email';

    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthUnauthenticated) {
          context.go('/login');
        }

        if (state is AuthError) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text(state.message)));
        }
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Name: $name', style: const TextStyle(fontSize: 16)),
                  const SizedBox(height: 8),
                  Text('Email: $email', style: const TextStyle(fontSize: 16)),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () {
                      context.read<AuthBloc>().add(const AuthSignOutEvent());
                    },
                    child: const Text('Logout'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
