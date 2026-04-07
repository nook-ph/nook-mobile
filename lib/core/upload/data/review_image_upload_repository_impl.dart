import 'dart:io';

import 'package:nook/core/upload/data/review_image_upload_remote_data_source.dart';
import 'package:nook/core/upload/domain/entities/uploaded_review_image.dart';
import 'package:nook/core/upload/domain/repositories/i_review_image_upload_repository.dart';

class ReviewImageUploadRepositoryImpl implements IReviewImageUploadRepository {
  final ReviewImageUploadRemoteDataSource remoteDataSource;

  ReviewImageUploadRepositoryImpl(this.remoteDataSource);

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
}
