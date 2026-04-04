import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileCubit extends Cubit<ProfileState> {
  final SupabaseClient _client;

  ProfileCubit({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client,
      super(const ProfileInitial());

  Future<void> loadProfile() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      emit(const ProfileUnauthenticated());
      return;
    }

    emit(const ProfileLoading());

    try {
      final row = await _client
          .from('profiles')
          .select('full_name,email,username')
          .eq('id', user.id)
          .maybeSingle();

      final map = row is Map<String, dynamic> ? row : const <String, dynamic>{};
      final name =
          (map['full_name'] as String?) ??
          (map['username'] as String?) ??
          (user.userMetadata?['full_name'] as String?) ??
          'No name';
      final email =
          (map['email'] as String?) ??
          user.email ??
          (user.userMetadata?['email'] as String?) ??
          'No email';

      emit(ProfileLoaded(name: name, email: email, userId: user.id));
    } catch (_) {
      final name =
          (user.userMetadata?['full_name'] as String?) ??
          (user.userMetadata?['name'] as String?) ??
          'No name';
      final email =
          user.email ?? (user.userMetadata?['email'] as String?) ?? 'No email';

      emit(ProfileLoaded(name: name, email: email, userId: user.id));
    }
  }

  void clear() {
    emit(const ProfileUnauthenticated());
  }
}

abstract class ProfileState extends Equatable {
  const ProfileState();

  @override
  List<Object?> get props => [];
}

class ProfileInitial extends ProfileState {
  const ProfileInitial();
}

class ProfileLoading extends ProfileState {
  const ProfileLoading();
}

class ProfileLoaded extends ProfileState {
  final String name;
  final String email;
  final String userId;

  const ProfileLoaded({
    required this.name,
    required this.email,
    required this.userId,
  });

  @override
  List<Object?> get props => [name, email, userId];
}

class ProfileUnauthenticated extends ProfileState {
  const ProfileUnauthenticated();
}
