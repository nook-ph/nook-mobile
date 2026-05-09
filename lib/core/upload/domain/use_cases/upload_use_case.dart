import 'dart:io';
import 'package:nook/core/upload/domain/entities/uploaded_avatar.dart';
import 'package:nook/core/upload/domain/entities/uploaded_review_image.dart';
import 'package:nook/core/upload/domain/repositories/i_review_image_upload_repository.dart';


class UploadReviewImagesUseCase {
  final IUploadRepository repository;
  const UploadReviewImagesUseCase(this.repository);

  Future<List<UploadedReviewImage>> call({
    required String cafeId,
    required String userId,
    required List<File> images,
    String? accessToken,
  }) {
    if (cafeId.trim().isEmpty) throw ArgumentError('Cafe id is required.');
    if (userId.trim().isEmpty) throw ArgumentError('User id is required.');
    if (images.length > 3) throw ArgumentError('You can upload up to 3 images.');

    return repository.uploadReviewImages(
      cafeId: cafeId,
      userId: userId,
      images: images,
      accessToken: accessToken,
    );
  }
}

class UploadAvatarUseCase {
  final IUploadRepository repository;
  const UploadAvatarUseCase(this.repository);

  Future<UploadedAvatar> call({
    required File file,
    String? accessToken,
  }) {
    return repository.uploadAvatar(file: file, accessToken: accessToken);
  }
}