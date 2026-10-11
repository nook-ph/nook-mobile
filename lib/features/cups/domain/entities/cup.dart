import 'dart:io';

import 'package:equatable/equatable.dart';

/// The longest note on a cup (`cups.note`).
const maxCupNote = 1000;

/// The most items (photos or named things) one cup holds.
const maxCupItems = 10;

/// The longest item name ("Iced Spanish latte").
const maxCupItemName = 60;

/// What an item in a cup is. A cup is a visit; what you had can be coffee,
/// another drink, food, or the place itself.
enum CupItemKind {
  coffee('coffee', 'Coffee'),
  drink('drink', 'Drink'),
  food('food', 'Food'),
  space('space', 'Space');

  const CupItemKind(this.wire, this.label);

  final String wire;
  final String label;

  static CupItemKind? fromWire(Object? value) {
    for (final kind in values) {
      if (kind.wire == value) return kind;
    }
    return null;
  }
}

/// One thing in a cup: a photo, a named item ("Spanish latte"), or both.
class CupItem extends Equatable {
  const CupItem({
    required this.id,
    this.kind,
    this.name,
    this.menuItemId,
    this.imageUrl,
    this.takenAt,
    this.caption,
    this.source,
    this.sourceId,
    this.objectKey,
  });

  final String id;

  /// Null on legacy photos, which never said.
  final CupItemKind? kind;
  final String? name;

  /// Picked from the cafe's menu.
  final String? menuItemId;

  /// Null for a text-only item.
  final String? imageUrl;
  final DateTime? takenAt;
  final String? caption;

  /// Legacy `user_photos.source` (rank, review, gallery) when known.
  final String? source;

  /// The review a legacy review photo came from.
  final String? sourceId;
  final String? objectKey;

  bool get hasPhoto => (imageUrl ?? '').isNotEmpty;

  String? get label {
    final n = name?.trim();
    return n == null || n.isEmpty ? null : n;
  }

  /// Review photos are managed through their review on the legacy backend.
  bool get isFromReview => source == 'review';

  @override
  List<Object?> get props => [
    id,
    kind,
    name,
    menuItemId,
    imageUrl,
    takenAt,
    caption,
    source,
    sourceId,
    objectKey,
  ];
}

/// One cup: one person's visit to a cafe. Photos and named items, an
/// optional note and optional stars (nook-supabase docs/CUPS_APPLY.md).
/// On the legacy backend a review is one cup, and loose gallery photos
/// make one cup per person, cafe and day.
class CupCard extends Equatable {
  const CupCard({
    required this.id,
    required this.userId,
    required this.username,
    required this.visitedAt,
    this.cupId,
    this.reviewId,
    this.cafeId,
    this.fullName,
    this.avatarUrl,
    this.rating,
    this.note,
    this.helpfulCount = 0,
    this.hasVoted = false,
    this.isMine = false,
    this.items = const [],
    this.visitsByAuthor = 1,
  });

  /// Stable within a list: the cup id, the review id, or the legacy
  /// person + day key.
  final String id;

  /// Set for a real cup: edit, helpful and report go through the cup RPCs.
  final String? cupId;

  /// Set for a legacy review shown as a cup.
  final String? reviewId;
  final String? cafeId;
  final String userId;

  /// Without the @. May be empty for an unfinished account.
  final String username;
  final String? fullName;
  final String? avatarUrl;

  /// 1 to 5, or null: stars are optional.
  final int? rating;
  final String? note;
  final int helpfulCount;
  final bool hasVoted;
  final bool isMine;
  final DateTime visitedAt;
  final List<CupItem> items;

  /// How many cups this person has at the cafe ("3rd visit").
  final int visitsByAuthor;

  List<CupItem> get photos => [
    for (final i in items)
      if (i.hasPhoto) i,
  ];

  /// Named items without a photo ("Banana bread").
  List<CupItem> get textItems => [
    for (final i in items)
      if (!i.hasPhoto && i.label != null) i,
  ];

