// lib/core/upload/data/upload_repository_impl.dart

import 'dart:io';
import 'package:nook/core/upload/data/upload_remove_data_source.dart';
import 'package:nook/core/upload/domain/entities/uploaded_avatar.dart';
import 'package:nook/core/upload/domain/entities/uploaded_review_image.dart';
import 'package:nook/core/upload/domain/repositories/i_review_image_upload_repository.dart';

class UploadRepositoryImpl implements IUploadRepository {
  final UploadRemoteDataSource remoteDataSource;
  const UploadRepositoryImpl(this.remoteDataSource);

  @override
  Future<List<UploadedReviewImage>> uploadReviewImages({
    required String cafeId,
    required String userId,
    required List<File> images,
    String? accessToken,
  }) {
    return remoteDataSource.uploadReviewImages(
      cafeId: cafeId,
      userId: userId,
      images: images,
      accessToken: accessToken,
    );
  }

  @override
  Future<UploadedAvatar> uploadAvatar({
    required File file,
    String? accessToken,
  }) {
    return remoteDataSource.uploadAvatar(file: file, accessToken: accessToken);
  }
}
