import 'package:nook/features/crawls/domain/repositories/i_crawl_repository.dart';

class ReportCrawlUseCase {
  final ICrawlRepository repository;

  ReportCrawlUseCase(this.repository);

  /// The server caps a reason at 50 characters and details at 500.
  static const maxDetailsLength = 500;

  Future<void> call({
    required String crawlId,
    required String reason,
    String? details,
  }) {
    final trimmed = details?.trim() ?? '';
    return repository.reportCrawl(
      crawlId: crawlId,
      reason: reason,
      details: trimmed.isEmpty ? null : trimmed,
    );
  }
}
