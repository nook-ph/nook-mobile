import 'package:nook/core/cafe/domain/entities/cafe_details.dart';
import 'package:nook/features/gallery/domain/entities/gallery_photo.dart';
import 'package:nook/features/public_profile/domain/entities/public_profile.dart';
import 'package:nook/features/public_profile/domain/i_public_profile_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// [IPublicProfileRepository] on Supabase: the `get_public_profile` RPC and
/// the owner's `profiles.show_profile_highlights` (migration
/// `20261005120000_public_profile.sql`).
class PublicProfileRepositoryImpl implements IPublicProfileRepository {
  PublicProfileRepositoryImpl({required SupabaseClient client})
    : _client = client;

  final SupabaseClient _client;

  @override
  Future<PublicProfile?> getProfile({String? username, String? userId}) async {
    assert(username != null || userId != null);
    try {
      final result = await _client.rpc(
        'get_public_profile',
        params: {
          'p_user_id': ?userId,
          if (userId == null) 'p_username': username,
        },
      );
      if (result is! Map) return null;
      return publicProfileFromJson(Map<String, dynamic>.from(result));
    } on PostgrestException catch (e) {
      throw PublicProfileException('Could not load the profile.', cause: e);
    }
  }

  @override
  Future<List<PersonMatch>> searchPeople(String prefix, {int limit = 5}) async {
    // The RPC matches the prefix literally (LIKE wildcards escaped), skips
    // suspended and inactive accounts and blocks in either direction, and
    // returns the shortest usernames first (nook-supabase
    // 20261008161000_blocks_both_ways_gallery_and_search.sql).
    try {
      final rows = await _client.rpc(
        'search_people',
        params: {'p_prefix': prefix, 'p_limit': limit},
      );
      return [
        for (final row in (rows as List? ?? const []).whereType<Map>())
          if (row['username'] is String && row['id'] is String)
            PersonMatch(
              userId: row['id'] as String,
              username: row['username'] as String,
              fullName: row['full_name'] as String?,
              avatarUrl: row['avatar_url'] as String?,
            ),
      ].take(limit).toList();
    } on PostgrestException catch (e) {
      throw PublicProfileException('Could not search people.', cause: e);
    }
  }

  String get _userId {
    final id = _client.auth.currentUser?.id;
    if (id == null) throw const PublicProfileException('Not signed in.');
    return id;
  }

  @override
  Future<bool> getMyHighlightsPublic() async {
    try {
      final row = await _client
          .from('profiles')
          .select('show_profile_highlights')
          .eq('id', _userId)
          .maybeSingle();
      return row?['show_profile_highlights'] as bool? ?? true;
    } on PostgrestException catch (e) {
      throw PublicProfileException('Could not read the setting.', cause: e);
    }
  }

  @override
  Future<void> setMyHighlightsPublic(bool value) async {
    try {
      await _client
          .from('profiles')
          .update({'show_profile_highlights': value})
          .eq('id', _userId);
    } on PostgrestException catch (e) {
      throw PublicProfileException('Could not save the setting.', cause: e);
    }
  }

  @override
  Future<void> reportPhoto(
    String photoId,
    PhotoReportReason reason, {
    String? details,
  }) async {
    try {
      await _client.from('photo_reports').insert({
        'photo_id': photoId,
        'reporter_id': _userId,
        'reason': reason.wire,
        'details': ?_details(details),
      });
    } on PostgrestException catch (e) {
      // Already reported by this person: the report stands.
      if (e.code == '23505') return;
      throw PublicProfileException('Could not send the report.', cause: e);
    }
  }

  @override
  Future<void> reportProfile(
    String userId,
    ProfileReportReason reason, {
    String? details,
  }) async {
    try {
      await _client.from('profile_reports').insert({
        'profile_id': userId,
        'reporter_id': _userId,
        'reason': reason.wire,
        'details': ?_details(details),
      });
    } on PostgrestException catch (e) {
      // Already reported by this person: the report stands.
      if (e.code == '23505') return;
      throw PublicProfileException('Could not send the report.', cause: e);
    }
  }

  /// The optional detail, trimmed, or none. The sheet's field already caps
  /// it at the DB's 500.
  static String? _details(String? text) {
    final trimmed = text?.trim() ?? '';
    return trimmed.isEmpty ? null : trimmed;
  }
}

/// The RPC's JSON as a [PublicProfile]. Tolerant of missing lists, so an
/// older server shape degrades to an empty strip rather than a crash.
PublicProfile publicProfileFromJson(Map<String, dynamic> json) {
  final counts = json['counts'] is Map
      ? Map<String, dynamic>.from(json['counts'] as Map)
      : const <String, dynamic>{};
  final userId = json['user_id'] as String;

  List<Map<String, dynamic>> rows(Object? value) => value is List
      ? [
          for (final item in value)
            if (item is Map) Map<String, dynamic>.from(item),
        ]
      : const [];

  final photos = [
    for (final row in rows(json['photos']))
      GalleryPhoto(
        id: row['id'] as String,
        userId: userId,
        cafeId: row['cafe_id'] as String,
        cafeName: row['cafe_name'] as String? ?? 'Cafe',
        cafeArea: row['cafe_area'] as String?,
        imageUrl: row['image_url'] as String,
        drinkName: row['drink_name'] as String?,
        caption: row['caption'] as String?,
        takenAt:
            DateTime.tryParse(row['taken_at'] as String? ?? '') ??
            DateTime.now(),
        source: GalleryPhotoSource.fromWire(row['source'] as String?),
        sourceId: row['source_id'] as String?,
        pinOrder: (row['pin_order'] as num?)?.toInt(),
      ),
  ];

  final reviews = [
    for (final row in rows(json['reviews']))
      WrittenReview(
        id: row['id'] as String,
        cafeId: row['cafe_id'] as String,
        cafeName: row['cafe_name'] as String? ?? 'Cafe',
        cafeImageUrl: row['cafe_image_url'] as String?,
        rating: (row['rating'] as num?)?.toInt() ?? 0,
        content: row['content'] as String? ?? '',
        imageUrls: [
          for (final url in (row['image_urls'] as List? ?? const []))
            if (url is String) url,
        ],
        createdAt:
            DateTime.tryParse(row['created_at'] as String? ?? '') ??
            DateTime.now(),
        updatedAt:
            DateTime.tryParse(row['created_at'] as String? ?? '') ??
            DateTime.now(),
      ),
  ];

  final highlights = json['highlights_public'] as bool? ?? true;
  return PublicProfile(
    userId: userId,
    username: json['username'] as String,
    fullName: json['full_name'] as String?,
    avatarUrl: json['avatar_url'] as String?,
    bio: json['bio'] as String?,
    highlightsPublic: highlights,
    isSelf: json['is_self'] as bool? ?? false,
    reviewCount: (counts['reviews'] as num?)?.toInt() ?? reviews.length,
    rankedCount: highlights ? (counts['ranked'] as num?)?.toInt() : null,
    cupCount: highlights ? (counts['cups'] as num?)?.toInt() : null,
    photos: highlights ? photos : const [],
    reviews: reviews,
  );
}
