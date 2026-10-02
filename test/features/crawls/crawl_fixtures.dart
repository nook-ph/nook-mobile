import 'package:nook/features/crawls/data/stamp_locator.dart';
import 'package:nook/features/crawls/domain/entities/crawl.dart';
import 'package:nook/features/crawls/domain/entities/crawl_run.dart';
import 'package:nook/features/crawls/domain/repositories/i_crawl_repository.dart';

CrawlStop stop(int order, {double lat = 10.33, double lng = 123.90}) =>
    CrawlStop(
      stopId: 'stop-$order',
      order: order,
      cafeId: 'cafe-$order',
      name: 'Cafe $order',
      neighborhood: 'IT Park',
      lat: lat,
      lng: lng,
    );

Crawl crawl({int stops = 3}) => Crawl(
  id: 'crawl-1',
  title: 'IT Park Study Crawl',
  shareCode: 'K7M2QX9A',
  isLinkVisible: false,
  status: 'active',
  isCreator: true,
  creatorUsername: 'cris',
  stops: [
    for (var i = 1; i <= stops; i++)
      stop(i, lat: 10.33 + i * 0.002, lng: 123.90 + (i.isEven ? 0.003 : 0.001)),
  ],
);

CrawlRun run({int stops = 3, int stamped = 0, bool withCrew = false}) {
  final base = DateTime(2026, 10, 3, 14);
  return CrawlRun(
    id: 'run-1',
    inviteCode: 'ABCDEF1234',
    crawl: crawl(stops: stops),
    members: [
      const CrewMember(userId: 'me', username: 'cris', isMe: true),
      if (withCrew) const CrewMember(userId: 'u2', username: 'mika'),
    ],
    stamps: [
      for (var i = 1; i <= stamped; i++)
        CrawlStamp(
          stopId: 'stop-$i',
          userId: 'me',
          claimedAt: base.add(Duration(minutes: 40 * (i - 1))),
        ),
    ],
  );
}

class FakeCrawlRepository implements ICrawlRepository {
  FakeCrawlRepository({this.currentRun});

  CrawlRun? currentRun;
  Object? claimError;
  Object? createError;
  Object? getRunError;
  int claimCalls = 0;
  final List<String> linkEnabledFor = [];
  List<String>? createdCafeIds;
  String? createdTitle;

  @override
  Future<CrawlRun> claimStamp({
    required String runId,
    required String stopId,
    required double lat,
    required double lng,
    double? accuracyMeters,
    String? note,
  }) async {
    claimCalls++;
    final error = claimError;
    if (error != null) throw error;
    final current = currentRun!;
    return currentRun = CrawlRun(
      id: current.id,
      inviteCode: current.inviteCode,
      crawl: current.crawl,
      members: current.members,
      stamps: [
        ...current.stamps,
        CrawlStamp(stopId: stopId, userId: 'me', claimedAt: DateTime.now()),
      ],
    );
  }

  @override
  Future<Crawl> createCrawl({
    required String title,
    String? description,
    required List<String> cafeIds,
    String? sourceListId,
  }) async {
    final error = createError;
    if (error != null) throw error;
    createdTitle = title;
    createdCafeIds = cafeIds;
    return crawl(stops: cafeIds.length);
  }

  @override
  Future<CrawlRun> getRun(String runId) async {
    final error = getRunError;
    if (error != null) throw error;
    return currentRun!;
  }

  @override
  Future<void> archiveCrawl(String crawlId) async {}

  @override
  Future<Crawl> getCrawlByCode(String shareCode) async => crawl();

  @override
  Future<MyCrawls> getMyCrawls() async => const MyCrawls();

  @override
  Future<CrawlRun> startRun(String crawlId) async => currentRun!;

  Object? updateTitleError;
  Object? reportError;
  Object? previewError;
  Object? joinError;
  Object? leaveError;
  String? updatedTitle;
  String? reportedReason;
  String? reportedDetails;
  String? joinedInviteCode;
  String? leftRunId;
  CrawlRunPreview preview = const CrawlRunPreview(
    title: 'IT Park Study Crawl',
    shareCode: 'K7M2QX9A',
    stopCount: 5,
    crewSize: 2,
    crewLimit: 8,
    starterUsername: 'cris',
  );

  @override
  Future<Crawl> updateCrawlTitle(String crawlId, String title) async {
    final error = updateTitleError;
    if (error != null) throw error;
    updatedTitle = title;
    return crawl();
  }

  @override
  Future<Crawl> enableCrawlLink(String crawlId) async {
    linkEnabledFor.add(crawlId);
    return crawl();
  }

  @override
  Future<void> reportCrawl({
    required String crawlId,
    required String reason,
    String? details,
  }) async {
    final error = reportError;
    if (error != null) throw error;
    reportedReason = reason;
    reportedDetails = details;
  }

  @override
  Future<CrawlRunPreview> getRunPreview(String inviteCode) async {
    final error = previewError;
    if (error != null) throw error;
    return preview;
  }

  @override
  Future<CrawlRun> joinRun(String inviteCode) async {
    final error = joinError;
    if (error != null) throw error;
    joinedInviteCode = inviteCode;
    return currentRun!;
  }

  @override
  Future<void> leaveRun(String runId) async {
    final error = leaveError;
    if (error != null) throw error;
    leftRunId = runId;
  }
}

class FakeStampLocator implements IStampLocator {
  Object? error;
  int calls = 0;

  @override
  Future<StampFix> currentFix() async {
    calls++;
    final e = error;
    if (e != null) throw e;
    return const StampFix(lat: 10.33, lng: 123.90, accuracyMeters: 8);
  }
}
