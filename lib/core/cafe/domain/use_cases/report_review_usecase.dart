import 'package:nook/core/cafe/domain/repositories/i_cafe_repository.dart';

/// Files a user report against a review. The row lands in `review_reports`
/// (status `pending`) and surfaces in the nook-admin moderation queue, where a
/// superadmin acts on it within 24 hours (hide/remove + suspend the author).
///
/// Reused both by the explicit "Report review" flow and by the block flow,
/// which auto-files a report so the developer is notified of the offending
/// content (App Store UGC requirement).
class ReportReviewUseCase {
  final ICafeRepository repository;

  ReportReviewUseCase(this.repository);

  Future<void> call({
    required String reviewId,
    required String cafeId,
    required String reporterId,
    required String reasonCode,
    String? description,
  }) {
    if (reviewId.trim().isEmpty) {
      throw ArgumentError('Review id is required.');
    }
    if (cafeId.trim().isEmpty) {
      throw ArgumentError('Cafe id is required.');
    }
    if (reporterId.trim().isEmpty) {
      throw ArgumentError('Reporter id is required.');
    }
    if (reasonCode.trim().isEmpty) {
      throw ArgumentError('Reason code is required.');
    }
    return repository.reportReview(
      reviewId: reviewId,
      cafeId: cafeId,
      reporterId: reporterId,
      reasonCode: reasonCode,
      description: description,
    );
  }
}
