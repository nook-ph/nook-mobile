import 'package:nook/features/crawls/domain/entities/crawl_run.dart';
import 'package:nook/features/crawls/domain/repositories/i_crawl_repository.dart';

class ClaimCrawlStampUseCase {
  final ICrawlRepository repository;

  ClaimCrawlStampUseCase(this.repository);

  Future<CrawlRun> call({
    required String runId,
    required String stopId,
    required double lat,
    required double lng,
    double? accuracyMeters,
    String? note,
  }) {
    return repository.claimStamp(
      runId: runId,
      stopId: stopId,
      lat: lat,
      lng: lng,
      accuracyMeters: accuracyMeters,
      note: note,
    );
  }
}
