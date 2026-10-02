import 'package:nook/features/crawls/domain/entities/crawl.dart';
import 'package:nook/features/crawls/domain/entities/crawl_run.dart';

/// JSON → entity mapping for the community-crawl RPCs. The shapes are built
/// server-side by `_community_crawl_json` / `_community_crawl_run_json`.
class CrawlModels {
  const CrawlModels._();

  static Crawl crawl(Map<String, dynamic> json) {
    final creator = json['creator'] as Map<String, dynamic>?;
    final stops =
        (json['stops'] as List<dynamic>? ?? const [])
            .map((s) => _stop(s as Map<String, dynamic>))
            .toList()
          ..sort((a, b) => a.order.compareTo(b.order));

    return Crawl(
      id: json['id'] as String,
      title: json['title'] as String? ?? '',
      description: json['description'] as String?,
      shareCode: json['share_code'] as String? ?? '',
      isLinkVisible: json['visibility'] == 'link',
      status: json['status'] as String? ?? 'active',
      isCreator: json['is_creator'] as bool? ?? false,
      creatorUsername: creator?['username'] as String?,
      creatorAvatarUrl: creator?['avatar_url'] as String?,
      stops: stops,
      runsStarted: _int(json['runs_started']),
      completions: _int(json['completions']),
    );
  }

  static CrawlRun run(Map<String, dynamic> json) {
    return CrawlRun(
      id: json['run_id'] as String,
      inviteCode: json['invite_code'] as String? ?? '',
      plannedFor: _date(json['planned_for']),
      crawl: crawl(json['crawl'] as Map<String, dynamic>),
      members: (json['members'] as List<dynamic>? ?? const [])
          .map((m) => _member(m as Map<String, dynamic>))
          .toList(),
      stamps: (json['stamps'] as List<dynamic>? ?? const [])
          .map((s) => _stamp(s as Map<String, dynamic>))
          .toList(),
    );
  }

  static CrawlRunPreview runPreview(Map<String, dynamic> json) {
    return CrawlRunPreview(
      title: json['title'] as String? ?? '',
      shareCode: json['share_code'] as String? ?? '',
      stopCount: _int(json['stop_count']),
      plannedFor: _date(json['planned_for']),
      crewSize: _int(json['crew_size']),
      crewLimit: _int(json['crew_limit']),
      starterUsername: json['starter_username'] as String?,
      starterAvatarUrl: json['starter_avatar_url'] as String?,
    );
  }

  static MyCrawls myCrawls(Map<String, dynamic> json) {
    return MyCrawls(
      created: (json['created'] as List<dynamic>? ?? const [])
          .map((c) => crawl(c as Map<String, dynamic>))
          .toList(),
      runs: (json['runs'] as List<dynamic>? ?? const [])
          .map((r) => _runSummary(r as Map<String, dynamic>))
          .toList(),
    );
  }

  static CrawlStop _stop(Map<String, dynamic> json) {
    return CrawlStop(
      stopId: json['stop_id'] as String,
      order: _int(json['stop_order']),
      cafeId: json['cafe_id'] as String,
      name: json['name'] as String? ?? '',
      neighborhood: (json['neighborhood'] as String?)?.trim(),
      imageUrl: json['featured_image_url'] as String?,
      lat: _double(json['lat']),
      lng: _double(json['lng']),
    );
  }

  static CrewMember _member(Map<String, dynamic> json) {
    return CrewMember(
      userId: json['user_id'] as String? ?? '',
      username: json['username'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      completedAt: _date(json['completed_at']),
      isMe: json['is_me'] as bool? ?? false,
    );
  }

  static CrawlStamp _stamp(Map<String, dynamic> json) {
    return CrawlStamp(
      stopId: json['stop_id'] as String,
      userId: json['user_id'] as String,
      claimedAt: _date(json['claimed_at']) ?? DateTime.now(),
    );
  }

  static CrawlRunSummary _runSummary(Map<String, dynamic> json) {
    return CrawlRunSummary(
      runId: json['run_id'] as String,
      title: json['title'] as String? ?? '',
      shareCode: json['share_code'] as String? ?? '',
      stopCount: _int(json['stop_count']),
      myStamps: _int(json['my_stamps']),
      creatorUsername: json['creator_username'] as String?,
      completedAt: _date(json['completed_at']),
      crew: (json['crew'] as List<dynamic>? ?? const [])
          .map((m) => _member(m as Map<String, dynamic>))
          .toList(),
    );
  }

  static int _int(Object? value) => (value as num?)?.toInt() ?? 0;

  static double _double(Object? value) => (value as num?)?.toDouble() ?? 0;

  static DateTime? _date(Object? value) =>
      value is String ? DateTime.tryParse(value)?.toLocal() : null;
}
