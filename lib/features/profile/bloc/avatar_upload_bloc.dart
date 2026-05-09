import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nook/core/upload/domain/use_cases/upload_use_case.dart';
import 'package:nook/features/profile/bloc/avatar_upload_event.dart';
import 'package:nook/features/profile/bloc/avatar_upload_state.dart';
import 'package:nook/features/profile/use_cases/update_profile_usecase.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AvatarUploadBloc extends Bloc<AvatarUploadEvent, AvatarUploadState> {
  AvatarUploadBloc({
    required this.uploadAvatarUseCase,
    required this.updateProfileAvatarUseCase,
  }) : super(const AvatarUploadInitial()) {
    on<SubmitAvatarRequested>(_onSubmitAvatarRequested);
  }

  final UploadAvatarUseCase uploadAvatarUseCase;
  final UpdateProfileUseCase updateProfileAvatarUseCase;

  Future<void> _onSubmitAvatarRequested(
    SubmitAvatarRequested event,
    Emitter<AvatarUploadState> emit,
  ) async {
    emit(const AvatarUploading());

    try {
      // Step A: Upload to Storage Bucket
      final uploadedAvatar =
          await uploadAvatarUseCase(
            file: event.file,
            accessToken: event.accessToken,
          ).timeout(
            const Duration(seconds: 15),
            onTimeout: () => throw TimeoutException('Avatar upload timed out.'),
          );

      // Step B: Get the currently logged-in user's ID
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('unauthenticated');
      }


      await updateProfileAvatarUseCase(
        userId: userId,
        avatarUrl: uploadedAvatar.publicUrl,
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw TimeoutException('Profile update timed out.'),
      );

      // Step D: Success!
      emit(AvatarUploadSuccess(avatar: uploadedAvatar));
    } catch (e) {
      emit(AvatarUploadError(_mapErrorMessage(e)));
    }
  }

  String _mapErrorMessage(Object error) {
    final message = error.toString().toLowerCase();

    if (message.contains('permission') ||
        message.contains('401') ||
        message.contains('unauthenticated')) {
      return 'Please sign in to update your avatar.';
    }
    if (message.contains('upload') || message.contains('s3')) {
      return 'Image upload failed. Please try again.';
    }
    if (error is TimeoutException || message.contains('timed out')) {
      return 'Upload timed out. Please check your connection and try again.';
    }

    return 'Unable to update your avatar right now. Please try again.';
  }
}
