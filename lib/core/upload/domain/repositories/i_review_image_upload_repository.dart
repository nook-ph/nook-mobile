import 'dart:io';
import 'package:nook/core/upload/domain/entities/uploaded_avatar.dart';
import 'package:nook/core/upload/domain/entities/uploaded_review_image.dart';

abstract interface class IUploadRepository {
  Future<List<UploadedReviewImage>> uploadReviewImages({
    required String cafeId,
    required String userId,
    required List<File> images,
    String? accessToken,
  });

  Future<UploadedAvatar> uploadAvatar({
    required File file,
    String? accessToken,
  });
}
