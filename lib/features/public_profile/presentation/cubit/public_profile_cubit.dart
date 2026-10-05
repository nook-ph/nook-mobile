import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nook/features/public_profile/domain/entities/public_profile.dart';
import 'package:nook/features/public_profile/domain/i_public_profile_repository.dart';

enum PublicProfileStatus { loading, loaded, notFound, failed }

class PublicProfileState extends Equatable {
  const PublicProfileState({
    this.status = PublicProfileStatus.loading,
    this.profile,
  });

  final PublicProfileStatus status;
  final PublicProfile? profile;

  @override
  List<Object?> get props => [status, profile];
}

/// One visitor screen's profile. Per screen, not app-wide: two profiles can
/// be on the navigation stack at once.
class PublicProfileCubit extends Cubit<PublicProfileState> {
  PublicProfileCubit({
    required IPublicProfileRepository repository,
    this.username,
    this.userId,
  }) : assert(username != null || userId != null),
       _repository = repository,
       super(const PublicProfileState());

  final IPublicProfileRepository _repository;
  final String? username;
  final String? userId;

  Future<void> load() async {
    if (state.status != PublicProfileStatus.loading) {
      emit(const PublicProfileState());
    }
    try {
      final profile = await _repository.getProfile(
        username: username,
        userId: userId,
      );
      if (isClosed) return;
      emit(
        profile == null
            ? const PublicProfileState(status: PublicProfileStatus.notFound)
            : PublicProfileState(
                status: PublicProfileStatus.loaded,
                profile: profile,
              ),
      );
    } catch (_) {
      if (isClosed) return;
      emit(const PublicProfileState(status: PublicProfileStatus.failed));
    }
  }
}