  bool get hasNote => (note?.trim() ?? '').isNotEmpty;
  bool get hasPhotos => items.any((i) => i.hasPhoto);
  bool get canVote => cupId != null || reviewId != null;

  /// Only real cups and legacy reviews can be edited as a whole; a legacy
  /// photo group is edited photo by photo.
  bool get isLegacyPhotos => cupId == null && reviewId == null;

  /// "@sai", or "You" on your own.
  String get label {
    if (isMine) return 'You';
    final name = username.trim();
    if (name.isNotEmpty) return '@$name';
    final full = fullName?.trim() ?? '';
    return full.isEmpty ? 'Someone' : full;
  }

  CupCard copyWith({int? helpfulCount, bool? hasVoted}) => CupCard(
    id: id,
    cupId: cupId,
    reviewId: reviewId,
    cafeId: cafeId,
    userId: userId,
    username: username,
    fullName: fullName,
    avatarUrl: avatarUrl,
    rating: rating,
    note: note,
    helpfulCount: helpfulCount ?? this.helpfulCount,
    hasVoted: hasVoted ?? this.hasVoted,
    isMine: isMine,
    visitedAt: visitedAt,
    items: items,
    visitsByAuthor: visitsByAuthor,
  );

  @override
  List<Object?> get props => [
    id,
    cupId,
    reviewId,
    cafeId,
    userId,
    username,
    fullName,
    avatarUrl,
    rating,
    note,
    helpfulCount,
    hasVoted,
    isMine,
    visitedAt,
    items,
    visitsByAuthor,
  ];
}

/// A cafe's cup numbers. Each person counts once in [rating] (their latest
/// rated cup), so a regular can't outvote everyone.
class CupStats extends Equatable {
  const CupStats({
    this.cupCount = 0,
    this.peopleCount = 0,
    this.photoCount = 0,
    this.ratedCount = 0,
    this.rating,
    this.kindCounts = const {},
  });

  /// Cups, which are visits.
  final int cupCount;
  final int peopleCount;
  final int photoCount;

  /// People with a rating.
  final int ratedCount;

  /// Null when nobody rated.
  final double? rating;

  /// Items per kind, for the filter chips.
  final Map<CupItemKind, int> kindCounts;

  bool get hasRatings => ratedCount > 0 && rating != null;

  /// Works out the numbers from every card of a cafe (the legacy path).
  factory CupStats.fromCards(List<CupCard> cards) {
    final latestRated = <String, CupCard>{};
    for (final c in cards) {
      if (c.rating == null) continue;
      final seen = latestRated[c.userId];
      if (seen == null || c.visitedAt.isAfter(seen.visitedAt)) {
        latestRated[c.userId] = c;
      }
    }
    final ratings = [for (final c in latestRated.values) c.rating!];
    final kinds = <CupItemKind, int>{};
    for (final c in cards) {
      for (final i in c.items) {
        final kind = i.kind;
        if (kind != null) kinds[kind] = (kinds[kind] ?? 0) + 1;
      }
    }
    return CupStats(
      cupCount: cards.length,
      peopleCount: {for (final c in cards) c.userId}.length,
      photoCount: cards.fold(0, (n, c) => n + c.photos.length),
      ratedCount: ratings.length,
      rating: ratings.isEmpty
          ? null
          : (ratings.reduce((a, b) => a + b) / ratings.length * 10)
                    .roundToDouble() /
                10,
      kindCounts: kinds,
    );
  }

  @override
  List<Object?> get props => [
    cupCount,
    peopleCount,
    photoCount,
    ratedCount,
    rating,
    kindCounts,
  ];
}

/// One page of a cafe's cups with the section's numbers.
class CafeCups extends Equatable {
  const CafeCups({
    required this.cafeId,
    required this.stats,
    required this.cards,
    required this.total,
    required this.hasMore,
  });

