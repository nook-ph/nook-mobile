import 'package:flutter/foundation.dart';
import 'package:nook/core/cafe/domain/entities/report_reason.dart';
import 'package:nook/features/cups/data/cups_community_photos_repository.dart';
import 'package:nook/features/cups/data/legacy_cups.dart';
import 'package:nook/features/cups/domain/entities/cup.dart';
import 'package:nook/features/cups/domain/i_cups_repository.dart';
import 'package:nook/features/gallery/domain/entities/community_photo.dart';
import 'package:nook/features/gallery/domain/i_community_photos_repository.dart';

/// `--dart-define=CUPS_DEMO=on` (debug builds only) swaps the Cups backend
/// for an in-memory one with fixtures, to see the Cups screens as they
/// will be once the migrations are applied, without touching any database.
bool get cupsDemoEnabled =>
    kDebugMode && const String.fromEnvironment('CUPS_DEMO') == 'on';

/// In-memory [ICupsRepository] for the debug demo and widget tests. Every
/// cafe starts with the same handful of cups (rated, unrated, photo-only,
/// text-only, two visits by one person); writes change only this memory.
class DemoCupsRepository implements ICupsRepository {
  DemoCupsRepository({String? me, DateTime Function()? now})
    : _me = me,
      _now = now ?? DateTime.now;

  final String? _me;
  final DateTime Function() _now;
  final Map<String, List<CupCard>> _byCafe = {};
  int _seq = 0;

  static const _base = 'https://lucerocris.sgp1.cdn.digitaloceanspaces.com';
  static const _photos = [
    '$_base/reviews/5b73a80b-9a60-4bec-9bcb-4c88559e4156/3c509ef3-057f-4206-94a8-0da675affbe1/1ca141dc-3355-4bed-ab88-a239abf5441e_0.jpg',
    '$_base/reviews/5b73a80b-9a60-4bec-9bcb-4c88559e4156/3c509ef3-057f-4206-94a8-0da675affbe1/34df5706-1ca5-43a6-a27c-18075862dfa0_1.jpg',
    '$_base/reviews/5b73a80b-9a60-4bec-9bcb-4c88559e4156/3c509ef3-057f-4206-94a8-0da675affbe1/c4c906e7-6464-4c65-82f0-517c7c59fdee_2.jpg',
    '$_base/reviews/41954fd7-c725-43cd-96bd-6a993dee4505/1997397e-1180-4fe8-8751-b38d2b225485/fa1a6b5d-8216-4912-a440-8680b97edad1_0.jpg',
    '$_base/reviews/41954fd7-c725-43cd-96bd-6a993dee4505/1997397e-1180-4fe8-8751-b38d2b225485/857b888f-987b-47cd-a061-057157aac1a0_1.jpg',
    '$_base/reviews/8c69c0f8-24d3-4517-b016-91c0b5afaf55/bc965e1c-e2e2-4756-82b7-fc3629e02442/fe635e80-6427-41b3-982d-9d0b79e603f7_0.jpg',
    '$_base/reviews/8c69c0f8-24d3-4517-b016-91c0b5afaf55/bc965e1c-e2e2-4756-82b7-fc3629e02442/6fef78b2-98ec-4fef-bc23-b24f5b8ab22c_1.jpg',
  ];

  @override
  CupsMode get mode => CupsMode.cups;

  @override
  Future<CupsMode> resolveMode() async => CupsMode.cups;

  List<CupCard> _cupsAt(String cafeId) =>
      _byCafe.putIfAbsent(cafeId, () => _seed(cafeId));

  CupItem _photo(int i, CupItemKind kind, String? name, int daysAgo) => CupItem(
    id: 'demo-photo-$i-${_seq++}',
    kind: kind,
    name: name,
    imageUrl: _photos[i % _photos.length],
    takenAt: _now().subtract(Duration(days: daysAgo)),
  );

