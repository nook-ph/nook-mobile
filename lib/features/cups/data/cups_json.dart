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

  static CupStats stats(Object? raw) {
    final json = _map(raw);
    final rated = _int(json['rated_count'] ?? json['rated_people']);
    final kinds = <CupItemKind, int>{};
    final byKind = _map(json['kind_counts']);
    for (final entry in byKind.entries) {
      final kind = CupItemKind.fromWire(entry.key);
      if (kind != null) kinds[kind] = _int(entry.value);
    }
    return CupStats(
      cupCount: _int(json['cup_count'] ?? json['card_count']),
      peopleCount: _int(json['people_count']),
      photoCount: _int(json['photo_count']),
      ratedCount: rated,
      rating: rated == 0 ? null : _double(json['rating']),
      kindCounts: kinds,
    );
  }

  static CupCard card(Object? raw, {String? cafeId}) {
    final json = _map(raw);
    final cupId = _string(json['cup_id'] ?? json['id']);
    final reviewId = _string(json['review_id']);
    final userId = (json['user_id'] as String?) ?? '';
    final visited = _date(
      json['visited_at'] ?? json['created_at'] ?? json['last_activity_at'],
    );
    final rawItems = json['items'] is List ? json['items'] : json['photos'];
    return CupCard(
      id: cupId ?? reviewId ?? '$userId:${visited.toIso8601String()}',
      cupId: cupId,
      reviewId: reviewId,
      cafeId: _string(json['cafe_id']) ?? cafeId,
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
      items: [for (final i in _list(rawItems)) item(i)],
      visitsByAuthor: _int(json['visits_by_author']).clamp(1, 1 << 20),
    );
  }

  static CupItem item(Object? raw) {
    final json = _map(raw);
    return CupItem(
      id: '${json['id'] ?? json['item_id'] ?? json['object_key'] ?? ''}',
      kind: CupItemKind.fromWire(json['kind']),
      name: _string(json['item_name'] ?? json['drink_name']),
      menuItemId: _string(json['menu_item_id']),
      imageUrl: _string(json['image_url']),
      takenAt: json['taken_at'] == null ? null : _date(json['taken_at']),
      caption: _string(json['caption']),
      source: _string(json['source']),
      objectKey: _string(json['object_key']),
    );
  }

  /// `post_cup` → `{cup, marked_been}`; `update_cup` / `add_cup_items`
  /// return the cup the same way (or bare).
  static CupPostResult postResult(Object? raw, {int itemsAdded = 0}) {
    final json = _map(raw);
    final cup = json['cup'] is Map
        ? card(json['cup'])
        : (json.containsKey('user_id') ? card(json) : null);
    return CupPostResult(
      cup: cup,
      itemsAdded: json.containsKey('items_added')
          ? _int(json['items_added'])
          : itemsAdded,
      markedBeen: json['marked_been'] == true,
    );
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
            cafeArea: _string(cafe['cafe_area']),
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
            cafeArea: _string(first['cafe_area']),
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
