import 'package:nook/features/crawls/data/crawl_models.dart';
import 'package:nook/features/crawls/domain/entities/crawl.dart';
import 'package:nook/features/crawls/domain/entities/crawl_exception.dart';
import 'package:nook/features/crawls/domain/entities/crawl_run.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// One method per community-crawl RPC. The server raises stable message
/// tokens (with the number the UI needs in `details`); [mapError] turns the
/// ones the UI has copy for into [CrawlException]s and lets the rest through.
class CrawlRemoteDataSource {
  final SupabaseClient supabase;

  CrawlRemoteDataSource(this.supabase);

  Future<MyCrawls> getMyCrawls() async {
    final json = await _rpc('get_my_community_crawls');
    return CrawlModels.myCrawls(json as Map<String, dynamic>);
  }

  Future<Crawl> getCrawlByCode(String shareCode) async {
    final json = await _rpc(
      'get_community_crawl',
      params: {'p_share_code': shareCode},
    );
    // Null covers private, removed, blocked and never-existed alike.
    if (json == null) throw const CrawlNotFound();
    return CrawlModels.crawl(json as Map<String, dynamic>);
  }

  Future<Crawl> createCrawl({
    required String title,
    String? description,
    required List<String> cafeIds,
    String? sourceListId,
  }) async {
    final json = await _rpc(
      'create_community_crawl',
      params: {
        'p_title': title,
        'p_description': description,
        'p_cafe_ids': cafeIds,
        'p_source_list_id': sourceListId,
      },
    );
    return CrawlModels.crawl(json as Map<String, dynamic>);
  }

  Future<void> archiveCrawl(String crawlId) async {
    await _rpc('archive_community_crawl', params: {'p_crawl_id': crawlId});
  }

  /// Stops are fixed once a crawl exists; only the title is editable here.
  Future<Crawl> updateCrawlTitle(String crawlId, String title) async {
    final json = await _rpc(
      'update_community_crawl',
      params: {'p_crawl_id': crawlId, 'p_title': title},
    );
    return CrawlModels.crawl(json as Map<String, dynamic>);
  }

  /// Makes a crawl readable by anyone holding its link or code. Creator only.
  Future<Crawl> enableCrawlLink(String crawlId) async {
    final json = await _rpc(
      'update_community_crawl',
      params: {'p_crawl_id': crawlId, 'p_visibility': 'link'},
    );
    return CrawlModels.crawl(json as Map<String, dynamic>);
  }

  /// One report per person per crawl; a repeat is silently ignored server-side.
  Future<void> reportCrawl({
    required String crawlId,
    required String reason,
    String? details,
  }) async {
    await _rpc(
      'report_community_crawl',
      params: {'p_crawl_id': crawlId, 'p_reason': reason, 'p_details': details},
    );
  }

  /// Callable signed out. Null covers removed, blocked and never-existed.
  Future<CrawlRunPreview> getRunPreview(String inviteCode) async {
    final json = await _rpc(
      'get_community_crawl_run_preview',
      params: {'p_invite_code': inviteCode},
    );
    if (json == null) throw const CrawlNotFound();
    return CrawlModels.runPreview(json as Map<String, dynamic>);
  }

  /// Idempotent: joining a run you are already in returns it.
  Future<CrawlRun> joinRun(String inviteCode) async {
    final json = await _rpc(
      'join_community_crawl_run',
      params: {'p_invite_code': inviteCode},
    );
    return CrawlModels.run(json as Map<String, dynamic>);
  }

  /// Drops the caller's stamps for the run along with their membership.
  Future<void> leaveRun(String runId) async {
    await _rpc('leave_community_crawl_run', params: {'p_run_id': runId});
  }

  Future<CrawlRun> startRun(String crawlId) async {
    final json = await _rpc(
      'start_community_crawl_run',
      params: {'p_crawl_id': crawlId},
    );
    return CrawlModels.run(json as Map<String, dynamic>);
  }

  Future<CrawlRun> getRun(String runId) async {
    final json = await _rpc(
      'get_community_crawl_run',
      params: {'p_run_id': runId},
    );
    return CrawlModels.run(json as Map<String, dynamic>);
  }

  Future<CrawlRun> claimStamp({
    required String runId,
    required String stopId,
    required double lat,
    required double lng,
    double? accuracyMeters,
    String? note,
  }) async {
    final json = await _rpc(
      'claim_community_crawl_stamp',
      params: {
        'p_run_id': runId,
        'p_stop_id': stopId,
        'p_lat': lat,
        'p_lng': lng,
        'p_accuracy': accuracyMeters,
        'p_note': note,
      },
    );
    return CrawlModels.run(json as Map<String, dynamic>);
  }

  Future<dynamic> _rpc(String name, {Map<String, dynamic>? params}) async {
    try {
      return await supabase.rpc(name, params: params);
    } on PostgrestException catch (e) {
      final mapped = mapError(e);
      if (mapped != null) throw mapped;
      rethrow;
    }
  }

  /// Null means "not one of ours" — the caller rethrows the original.
  static CrawlException? mapError(PostgrestException e) {
    final number = int.tryParse('${e.details ?? ''}'.trim()) ?? 0;
    final token = e.message.trim();

    return switch (token) {
      'stamp_too_far' => StampTooFar(number),
      'stamp_too_soon' => StampTooSoon(number),
      'stamp_low_accuracy' => StampLowAccuracy(number),
      'crew_full' => const CrewFull(),
      'crawl_rate_limited' => const CrawlRateLimited(),
      'crawl_not_found' ||
      'run_not_found' ||
      'stop_not_found' => const CrawlNotFound(),
      _ when token.startsWith('crawl_') => CrawlInvalid(token),
      _ => null,
    };
  }
}
