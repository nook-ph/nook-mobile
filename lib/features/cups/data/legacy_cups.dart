import 'package:nook/core/cafe/domain/entities/cafe_details.dart';
import 'package:nook/features/cups/domain/entities/cup.dart';
import 'package:nook/features/gallery/domain/entities/community_photo.dart';
import 'package:nook/features/gallery/domain/entities/gallery_photo.dart';

/// Builds cups out of the legacy reads (reviews and gallery photos) the
/// way the Cups backend reads legacy rows: each review is one visit, with
/// its photos; loose gallery photos make one visit per person, cafe and
/// day. Pure, so the fallback is testable on its own.
abstract final class LegacyCups {
  /// [reviews] and [photos] of one cafe, already filtered to what the
  /// viewer may see.
  static List<CupCard> cafeCards({
    required List<Review> reviews,
    required List<CommunityPhoto> photos,
    required String cafeId,
    String? me,
  }) {
    final credits = <String, PhotoCredit>{};
    for (final p in photos) {
      credits.putIfAbsent(p.credit.userId, () => p.credit);
    }
    final byReview = <String, List<GalleryPhoto>>{};
    final loose = <CommunityPhoto>[];
    final reviewIds = {for (final r in reviews) r.id};
    for (final p in photos) {
      final reviewId = p.photo.sourceId;
      if (p.photo.isFromReview &&
          reviewId != null &&
          reviewIds.contains(reviewId)) {
        (byReview[reviewId] ??= []).add(p.photo);
      } else {
        loose.add(p);
      }
    }

    final cards = <CupCard>[];
    for (final r in reviews) {
      final credit = credits[r.userId];
      final reviewName = r.name?.trim() ?? '';
      cards.add(
        _reviewCard(
          reviewId: r.id,
          cafeId: cafeId,
          userId: r.userId,
          username: credit?.username ?? reviewName,
          fullName: credit?.fullName,
          avatarUrl: credit?.avatarUrl,
          rating: r.rating,
          content: r.content,
          createdAt: r.createdAt,
          imageUrls: r.imageUrls,
          photos: byReview[r.id] ?? const [],
          helpfulCount: r.helpfulCount,
          hasVoted: r.hasVoted,
          isMine: me != null && r.userId == me,
        ),
      );
    }
    // The credit is the author (the photo row's user, joined to profiles).
    final byPersonDay = <String, List<CommunityPhoto>>{};
    for (final p in loose) {
      final key = '${p.credit.userId}|${_dayKey(p.photo.takenAt)}';
      (byPersonDay[key] ??= []).add(p);
    }
    for (final group in byPersonDay.values) {
      final credit = group.first.credit;
      cards.add(
        _photoCard(
          [for (final p in group) p.photo],
          userId: credit.userId,
          cafeId: cafeId,
          username: credit.username,
          fullName: credit.fullName,
          avatarUrl: credit.avatarUrl,
          isMine: credit.isSelf || (me != null && credit.userId == me),
        ),
      );
    }
    return _withVisitCounts(cards);
  }

  /// A person's cups grid: their reviews and visible photos as visits,
  /// grouped by cafe, newest visit first.
  static List<ProfileCafeCups> profileCafes({
    required String userId,
    required String username,
    String? avatarUrl,
    bool isMine = false,
    required List<WrittenReview> reviews,
    required List<GalleryPhoto> photos,
  }) {
    final visible = [
      for (final p in photos)
        if (!p.isHidden && !p.isModerated) p,
    ];
    final reviewIds = {for (final r in reviews) r.id};
    final cafeIds = <String>{
      for (final r in reviews) r.cafeId,
      for (final p in visible) p.cafeId,
    };
    final cafes = <ProfileCafeCups>[];
    for (final cafeId in cafeIds) {
      final cafePhotos = [
        for (final p in visible)
          if (p.cafeId == cafeId) p,
      ];
      final cafeReviews = [
        for (final r in reviews)
          if (r.cafeId == cafeId) r,
      ];
      final cards = <CupCard>[
        for (final r in cafeReviews)
          _reviewCard(
            reviewId: r.id,
            cafeId: cafeId,
            userId: userId,
            username: username,
            avatarUrl: avatarUrl,
            rating: r.rating,
            content: r.content,
            createdAt: r.createdAt,
            imageUrls: r.imageUrls,
            photos: [
              for (final p in cafePhotos)
                if (p.isFromReview && p.sourceId == r.id) p,
            ],
            isMine: isMine,
          ),
        for (final group in _byDay([
          for (final p in cafePhotos)
            if (!(p.isFromReview && reviewIds.contains(p.sourceId))) p,
        ]))
          _photoCard(
            group,
            userId: userId,
            cafeId: cafeId,
            username: username,
            avatarUrl: avatarUrl,
            isMine: isMine,
          ),
      ]..sort((a, b) => b.visitedAt.compareTo(a.visitedAt));
      final named = cafePhotos.isEmpty ? null : cafePhotos.first;
      final review = cafeReviews.isEmpty ? null : cafeReviews.first;
      cafes.add(
        ProfileCafeCups(
          cafeId: cafeId,
          cafeName: named?.cafeName ?? review?.cafeName ?? 'Cafe',
          cafeArea: named?.cafeArea,
          cafeImageUrl: review?.cafeImageUrl,
          cups: _withVisitCounts(cards),
        ),
      );
    }
    cafes.sort((a, b) => b.lastVisitAt.compareTo(a.lastVisitAt));
    return cafes;
  }

