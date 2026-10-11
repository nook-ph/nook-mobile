import 'package:nook/features/cups/domain/entities/cup.dart';

/// Maps the Cups RPC payloads (nook-supabase docs/CUPS_APPLY.md, "For the
/// app") to entities. Pure, so the mapping is testable without a backend.
/// Field names live only here.
abstract final class CupsJson {
  static CafeCups cafeCups(Object? raw, {required String cafeId}) {
    final json = _map(raw);
    return CafeCups(
      cafeId: (json['cafe_id'] as String?) ?? cafeId,
      stats: stats(json['stats']),
      cards: [for (final c in _list(json['cards'])) card(c, cafeId: cafeId)],
      total: _int(json['total']),
      hasMore: json['has_more'] == true,
    );
  }

  /// The `get_cafe_cup_stats` row: cups (visits), people, photos, photos
  /// per kind, and the rating from each person's latest rated visit.
  static CupStats stats(Object? raw) {
    final json = _map(raw);
    final rated = _int(json['rated_people_count'] ?? json['rated_count']);
    final kinds = <CupItemKind, int>{
      for (final kind in CupItemKind.values)
        if (_int(json['${kind.wire}_photo_count']) > 0)
          kind: _int(json['${kind.wire}_photo_count']),
    };
    return CupStats(
      cupCount: _int(json['cup_count']),
      peopleCount: _int(json['people_count']),
      photoCount: _int(json['photo_count']),
      ratedCount: rated,
      rating: rated == 0 ? null : _double(json['rating']),
      kindCounts: kinds,
    );
  }

  /// A `cup` object (also `cards[]`, `my_cups[]`). Every one has an id the
  /// cup RPCs take, a legacy visit (`is_virtual`) included.
  static CupCard card(Object? raw, {String? cafeId}) {
    final json = _map(raw);
    final id = _string(json['id'] ?? json['cup_id']) ?? '';
    final reviewId = _string(json['review_id']);
    final userId = (json['user_id'] as String?) ?? '';
    final visited = _date(json['visited_at'] ?? json['created_at']);
    return CupCard(
      id: id.isEmpty ? '$userId:${visited.toIso8601String()}' : id,
      cupId: id.isEmpty ? null : id,
      reviewId: reviewId,
      cafeId: _string(json['cafe_id']) ?? cafeId,
      source: _string(json['source']) ?? 'cup',
      isVirtual: json['is_virtual'] == true,
      userId: userId,
      username: (json['username'] as String?)?.trim() ?? '',
      fullName: _string(json['full_name']),
      avatarUrl: _string(json['avatar_url']),
      rating: rating(json['rating']),
      note: _string(json['note']),
      helpfulCount: _int(json['helpful_count']),
      hasVoted: json['has_voted'] == true,
      isMine: json['is_mine'] == true,
      visitedAt: visited,
      items: [for (final i in _list(json['items'])) item(i)],
      visitsByAuthor: _int(json['visits_by_author']).clamp(1, 1 << 20),
    );
  }

  /// `{ id, kind, item_name, menu_item_id, menu_item_name, photo|null }`.
  static CupItem item(Object? raw) {
    final json = _map(raw);
    final photo = json['photo'] is Map ? _map(json['photo']) : null;
    return CupItem(
      id: '${json['id'] ?? ''}',
      kind: CupItemKind.fromWire(json['kind']),
      name: _string(json['item_name']) ?? _string(json['menu_item_name']),
      menuItemId: _string(json['menu_item_id']),
      photoId: photo == null ? null : _string(photo['id']),
      imageUrl: photo == null ? null : _string(photo['image_url']),
      takenAt: photo?['taken_at'] == null ? null : _date(photo!['taken_at']),
      objectKey: photo == null ? null : _string(photo['object_key']),
      isHidden: photo?['is_hidden'] == true,
    );
  }

  /// `post_cup` → `{cup, marked_been}`; `update_cup` → `{cup}`;
  /// `add_cup_items` → `{cup, added}`.
  static CupPostResult postResult(Object? raw, {int itemsAdded = 0}) {
    final json = _map(raw);
    return CupPostResult(
      cup: json['cup'] is Map ? card(json['cup']) : null,
      itemsAdded: json.containsKey('added') ? _int(json['added']) : itemsAdded,
      markedBeen: json['marked_been'] == true,
    );
  }