  List<CupCard> _seed(String cafeId) {
    final now = _now();
    CupCard cup({
      required String id,
      required String user,
      required String username,
      int? rating,
      String? note,
      required int daysAgo,
      List<CupItem> items = const [],
      int helpful = 0,
      int visits = 1,
    }) => CupCard(
      id: id,
      cupId: id,
      cafeId: cafeId,
      userId: user,
      username: username,
      rating: rating,
      note: note,
      helpfulCount: helpful,
      isMine: user == _me,
      visitedAt: now.subtract(Duration(days: daysAgo)),
      items: items,
      visitsByAuthor: visits,
    );
    return [
      cup(
        id: '$cafeId-1',
        user: 'demo-mae',
        username: 'mae.brews',
        rating: 5,
        note:
            'Quiet upstairs and outlets at every table. The Spanish latte '
            'is not too sweet, and the banana bread is warm if you ask. '
            'Minimum spend is ₱180 after 6pm, worth it for a long work '
            'session.',
        daysAgo: 3,
        helpful: 3,
        visits: 2,
        items: [
          _photo(0, CupItemKind.coffee, 'Spanish latte', 3),
          _photo(1, CupItemKind.food, 'Banana bread', 3),
          _photo(2, CupItemKind.space, 'Upstairs', 3),
          _photo(3, CupItemKind.coffee, null, 3),
        ],
      ),
      cup(
        id: '$cafeId-2',
        user: 'demo-sai',
        username: 'sai',
        daysAgo: 6,
        items: [_photo(5, CupItemKind.coffee, 'Iced americano', 6)],
      ),
      cup(
        id: '$cafeId-3',
        user: 'demo-jun',
        username: 'jun.c',
        rating: 4,
        note: 'Good matcha, a bit loud at lunch.',
        daysAgo: 12,
        helpful: 1,
        items: const [
          CupItem(
            id: 'demo-text-1',
            kind: CupItemKind.drink,
            name: 'Iced matcha latte',
          ),
          CupItem(id: 'demo-text-2', kind: CupItemKind.food, name: 'Ensaymada'),
        ],
      ),
      cup(
        id: '$cafeId-4',
        user: 'demo-mae',
        username: 'mae.brews',
        daysAgo: 20,
        visits: 2,
        items: [
          _photo(6, CupItemKind.drink, 'Hot chocolate', 20),
          _photo(4, CupItemKind.coffee, 'Cortado', 20),
        ],
      ),
    ];
  }

  @override
  Future<CafeCups> getCafeCups(
    String cafeId, {
    CupSort sort = CupSort.recommended,
    int? ratingFilter,
    CupItemKind? kind,
    int limit = 10,
    int offset = 0,
  }) async {
    final all = _cupsAt(cafeId);
    final matching = LegacyCups.sort([
      for (final c in all)
        if ((ratingFilter == null || c.rating == ratingFilter) &&
            (kind == null || LegacyCups.hasKind(c, kind)))
          c,
    ], sort);
    final page = matching.skip(offset).take(limit).toList();
    return CafeCups(
      cafeId: cafeId,
      stats: CupStats.fromCards(all),
      cards: page,
      total: matching.length,
      hasMore: offset + page.length < matching.length,
      myCups: LegacyCups.mine(all),
    );
  }

  @override
  Future<ProfileCups?> getProfileCups({
    String? userId,
    String? username,
  }) async {
    final who = userId ?? 'demo-mae';
    final cafes = <ProfileCafeCups>[];
    for (final entry in _byCafe.entries) {
      final mine = [
        for (final c in entry.value)
          if (c.userId == who) c,
      ];
      if (mine.isEmpty) continue;
      cafes.add(
        ProfileCafeCups(cafeId: entry.key, cafeName: 'Demo cafe', cups: mine),
      );
    }
    return ProfileCups(userId: who, isSelf: who == _me, cafes: cafes);
  }

