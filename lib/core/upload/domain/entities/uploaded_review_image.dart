import 'package:nook/core/upload/domain/entities/uploaded_file.dart';

class UploadedReviewImage extends UploadedFile {
  final int slot;
  const UploadedReviewImage({
    required super.objectKey,
    required super.publicUrl,
    required this.slot,
  });
}
