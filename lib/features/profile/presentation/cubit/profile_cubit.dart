import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nook/core/cafe/domain/entities/cafe_details.dart';
import 'package:nook/core/cafe/domain/use_cases/get_reviews_written_by_user_usecase.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileCubit extends Cubit<ProfileState> {
  final SupabaseClient _client;
  final GetReviewsWrittenByUserUseCase _getReviewsWrittenByUser;

  ProfileCubit({
    SupabaseClient? client,
    required GetReviewsWrittenByUserUseCase getReviewsWrittenByUser,
  }) : _client = client ?? Supabase.instance.client,
       _getReviewsWrittenByUser = getReviewsWrittenByUser,
       super(const ProfileInitial());

  Future<void> loadProfile() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      emit(const ProfileUnauthenticated());
      return;
    }

    emit(const ProfileLoading());

    try {
      final profileFuture = _client
          .from('profiles')
          .select('full_name,email,username')
          .eq('id', user.id)
          .maybeSingle();

      final reviewsFuture = _getReviewsWrittenByUser(user.id).catchError(
        (Object error, StackTrace stackTrace) => <WrittenReview>[],
      );

      final outcomes = await Future.wait<dynamic>([
        profileFuture,
        reviewsFuture,
      ]);

      final row = outcomes[0];
      final reviews = outcomes[1] as List<WrittenReview>;

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

      emit(
        ProfileLoaded(
          name: name,
          email: email,
          userId: user.id,
          reviews: reviews,
        ),
      );
    } catch (e) {
      emit(ProfileError(e));
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
  final List<WrittenReview> reviews;

  const ProfileLoaded({
    required this.name,
    required this.email,
    required this.userId,
    this.reviews = const [],
  });

  @override
  List<Object?> get props => [name, email, userId, reviews];
}

class ProfileError extends ProfileState {
  final Object error;

  const ProfileError(this.error);

  @override
  List<Object?> get props => [error];
}

class ProfileUnauthenticated extends ProfileState {
  const ProfileUnauthenticated();
}