  /// `p_visited_at` is a date: the visit's day, not an instant.
  static String visitDate(DateTime at) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${at.year}-${two(at.month)}-${two(at.day)}';
  }

  /// Null when the payload is null (a profile that can't be shown). Takes
  /// cafes with their cups, or a flat list of cups with cafe fields, which
  /// it groups by cafe.
  static ProfileCups? profileCups(Object? raw) {
    if (raw == null) return null;
    final json = _map(raw);
    final userId = (json['user_id'] as String?) ?? '';
    final cafes = <ProfileCafeCups>[];
    final grouped = _list(json['cafes']);
    if (grouped.isNotEmpty) {
      for (final c in grouped) {
        final cafe = _map(c);
        final cafeId = (cafe['cafe_id'] as String?) ?? '';
        final cups = [
          for (final cup in _list(cafe['cups']))
            card(_withUser(cup, userId), cafeId: cafeId),
        ]..sort((a, b) => b.visitedAt.compareTo(a.visitedAt));
        cafes.add(
          ProfileCafeCups(
            cafeId: cafeId,
            cafeName: _cafeName(cafe['cafe_name']),
            cafeArea: _area(cafe['cafe_area']),
            cafeImageUrl: _string(cafe['cafe_image_url']),
            visitCount: cafe['visit_count'] == null
                ? null
                : _int(cafe['visit_count']),
            cups: cups,
          ),
        );
      }
    } else {
      final byCafe = <String, List<Map<String, dynamic>>>{};
      for (final c in _list(json['cards'] ?? json['cups'])) {
        final cup = _map(c);
        (byCafe[(cup['cafe_id'] as String?) ?? ''] ??= []).add(cup);
      }
      for (final entry in byCafe.entries) {
        final first = entry.value.first;
        cafes.add(
          ProfileCafeCups(
            cafeId: entry.key,
            cafeName: _cafeName(first['cafe_name']),
            cafeArea: _area(first['cafe_area']),
            cafeImageUrl: _string(first['cafe_image_url']),
            cups: [
              for (final cup in entry.value)
                card(_withUser(cup, userId), cafeId: entry.key),
            ]..sort((a, b) => b.visitedAt.compareTo(a.visitedAt)),
          ),
        );
      }
    }
    cafes.sort((a, b) => b.lastVisitAt.compareTo(a.lastVisitAt));
    return ProfileCups(
      userId: userId,
      highlightsPublic: json['highlights_public'] != false,
      isSelf: json['is_self'] == true,
      cafes: cafes,
    );
  }

  /// Items as `post_cup` / `add_cup_items` take them.
  static Map<String, Object?> itemPayload(
    CupItemDraft draft, {
    String? objectKey,
    String? imageUrl,
  }) => {
    'kind': draft.kind.wire,
    'item_name': ?_string(draft.name),
    'menu_item_id': ?draft.menuItemId,
    'object_key': ?objectKey,
    'image_url': ?imageUrl,
    if (draft.takenAt != null || objectKey != null)
      'taken_at': (draft.takenAt ?? DateTime.now()).toUtc().toIso8601String(),
  };

  /// 1 to 5, or null. Never 0: a missing rating is no stars, not zero.
  static int? rating(Object? raw) {
    final n = raw is num ? raw.toInt() : int.tryParse('${raw ?? ''}');
    if (n == null || n < 1 || n > 5) return null;
    return n;
  }

  static Map<String, dynamic> _withUser(Object? raw, String userId) {
    final json = Map<String, dynamic>.from(_map(raw));
    json['user_id'] ??= userId;
    return json;
  }

  /// "Talamban , Cebu City" (a neighbourhood with a trailing space) reads
  /// "Talamban, Cebu City".
  static String? _area(Object? raw) =>
      _string(raw)?.replaceAll(RegExp(r'\s+,'), ',');

  static String _cafeName(Object? raw) {
    final name = (raw as String?)?.trim() ?? '';
    return name.isEmpty ? 'Cafe' : name;
  }

  static Map<String, dynamic> _map(Object? raw) =>
      raw is Map ? Map<String, dynamic>.from(raw) : const {};

  static List<Object?> _list(Object? raw) => raw is List ? raw : const [];

  static int _int(Object? raw) =>
      raw is num ? raw.toInt() : int.tryParse('${raw ?? ''}') ?? 0;

  static double? _double(Object? raw) =>
      raw is num ? raw.toDouble() : double.tryParse('${raw ?? ''}');

  static String? _string(Object? raw) {
    if (raw == null) return null;
    final s = raw.toString().trim();
    return s.isEmpty ? null : s;
  }

  static DateTime _date(Object? raw) =>
      DateTime.tryParse('${raw ?? ''}')?.toLocal() ??
      DateTime.fromMillisecondsSinceEpoch(0);
}
