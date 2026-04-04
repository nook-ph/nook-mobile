import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:nook/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:nook/features/profile/presentation/cubit/profile_cubit.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          ProfileCubit(client: Supabase.instance.client)..loadProfile(),
      child: BlocListener<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthAuthenticated) {
            context.read<ProfileCubit>().loadProfile();
          }

          if (state is AuthUnauthenticated) {
            context.read<ProfileCubit>().clear();
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
                child: BlocBuilder<ProfileCubit, ProfileState>(
                  builder: (context, profileState) {
                    final isAuthenticated = profileState is ProfileLoaded;
                    final name = profileState is ProfileLoaded
                        ? profileState.name
                        : 'No name';
                    final email = profileState is ProfileLoaded
                        ? profileState.email
                        : 'No email';

                    if (profileState is ProfileLoading ||
                        profileState is ProfileInitial) {
                      return const CircularProgressIndicator();
                    }

                    return Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Name: $name',
                          style: const TextStyle(fontSize: 16),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Email: $email',
                          style: const TextStyle(fontSize: 16),
                        ),
                        const SizedBox(height: 24),
                        if (isAuthenticated)
                          ElevatedButton(
                            onPressed: () {
                              context.read<AuthBloc>().add(
                                const AuthSignOutEvent(),
                              );
                            },
                            child: const Text('Logout'),
                          )
                        else
                          ElevatedButton(
                            onPressed: () => context.push('/login'),
                            child: const Text('Login'),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
