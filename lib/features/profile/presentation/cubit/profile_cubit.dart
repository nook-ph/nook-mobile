import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nook/core/cafe/domain/entities/cafe_details.dart';
import 'package:nook/core/cafe/domain/use_cases/delete_review_usecase.dart';
import 'package:nook/core/cafe/domain/use_cases/get_reviews_written_by_user_usecase.dart';
import 'package:nook/features/profile/presentation/profile_logic.dart';
import 'package:nook/features/profile/use_cases/update_profile_usecase.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileCubit extends Cubit<ProfileState> {
  final SupabaseClient _client;
  final GetReviewsWrittenByUserUseCase _getReviewsWrittenByUser;
  final UpdateProfileUseCase _updateProfileUseCase;
  final DeleteReviewUseCase _deleteReviewUseCase;

  ProfileCubit({
    SupabaseClient? client,
    required GetReviewsWrittenByUserUseCase getReviewsWrittenByUser,
    required UpdateProfileUseCase updateProfileUseCase,
    required DeleteReviewUseCase deleteReviewUseCase,
  }) : _client = client ?? Supabase.instance.client,
       _getReviewsWrittenByUser = getReviewsWrittenByUser,
       _updateProfileUseCase = updateProfileUseCase,
       _deleteReviewUseCase = deleteReviewUseCase,
       super(const ProfileInitial());

  /// With [refresh], a profile already loaded for the signed-in user stays on
  /// screen while the new one is fetched, and stays if the fetch fails.
  Future<void> loadProfile({bool refresh = false}) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      emit(const ProfileUnauthenticated());
      return;
    }

    final current = state;
    final keepShown =
        refresh && current is ProfileLoaded && current.userId == user.id;
    if (!keepShown) emit(const ProfileLoading());

    try {
      final profileFuture = _client
          .from('profiles')
          // No `email`: it comes from the session, so this read keeps
          // working once that column stops being readable by other users.
          .select('full_name,username,bio,avatar_url,last_username_change')
          .eq('id', user.id)
          .maybeSingle();

      // A failed reviews read must not take the profile down with it, but it
      // is not "no reviews" either: the state says which it was.
      var reviewsFailed = false;
      final reviewsFuture = _getReviewsWrittenByUser(user.id).catchError((
        Object error,
        StackTrace stackTrace,
      ) {
        reviewsFailed = true;
        return <WrittenReview>[];
      });

      final outcomes = await Future.wait<dynamic>([
        profileFuture,
        reviewsFuture,
      ]);
      if (isClosed) return;

      final row = outcomes[0];
      final reviews = outcomes[1] as List<WrittenReview>;

      final map = row is Map<String, dynamic> ? row : const <String, dynamic>{};

      final name =
          (map['full_name'] as String?) ??
          (user.userMetadata?['full_name'] as String?) ??
          noNamePlaceholder;

      final username =
          (map['username'] as String?) ??
          (user.userMetadata?['username'] as String?) ??
          '';

      final email =
          user.email ?? (user.userMetadata?['email'] as String?) ?? 'No email';

      final bio = (map['bio'] as String?) ?? '';
      final avatarUrl = map['avatar_url'] as String?;

      final rawLastChange = map['last_username_change'] as String?;
      final lastUsernameChange = rawLastChange != null
          ? DateTime.tryParse(rawLastChange)
          : null;

      emit(
        ProfileLoaded(
          name: name,
          username: username,
          email: email,
          bio: bio,
          userId: user.id,
          avatarUrl: avatarUrl,
          lastUsernameChange: lastUsernameChange,
          reviews: reviews,
          reviewsFailed: reviewsFailed,
        ),
      );
    } catch (e) {
      if (isClosed || keepShown) return;
      emit(ProfileError(e));
    }
  }

  Future<void> editProfile({
    String? name,
    String? username,
    String? bio,
    String? avatarUrl,
  }) async {
    final currentState = state;

    if (currentState is! ProfileLoaded) return;

    // "No name" is what the page shows for an empty full_name; it and an
    // emptied field are never written.
    final trimmedName = name?.trim() ?? '';
    name = trimmedName.isEmpty || trimmedName == noNamePlaceholder
        ? null
        : trimmedName;

    try {
      await _updateProfileUseCase.call(
        userId: currentState.userId,
        name: name,
        username: username,
        bio: bio,
        avatarUrl: avatarUrl,
      );
      if (isClosed) return;

      final newLastChange = username != null
          ? DateTime.now()
          : currentState.lastUsernameChange;

      emit(
        ProfileLoaded(
          name: name ?? currentState.name,
          username: username ?? currentState.username,
          bio: bio ?? currentState.bio,
          avatarUrl: avatarUrl ?? currentState.avatarUrl,
          email: currentState.email,
          userId: currentState.userId,
          lastUsernameChange: newLastChange,
          reviews: currentState.reviews,
          reviewsFailed: currentState.reviewsFailed,
        ),
      );
    } catch (e) {
      rethrow;
    }
  }

  void clear() {
    emit(const ProfileUnauthenticated());
  }

  Future<void> deleteReview(String reviewId) async {
    final currentState = state;
    if (currentState is! ProfileLoaded) return;

    try {
      await _deleteReviewUseCase.call(reviewId);
    } catch (e) {
      rethrow;
    }
    if (isClosed) return;

    final updatedReviews = currentState.reviews
        .where((r) => r.id != reviewId)
        .toList(growable: false);

    if (updatedReviews.length == currentState.reviews.length) return;

    emit(
      ProfileLoaded(
        name: currentState.name,
        username: currentState.username,
        email: currentState.email,
        bio: currentState.bio,
        userId: currentState.userId,
        avatarUrl: currentState.avatarUrl,
        lastUsernameChange: currentState.lastUsernameChange,
        reviews: updatedReviews,
      ),
    );
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
  final String username;
  final String email;
  final String bio;
  final String userId;
  final String? avatarUrl;
  final DateTime? lastUsernameChange;
  final List<WrittenReview> reviews;

  /// The reviews could not be read: [reviews] is empty because of that, not
  /// because the user has written none.
  final bool reviewsFailed;

  const ProfileLoaded({
    required this.name,
    required this.username,
    required this.email,
    required this.bio,
    required this.userId,
    this.avatarUrl,
    this.lastUsernameChange,
    this.reviews = const [],
    this.reviewsFailed = false,
  });

  @override
  List<Object?> get props => [
    name,
    username,
    email,
    bio,
    userId,
    avatarUrl,
    lastUsernameChange,
    reviews,
    reviewsFailed,
  ];
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
