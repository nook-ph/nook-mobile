import 'package:nook/features/crawls/domain/entities/crawl.dart';
import 'package:nook/features/crawls/domain/entities/crawl_run.dart';

/// Community crawls. Every write goes through a server RPC; the client never
/// touches the tables directly (docs/COMMUNITY_CRAWLS.md §3).
abstract class ICrawlRepository {
  /// Crawls the caller made and runs the caller is in.
  Future<MyCrawls> getMyCrawls();

  /// Looks a crawl up by its share code. Throws `CrawlNotFound` when it is
  /// private, removed, blocked, or never existed.
  Future<Crawl> getCrawlByCode(String shareCode);

  /// [cafeIds] in stop order, 3–6 of them.
  Future<Crawl> createCrawl({
    required String title,
    String? description,
    required List<String> cafeIds,
    String? sourceListId,
  });

  Future<void> archiveCrawl(String crawlId);

  /// Creator only. Stops never change after a crawl is made.
  Future<Crawl> updateCrawlTitle(String crawlId, String title);

  /// Creator only. Lets anyone with the link or code open the crawl; a crawl
  /// is private until its creator first shares it.
  Future<Crawl> enableCrawlLink(String crawlId);

  /// One report per person per crawl; repeats are ignored by the server.
  Future<void> reportCrawl({
    required String crawlId,
    required String reason,
    String? details,
  });

  /// What an invite link shows before joining. Works signed out. Throws
  /// `CrawlNotFound` when the run is gone or hidden from the caller.
  Future<CrawlRunPreview> getRunPreview(String inviteCode);

  /// Throws `CrewFull` at eight members, `CrawlNotFound` when the run is gone.
  Future<CrawlRun> joinRun(String inviteCode);

  /// Leaving removes the caller's stamps for that run.
  Future<void> leaveRun(String runId);

  Future<CrawlRun> startRun(String crawlId);

  Future<CrawlRun> getRun(String runId);

  /// Claims a stamp. The server decides whether the position counts; failures
  /// arrive as `StampTooFar` / `StampTooSoon` / `StampLowAccuracy`.
  Future<CrawlRun> claimStamp({
    required String runId,
    required String stopId,
    required double lat,
    required double lng,
    double? accuracyMeters,
    String? note,
  });
}
