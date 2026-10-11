import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nook/features/cups/domain/entities/cup.dart';
import 'package:nook/features/cups/domain/i_cups_repository.dart';

enum ProfileCupsStatus { initial, loading, loaded, failed }

class ProfileCupsState extends Equatable {
  const ProfileCupsState({
    this.status = ProfileCupsStatus.initial,
    this.cups,
    this.error,
  });

  final ProfileCupsStatus status;

  /// Null before the first load, and when the profile can't be shown.
  final ProfileCups? cups;
  final Object? error;

  List<ProfileCafeCups> get cafes => cups?.cafes ?? const [];

  @override
  List<Object?> get props => [status, cups, error];
}

/// One person's Cups grid (`get_profile_cups`, or their reviews and photos
/// on the legacy backend).
class ProfileCupsCubit extends Cubit<ProfileCupsState> {
  ProfileCupsCubit({
    required ICupsRepository repository,
    this.userId,
    this.username,
  }) : assert(userId != null || username != null),
       _read = (() =>
           repository.getProfileCups(userId: userId, username: username)),
       super(const ProfileCupsState());

  /// Reads through [read] instead of a repository: a profile whose cups
  /// are already in hand (tests, a screen without the Cups backend).
  ProfileCupsCubit.from(Future<ProfileCups?> Function() read)
    : _read = read,
      userId = null,
      username = null,
      super(const ProfileCupsState());

  final Future<ProfileCups?> Function() _read;
  final String? userId;
  final String? username;

  int _epoch = 0;

  Future<void> load({bool refresh = false}) async {
    final epoch = ++_epoch;
    if (!refresh || state.status != ProfileCupsStatus.loaded) {
      emit(const ProfileCupsState(status: ProfileCupsStatus.loading));
    }
    try {
      final cups = await _read();
      if (isClosed || epoch != _epoch) return;
      emit(ProfileCupsState(status: ProfileCupsStatus.loaded, cups: cups));
    } catch (e) {
      debugPrint('[ProfileCups] load failed: $e');
      if (isClosed || epoch != _epoch) return;
      if (refresh && state.status == ProfileCupsStatus.loaded) return;
      emit(ProfileCupsState(status: ProfileCupsStatus.failed, error: e));
    }
  }
}