  final String cafeId;
  final CupStats stats;
  final List<CupCard> cards;

  /// Every cup matching the filters, not only this page.
  final int total;
  final bool hasMore;

  @override
  List<Object?> get props => [cafeId, stats, cards, total, hasMore];
}

/// How the cups list is ordered (`get_cafe_cups` `p_sort`).
enum CupSort {
  recommended('recommended', 'Recommended'),
  recent('recent', 'Newest'),
  highest('highest', 'Highest rated'),
  helpful('helpful', 'Most helpful');

  const CupSort(this.wire, this.label);

  final String wire;
  final String label;
}

/// One item being added to a cup: a new photo from the device, or a name
/// only.
class CupItemDraft extends Equatable {
  const CupItemDraft({
    this.file,
    this.takenAt,
    this.kind = CupItemKind.coffee,
    this.name,
    this.menuItemId,
  });

  final File? file;
  final DateTime? takenAt;
  final CupItemKind kind;
  final String? name;
  final String? menuItemId;

  bool get hasPhoto => file != null;

  @override
  List<Object?> get props => [file?.path, takenAt, kind, name, menuItemId];
}

/// What posting or editing a cup did.
class CupPostResult extends Equatable {
  const CupPostResult({this.cup, this.itemsAdded = 0, this.markedBeen = false});

  /// The cup as saved, when the server sent it back.
  final CupCard? cup;
  final int itemsAdded;

  /// The cafe was not Been before; posting marked it.
  final bool markedBeen;

  @override
  List<Object?> get props => [cup, itemsAdded, markedBeen];
}

/// A menu item to pick in the composer ("What did you order?").
class CupMenuOption extends Equatable {
  const CupMenuOption({required this.id, required this.name, this.kind});

  final String id;
  final String name;

  /// A guess from the menu category, to preselect the kind chip.
  final CupItemKind? kind;

  @override
  List<Object?> get props => [id, name, kind];
}

/// One cafe on a profile's Cups grid: that person's cups there.
class ProfileCafeCups extends Equatable {
  const ProfileCafeCups({
    required this.cafeId,
    required this.cafeName,
    required this.cups,
    this.cafeArea,
    this.cafeImageUrl,
    int? visitCount,
  }) : _visitCount = visitCount;

  final String cafeId;
  final String cafeName;
  final String? cafeArea;
  final String? cafeImageUrl;

  /// Newest visit first.
  final List<CupCard> cups;
  final int? _visitCount;

  int get visitCount => _visitCount ?? cups.length;

  List<CupItem> get photos => [for (final c in cups) ...c.photos];
  CupItem? get cover => photos.isEmpty ? null : photos.first;

  /// The newest rating, if any visit has one.
  int? get rating => cups.where((c) => c.rating != null).firstOrNull?.rating;

  /// The newest note, for a text-only tile.
  String? get note => cups.where((c) => c.hasNote).firstOrNull?.note;

  DateTime get lastVisitAt => cups.isEmpty
      ? DateTime.fromMillisecondsSinceEpoch(0)
      : cups.first.visitedAt;

  @override
  List<Object?> get props => [
    cafeId,
    cafeName,
    cafeArea,
    cafeImageUrl,
    cups,
    _visitCount,
  ];
}

/// A person's cups, grouped by cafe, newest visit first.
class ProfileCups extends Equatable {
  const ProfileCups({
    required this.userId,
    required this.cafes,
    this.highlightsPublic = true,
    this.isSelf = false,
  });

  final String userId;
  final List<ProfileCafeCups> cafes;
  final bool highlightsPublic;
  final bool isSelf;

  int get cupCount => cafes.fold(0, (n, c) => n + c.visitCount);
  int get cafeCount => cafes.length;
  int get photoCount => cafes.fold(0, (n, c) => n + c.photos.length);

  @override
  List<Object?> get props => [userId, cafes, highlightsPublic, isSelf];
}
