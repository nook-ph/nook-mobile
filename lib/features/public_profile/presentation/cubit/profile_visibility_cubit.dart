import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nook/features/public_profile/domain/i_public_profile_repository.dart';

enum ProfileVisibilityStatus { initial, loading, loaded, failed }

class ProfileVisibilityState extends Equatable {
  const ProfileVisibilityState({
    this.status = ProfileVisibilityStatus.initial,
    this.highlightsPublic = true,
  });

  final ProfileVisibilityStatus status;

  /// "Show my top cafes and gallery on my profile". On until read: it is
  /// the server default.
  final bool highlightsPublic;

  @override
  List<Object?> get props => [status, highlightsPublic];
}

/// The signed-in person's profile switch, shared by Settings and the
/// profile's "visitors see" hint so both say the same thing.
class ProfileVisibilityCubit extends Cubit<ProfileVisibilityState> {
  ProfileVisibilityCubit({required IPublicProfileRepository repository})
    : _repository = repository,
      super(const ProfileVisibilityState());

  final IPublicProfileRepository _repository;

  Future<void> load() async {
    if (state.status == ProfileVisibilityStatus.loading) return;
    emit(
      ProfileVisibilityState(
        status: ProfileVisibilityStatus.loading,
        highlightsPublic: state.highlightsPublic,
      ),
    );
    try {
      final value = await _repository.getMyHighlightsPublic();
      if (isClosed) return;
      emit(
        ProfileVisibilityState(
          status: ProfileVisibilityStatus.loaded,
          highlightsPublic: value,
        ),
      );
    } catch (_) {
      if (isClosed) return;
      emit(
        ProfileVisibilityState(
          status: ProfileVisibilityStatus.failed,
          highlightsPublic: state.highlightsPublic,
        ),
      );
    }
  }

  /// Flips the switch at once and goes back if the save fails. Returns
  /// false on failure so the caller can say so.
  Future<bool> setHighlightsPublic(bool value) async {
    final before = state;
    emit(
      ProfileVisibilityState(
        status: ProfileVisibilityStatus.loaded,
        highlightsPublic: value,
      ),
    );
    try {
      await _repository.setMyHighlightsPublic(value);
      return true;
    } catch (_) {
      if (!isClosed) emit(before);
      return false;
    }
  }

  /// Signed out: back to the default.
  void clear() => emit(const ProfileVisibilityState());
}
