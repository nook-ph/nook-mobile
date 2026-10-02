import 'package:equatable/equatable.dart';

/// One cafe in a crawl. Stops are a snapshot taken when the crawl was made —
/// they never change afterwards (docs/COMMUNITY_CRAWLS.md §1).
class CrawlStop extends Equatable {
  final String stopId;
  final int order;
  final String cafeId;
  final String name;
  final String? neighborhood;
  final String? imageUrl;
  final double lat;
  final double lng;

  const CrawlStop({
    required this.stopId,
    required this.order,
    required this.cafeId,
    required this.name,
    this.neighborhood,
    this.imageUrl,
    required this.lat,
    required this.lng,
  });

  @override
  List<Object?> get props => [
    stopId,
    order,
    cafeId,
    name,
    neighborhood,
    imageUrl,
    lat,
    lng,
  ];
}

/// A user-made crawl: an ordered set of 3–6 cafes others can take.
class Crawl extends Equatable {
  final String id;
  final String title;
  final String? description;

  /// The public identifier used in links and typed from a story.
  final String shareCode;

  /// False = private to the creator and anyone in one of its runs.
  final bool isLinkVisible;

  /// `active` or `archived`. Removed crawls never reach the client.
  final String status;
  final bool isCreator;

  /// Null once the creator's account is gone; the crawl outlives them.
  final String? creatorUsername;
  final String? creatorAvatarUrl;
  final List<CrawlStop> stops;

  /// Aggregates only — nobody's individual activity is exposed here.
  final int runsStarted;
  final int completions;

  const Crawl({
    required this.id,
    required this.title,
    this.description,
    required this.shareCode,
    required this.isLinkVisible,
    required this.status,
    required this.isCreator,
    this.creatorUsername,
    this.creatorAvatarUrl,
    required this.stops,
    this.runsStarted = 0,
    this.completions = 0,
  });

  bool get isArchived => status == 'archived';

  /// "by @cris", or a neutral line when the creator has left.
  String get byline =>
      creatorUsername == null ? 'by a former member' : 'by @$creatorUsername';

  @override
  List<Object?> get props => [
    id,
    title,
    description,
    shareCode,
    isLinkVisible,
    status,
    isCreator,
    creatorUsername,
    creatorAvatarUrl,
    stops,
    runsStarted,
    completions,
  ];
}