  /// Orders [cards] as `get_cafe_cups` does for [sort].
  static List<CupCard> sort(List<CupCard> cards, CupSort sort) {
    double recommended(CupCard c) =>
        (c.hasNote ? 1 : 0) +
        (c.hasPhotos ? 1 : 0) +
        (c.rating ?? 0) * 0.4 +
        c.helpfulCount * 0.3 +
        c.visitedAt.millisecondsSinceEpoch / 1000 / 1000000 * 0.3;
    int byKey(CupCard a, CupCard b) => switch (sort) {
      CupSort.recommended => recommended(b).compareTo(recommended(a)),
      CupSort.recent => 0,
      CupSort.highest => (b.rating ?? 0).compareTo(a.rating ?? 0),
      CupSort.helpful => b.helpfulCount.compareTo(a.helpfulCount),
    };
    final sorted = [...cards];
    sorted.sort((a, b) {
      final first = byKey(a, b);
      if (first != 0) return first;
      final recent = b.visitedAt.compareTo(a.visitedAt);
      return recent != 0 ? recent : a.id.compareTo(b.id);
    });
    return sorted;
  }

  /// Whether [card] has an item of [kind]. Legacy photos have no kind, so
  /// they only show under All.
  static bool hasKind(CupCard card, CupItemKind kind) =>
      card.items.any((i) => i.kind == kind);

  static CupItem fromGallery(GalleryPhoto p) => CupItem(
    id: p.id,
    photoId: p.id,
    isHidden: p.isHidden,
    name: p.drinkName,
    imageUrl: p.imageUrl,
    takenAt: p.takenAt,
    caption: p.caption,
    source: p.source.wire,
    sourceId: p.sourceId,
  );

  static CupCard _reviewCard({
    required String reviewId,
    required String cafeId,
    required String userId,
    required String username,
    String? fullName,
    String? avatarUrl,
    required int rating,
    required String content,
    required DateTime createdAt,
    required List<String> imageUrls,
    required List<GalleryPhoto> photos,
    int helpfulCount = 0,
    bool hasVoted = false,
    bool isMine = false,
  }) {
    final items = [for (final p in photos) fromGallery(p)];
    // A review's photos are mirrored into the gallery; any that are not
    // (an old review, or a private gallery) still show, as on 1.1.x.
    final shown = {for (final i in items) i.imageUrl};
    for (var i = 0; i < imageUrls.length; i++) {
      final url = imageUrls[i];
      if (url.isEmpty || shown.contains(url)) continue;
      items.add(
        CupItem(
          id: 'review:$reviewId:$i',
          imageUrl: url,
          takenAt: createdAt,
          source: 'review',
          sourceId: reviewId,
        ),
      );
    }
    final note = content.trim();
    return CupCard(
      id: 'review:$reviewId',
      reviewId: reviewId,
      source: 'review',
      isVirtual: true,
      cafeId: cafeId,
      userId: userId,
      username: username,
      fullName: fullName,
      avatarUrl: avatarUrl,
      rating: rating < 1 || rating > 5 ? null : rating,
      note: note.isEmpty ? null : note,
      helpfulCount: helpfulCount,
      hasVoted: hasVoted,
      isMine: isMine,
      visitedAt: createdAt,
      items: List.unmodifiable(items),
    );
  }

  static CupCard _photoCard(
    List<GalleryPhoto> group, {
    required String userId,
    required String cafeId,
    required String username,
    String? fullName,
    String? avatarUrl,
    bool isMine = false,
  }) {
    final sorted = [...group]..sort((a, b) => b.takenAt.compareTo(a.takenAt));
    final first = sorted.first;
    return CupCard(
      id: 'photos:$userId:${_dayKey(first.takenAt)}',
      source: 'photos',
      isVirtual: true,
      cafeId: cafeId,
      userId: userId,
      username: username,
      fullName: fullName,
      avatarUrl: avatarUrl,
      isMine: isMine,
      visitedAt: first.takenAt,
      items: List.unmodifiable([for (final p in sorted) fromGallery(p)]),
    );
  }

  /// Loose photos grouped per person and day, newest day first.
  static List<List<GalleryPhoto>> _byDay(List<GalleryPhoto> photos) {
    final groups = <String, List<GalleryPhoto>>{};
    for (final p in photos) {
      (groups['${p.userId}|${_dayKey(p.takenAt)}'] ??= []).add(p);
    }
    return groups.values.toList();
  }

  static String _dayKey(DateTime at) {
    final local = at.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)}';
  }

  static List<CupCard> _withVisitCounts(List<CupCard> cards) {
    final visits = <String, int>{};
    for (final c in cards) {
      visits[c.userId] = (visits[c.userId] ?? 0) + 1;
    }
    return [
      for (final c in cards)
        CupCard(
          id: c.id,
          cupId: c.cupId,
          reviewId: c.reviewId,
          cafeId: c.cafeId,
          source: c.source,
          isVirtual: c.isVirtual,
          userId: c.userId,
          username: c.username,
          fullName: c.fullName,
          avatarUrl: c.avatarUrl,
          rating: c.rating,
          note: c.note,
          helpfulCount: c.helpfulCount,
          hasVoted: c.hasVoted,
          isMine: c.isMine,
          visitedAt: c.visitedAt,
          items: c.items,
          visitsByAuthor: visits[c.userId] ?? 1,
        ),
    ];
  }
}
