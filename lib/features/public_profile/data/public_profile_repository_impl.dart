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
    // `_` is a wildcard to LIKE and allowed in usernames: match it literally.
    final pattern = '${prefix.replaceAll('_', r'\_')}%';
    try {
      final rows = await _client
          .from('profiles')
          .select('id, username, full_name, avatar_url')
          .ilike('username', pattern)
          .eq('is_suspended', false)
          .eq('account_status', 'active')
          .limit(20);
      final people =
          [
            for (final row in rows)
              if (row['username'] is String)
                PersonMatch(
                  userId: row['id'] as String,
                  username: row['username'] as String,
                  fullName: row['full_name'] as String?,
                  avatarUrl: row['avatar_url'] as String?,
                ),
          ]..sort((a, b) {
            final byLength = a.username.length.compareTo(b.username.length);
            return byLength != 0
                ? byLength
                : a.username.toLowerCase().compareTo(b.username.toLowerCase());
          });
      return people.take(limit).toList();
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

  String? area(Object? neighborhood, Object? city) {
    final parts = [
      for (final p in [neighborhood, city])
        if (p is String && p.trim().isNotEmpty) p.trim(),
    ];
    return parts.isEmpty ? null : parts.join(', ');
  }

  final top = [
    for (final row in rows(json['top_cafes']))
      PublicTopCafe(
        rank: (row['rank'] as num).toInt(),
        cafeId: row['cafe_id'] as String,
        name: row['name'] as String? ?? 'Cafe',
        area: area(row['neighborhood'], row['city']),
        imageUrl: row['image_url'] as String?,
      ),
  ]..sort((a, b) => a.rank.compareTo(b.rank));

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
    // Belt and braces: never show more than three, nor any when private.
    topCafes: highlights ? top.take(3).toList() : const [],
    photos: highlights ? photos : const [],
    reviews: reviews,
  );
}
