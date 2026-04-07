import 'dart:io';

import 'package:nook/core/upload/domain/entities/uploaded_review_image.dart';

abstract class IReviewImageUploadRepository {
  Future<List<UploadedReviewImage>> uploadReviewImages({
    required String cafeId,
    required String userId,
    required List<File> images,
    String? accessToken,
  });
}
