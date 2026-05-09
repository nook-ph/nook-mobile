import 'package:nook/core/upload/domain/entities/uploaded_avatar.dart';

abstract class AvatarUploadState {
  const AvatarUploadState();
}

class AvatarUploadInitial extends AvatarUploadState {
  const AvatarUploadInitial();
}

class AvatarUploading extends AvatarUploadState {
  const AvatarUploading();
}

class AvatarUploadSuccess extends AvatarUploadState {
  final UploadedAvatar avatar;

  const AvatarUploadSuccess({required this.avatar});
}

class AvatarUploadError extends AvatarUploadState {
  final String message;

  const AvatarUploadError(this.message);
}