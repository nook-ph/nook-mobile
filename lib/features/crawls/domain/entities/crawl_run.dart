import 'package:equatable/equatable.dart';
import 'package:nook/features/crawls/domain/entities/crawl.dart';

class CrewMember extends Equatable {
  final String userId;
  final String? username;
  final String? avatarUrl;
  final DateTime? completedAt;
  final bool isMe;

  const CrewMember({
    required this.userId,
    this.username,
    this.avatarUrl,
    this.completedAt,
    this.isMe = false,
  });

  String get initial {
    final name = username?.trim() ?? '';
    return name.isEmpty ? '?' : name[0].toUpperCase();
  }

  @override
  List<Object?> get props => [userId, username, avatarUrl, completedAt, isMe];
}

class CrawlStamp extends Equatable {
  final String stopId;
  final String userId;
  final DateTime claimedAt;

  const CrawlStamp({
    required this.stopId,
    required this.userId,
    required this.claimedAt,
  });

  @override
  List<Object?> get props => [stopId, userId, claimedAt];
}

/// One attempt at a crawl by a crew. A solo run is a crew of one.
class CrawlRun extends Equatable {
  final String id;
  final String inviteCode;
  final DateTime? plannedFor;
  final Crawl crawl;
  final List<CrewMember> members;
  final List<CrawlStamp> stamps;

  const CrawlRun({
    required this.id,
    required this.inviteCode,
    this.plannedFor,
    required this.crawl,
    required this.members,
    required this.stamps,
  });

  CrewMember? get me {
    for (final member in members) {
      if (member.isMe) return member;
    }
    return null;
  }

  /// The caller's own stamps, oldest first.
  List<CrawlStamp> get myStamps {
    final id = me?.userId;
    if (id == null) return const [];
    return stamps.where((s) => s.userId == id).toList()
      ..sort((a, b) => a.claimedAt.compareTo(b.claimedAt));
  }

  Set<String> get myStampedStopIds => myStamps.map((s) => s.stopId).toSet();

  int get myStampCount => myStampedStopIds.length;

  bool get isComplete =>
      crawl.stops.isNotEmpty && myStampCount >= crawl.stops.length;

  CrawlStamp? myStampFor(String stopId) {
    for (final stamp in myStamps) {
      if (stamp.stopId == stopId) return stamp;
    }
    return null;
  }

  /// How many of the crew have stamped [stopId].
  int crewStampCount(String stopId) => stamps
      .where((s) => s.stopId == stopId)
      .map((s) => s.userId)
      .toSet()
      .length;

  /// The first stop the caller has not stamped yet, in crawl order.
  CrawlStop? get nextStop {
    final done = myStampedStopIds;
    for (final stop in crawl.stops) {
      if (!done.contains(stop.stopId)) return stop;
    }
    return null;
  }

  @override
  List<Object?> get props => [
    id,
    inviteCode,
    plannedFor,
    crawl,
    members,
    stamps,
  ];
}

/// A run as listed on the Lists tab — enough to show progress and resume.
class CrawlRunSummary extends Equatable {
  final String runId;
  final String title;
  final String shareCode;
  final int stopCount;
  final int myStamps;
  final String? creatorUsername;
  final DateTime? completedAt;
  final List<CrewMember> crew;

  const CrawlRunSummary({
    required this.runId,
    required this.title,
    required this.shareCode,
    required this.stopCount,
    required this.myStamps,
    this.creatorUsername,
    this.completedAt,
    this.crew = const [],
  });

  bool get isComplete => completedAt != null;

  @override
  List<Object?> get props => [
    runId,
    title,
    shareCode,
    stopCount,
    myStamps,
    creatorUsername,
    completedAt,
    crew,
  ];
}

/// What an invite link shows before the caller joins: enough to decide, and
/// nothing about individuals beyond who started the run.
class CrawlRunPreview extends Equatable {
  final String title;
  final String shareCode;
  final int stopCount;
  final DateTime? plannedFor;
  final int crewSize;
  final int crewLimit;
  final String? starterUsername;
  final String? starterAvatarUrl;

  const CrawlRunPreview({
    required this.title,
    required this.shareCode,
    required this.stopCount,
    this.plannedFor,
    required this.crewSize,
    required this.crewLimit,
    this.starterUsername,
    this.starterAvatarUrl,
  });

  bool get isFull => crewLimit > 0 && crewSize >= crewLimit;

  @override
  List<Object?> get props => [
    title,
    shareCode,
    stopCount,
    plannedFor,
    crewSize,
    crewLimit,
    starterUsername,
    starterAvatarUrl,
  ];
}

class MyCrawls extends Equatable {
  final List<Crawl> created;
  final List<CrawlRunSummary> runs;

  const MyCrawls({this.created = const [], this.runs = const []});

  bool get isEmpty => created.isEmpty && runs.isEmpty;

  @override
  List<Object?> get props => [created, runs];
}
