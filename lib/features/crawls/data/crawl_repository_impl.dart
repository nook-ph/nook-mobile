import 'package:nook/features/crawls/data/crawl_remote_data_source.dart';
import 'package:nook/features/crawls/domain/entities/crawl.dart';
import 'package:nook/features/crawls/domain/entities/crawl_run.dart';
import 'package:nook/features/crawls/domain/repositories/i_crawl_repository.dart';

class CrawlRepositoryImpl implements ICrawlRepository {
  final CrawlRemoteDataSource remoteDataSource;

  CrawlRepositoryImpl(this.remoteDataSource);

  @override
  Future<MyCrawls> getMyCrawls() => remoteDataSource.getMyCrawls();

  @override
  Future<Crawl> getCrawlByCode(String shareCode) =>
      remoteDataSource.getCrawlByCode(shareCode);

  @override
  Future<Crawl> createCrawl({
    required String title,
    String? description,
    required List<String> cafeIds,
    String? sourceListId,
  }) => remoteDataSource.createCrawl(
    title: title,
    description: description,
    cafeIds: cafeIds,
    sourceListId: sourceListId,
  );

  @override
  Future<void> archiveCrawl(String crawlId) =>
      remoteDataSource.archiveCrawl(crawlId);

  @override
  Future<Crawl> updateCrawlTitle(String crawlId, String title) =>
      remoteDataSource.updateCrawlTitle(crawlId, title);

  @override
  Future<Crawl> enableCrawlLink(String crawlId) =>
      remoteDataSource.enableCrawlLink(crawlId);

  @override
  Future<void> reportCrawl({
    required String crawlId,
    required String reason,
    String? details,
  }) => remoteDataSource.reportCrawl(
    crawlId: crawlId,
    reason: reason,
    details: details,
  );

  @override
  Future<CrawlRunPreview> getRunPreview(String inviteCode) =>
      remoteDataSource.getRunPreview(inviteCode);

  @override
  Future<CrawlRun> joinRun(String inviteCode) =>
      remoteDataSource.joinRun(inviteCode);

  @override
  Future<void> leaveRun(String runId) => remoteDataSource.leaveRun(runId);

  @override
  Future<CrawlRun> startRun(String crawlId) =>
      remoteDataSource.startRun(crawlId);

  @override
  Future<CrawlRun> getRun(String runId) => remoteDataSource.getRun(runId);

  @override
  Future<CrawlRun> claimStamp({
    required String runId,
    required String stopId,
    required double lat,
    required double lng,
    double? accuracyMeters,
    String? note,
  }) => remoteDataSource.claimStamp(
    runId: runId,
    stopId: stopId,
    lat: lat,
    lng: lng,
    accuracyMeters: accuracyMeters,
    note: note,
  );
}