  @override
  Future<CupPostResult> postCup({
    required String cafeId,
    int? rating,
    String? note,
    DateTime? visitedAt,
    required List<CupItemDraft> items,
    void Function(int index)? onPhotoUploaded,
  }) async {
    final cups = _cupsAt(cafeId);
    final id = 'demo-new-${_seq++}';
    for (var i = 0; i < items.length; i++) {
      if (items[i].hasPhoto) {
        await Future<void>.delayed(const Duration(milliseconds: 300));
        onPhotoUploaded?.call(i);
      }
    }
    final cup = CupCard(
      id: id,
      cupId: id,
      cafeId: cafeId,
      userId: _me ?? 'demo-me',
      username: 'you',
      rating: rating,
      note: note,
      isMine: true,
      visitedAt: visitedAt ?? _now(),
      items: [
        for (final d in items)
          CupItem(
            id: 'demo-item-${_seq++}',
            kind: d.kind,
            name: d.name,
            menuItemId: d.menuItemId,
            imageUrl: d.file?.path,
            takenAt: d.takenAt,
          ),
      ],
    );
    cups.insert(0, cup);
    return CupPostResult(cup: cup, itemsAdded: items.length, markedBeen: true);
  }

  @override
  Future<CupPostResult> updateCup(
    CupCard cup, {
    int? rating,
    String? note,
    DateTime? visitedAt,
    List<CupItemDraft> addItems = const [],
    List<String> removeItemIds = const [],
    void Function(int index)? onPhotoUploaded,
  }) async {
    final cups = _cupsAt(cup.cafeId ?? '');
    final i = cups.indexWhere((c) => c.id == cup.id);
    final updated = CupCard(
      id: cup.id,
      cupId: cup.cupId,
      cafeId: cup.cafeId,
      userId: cup.userId,
      username: cup.username,
      rating: rating,
      note: note,
      isMine: true,
      visitedAt: visitedAt ?? cup.visitedAt,
      items: [
        for (final item in cup.items)
          if (!removeItemIds.contains(item.id)) item,
        for (final d in addItems)
          CupItem(
            id: 'demo-item-${_seq++}',
            kind: d.kind,
            name: d.name,
            imageUrl: d.file?.path,
          ),
      ],
    );
    if (i >= 0) cups[i] = updated;
    return CupPostResult(cup: updated, itemsAdded: addItems.length);
  }

  @override
  Future<void> deleteCup(CupCard cup) async {
    _cupsAt(cup.cafeId ?? '').removeWhere((c) => c.id == cup.id);
  }

  @override
  Future<CupCard> toggleHelpful(CupCard card) async => card.copyWith(
    hasVoted: !card.hasVoted,
    helpfulCount: card.helpfulCount + (card.hasVoted ? -1 : 1),
  );

  @override
  Future<void> reportCup(
    CupCard card, {
    required String cafeId,
    required ReportReason reason,
    String? details,
  }) async {}

  /// The cafe's photos for the stories tray, from the same cups.
  ICommunityPhotosRepository get photos => _DemoPhotos(this);
}

class _DemoPhotos implements ICommunityPhotosRepository {
  _DemoPhotos(this._cups);

  final DemoCupsRepository _cups;

  @override
  Future<CommunityPhotoPage> getCafePhotos(
    String cafeId, {
    required int limit,
    int offset = 0,
  }) async {
    final page = await _cups.getCafeCups(
      cafeId,
      sort: CupSort.recent,
      limit: limit,
      offset: offset,
    );
    final photos = [
      for (final card in page.cards)
        ...cupPhotosToCommunity(
          card,
          cafeId: cafeId,
          cafeName: 'this cafe',
          me: _cups._me,
        ),
    ];
    return CommunityPhotoPage(
      photos: photos,
      total: page.stats.photoCount,
      hasMore: page.hasMore,
      nextOffset: offset + page.cards.length,
    );
  }
}
