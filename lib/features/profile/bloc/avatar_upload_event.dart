import 'dart:io';

abstract class AvatarUploadEvent {
  const AvatarUploadEvent();
}

class SubmitAvatarRequested extends AvatarUploadEvent {
  final File file;
  final String? accessToken;

  const SubmitAvatarRequested({
    required this.file,
    this.accessToken,
  });
}