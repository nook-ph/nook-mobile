import 'package:nook/features/cups/data/cups_backend.dart';
import 'package:nook/features/cups/data/cups_json.dart';
import 'package:nook/features/cups/domain/entities/cup.dart';
import 'package:nook/features/gallery/domain/entities/cafe_story.dart';
import 'package:nook/features/gallery/domain/entities/community_photo.dart';
import 'package:nook/features/gallery/domain/entities/gallery_photo.dart';
import 'package:nook/features/gallery/domain/i_community_photos_repository.dart';
import 'package:nook/features/gallery/domain/i_gallery_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// A cafe's photos for the "Latest cups" tray and its grid, read from
/// `get_cafe_cup_photos` so each photo carries its cup (visit), stars and
/// note, and a moderated cup hides its photos. Falls back to [legacy] (the `user_photos` read) where the Cups
/// RPCs don't exist yet.
///
class CupsCommunityPhotosRepository implements ICommunityPhotosRepository {
  CupsCommunityPhotosRepository({
    required SupabaseClient client,
    required CupsBackend backend,
    required ICommunityPhotosRepository legacy,
  }) : _client = client,
       _backend = backend,
       _legacy = legacy;

  final SupabaseClient _client;
  final CupsBackend _backend;
  final ICommunityPhotosRepository _legacy;

  /// Cafe names by id: cups come without their cafe's name.
  final Map<String, ({String name, String? area})> _cafes = {};

  @override
  Future<CommunityPhotoPage> getCafePhotos(
    String cafeId, {
    required int limit,
    int offset = 0,
  }) async {
    try {
      return await _backend.run(
        cups: () => _cupPhotos(cafeId, limit: limit, offset: offset),
        legacy: () =>
            _legacy.getCafePhotos(cafeId, limit: limit, offset: offset),
      );
    } on GalleryException {
      rethrow;
    } catch (e) {
      throw GalleryException('Could not load the photos.', cause: e);
    }
  }

  Future<CommunityPhotoPage> _cupPhotos(
    String cafeId, {
    required int limit,
    required int offset,
  }) async {
    final cafeRead = _cafeOf(cafeId);
    final raw = await _client.rpc(
      'get_cafe_cup_photos',
      params: {
        'p_cafe_id': cafeId,
        'p_limit': limit.clamp(1, 100),
        'p_offset': offset,
      },
    );
    final cafe = await cafeRead;
    final json = raw is Map ? raw : const {};
    final rows = json['photos'] is List ? json['photos'] as List : const [];
    final me = _client.auth.currentUser?.id;
    final photos = [
      for (final row in rows)
        ?cupPhotoRowToCommunity(
          row,
          cafeId: cafeId,
          cafeName: cafe.name,
          cafeArea: cafe.area,
          me: me,
        ),
    ];
    final total = (json['total'] as num?)?.toInt() ?? photos.length;
    return CommunityPhotoPage(
      photos: photos,
      total: total < photos.length ? photos.length : total,
      hasMore: json['has_more'] == true,
      nextOffset: offset + rows.length,
    );
  }

  Future<({String name, String? area})> _cafeOf(String cafeId) async {
    final known = _cafes[cafeId];
    if (known != null) return known;
    try {
      final row = await _client
          .from('cafes')
          .select('name, neighborhood, city')
          .eq('id', cafeId)
          .maybeSingle();
      final name = (row?['name'] as String?)?.trim() ?? '';
      final area = [row?['neighborhood'], row?['city']]
          .whereType<String>()
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .join(', ');
      return _cafes[cafeId] = (
        name: name.isEmpty ? 'Cafe' : name,
        area: area.isEmpty ? null : area,
      );
    } catch (_) {
      return (name: 'Cafe', area: null);
    }
  }
}

/// One `get_cafe_cup_photos` row as a credited photo with its cup's
/// words. Null for a row with no username to credit.
CommunityPhoto? cupPhotoRowToCommunity(
  Object? raw, {
  required String cafeId,
  required String cafeName,
  String? cafeArea,
  String? me,
}) {
  if (raw is! Map) return null;
  final row = Map<String, dynamic>.from(raw);
  final username = (row['username'] as String?)?.trim() ?? '';
  final userId = (row['user_id'] as String?) ?? '';
  final imageUrl = (row['image_url'] as String?) ?? '';
  if (username.isEmpty || userId.isEmpty || imageUrl.isEmpty) return null;
  final rating = CupsJson.rating(row['rating']);
  final note = (row['note'] as String?)?.trim() ?? '';
  final fullName = (row['full_name'] as String?)?.trim();
  final avatar = (row['avatar_url'] as String?)?.trim();
  final takenAt =
      DateTime.tryParse(
        '${row['taken_at'] ?? row['visited_at'] ?? ''}',
      )?.toLocal() ??
      DateTime.now();
  final itemName = (row['item_name'] as String?)?.trim();
  return CommunityPhoto(
    photo: GalleryPhoto(
      id: '${row['id']}',
      userId: userId,
      cafeId: cafeId,
      cafeName: cafeName,
      cafeArea: cafeArea,
      imageUrl: imageUrl,
      drinkName: itemName == null || itemName.isEmpty ? null : itemName,
      takenAt: takenAt,
      source: row['source'] == 'review'
          ? GalleryPhotoSource.review
          : GalleryPhotoSource.gallery,
      sourceId: row['review_id'] as String?,
    ),
    credit: PhotoCredit(
      userId: userId,
      username: username,
      fullName: fullName == null || fullName.isEmpty ? null : fullName,
      avatarUrl: avatar == null || avatar.isEmpty ? null : avatar,
      isSelf: me != null && userId == me,
    ),
    cup: rating == null && note.isEmpty
        ? null
        : StoryReview(rating: rating, text: note),
    visit: row['cup_id'] as String?,
  );
}

/// A cup's photos as credited community photos, each carrying the cup's
/// stars and note. Empty for a cup whose author has no username to credit.
List<CommunityPhoto> cupPhotosToCommunity(
  CupCard card, {
  required String cafeId,
  required String cafeName,
  String? cafeArea,
  String? me,
}) {
  if (card.username.trim().isEmpty || card.userId.isEmpty) return const [];
  final credit = PhotoCredit(
    userId: card.userId,
    username: card.username,
    fullName: card.fullName,
    avatarUrl: card.avatarUrl,
    isSelf: card.isMine || (me != null && card.userId == me),
  );
  final words = card.rating == null && !card.hasNote
      ? null
      : StoryReview(rating: card.rating, text: card.note?.trim() ?? '');
  return [
    for (final item in card.photos)
      CommunityPhoto(
        photo: GalleryPhoto(
          id: item.photoId ?? item.id,
          userId: card.userId,
          cafeId: cafeId,
          cafeName: cafeName,
          cafeArea: cafeArea,
          imageUrl: item.imageUrl!,
          drinkName: item.label,
          caption: item.caption,
          takenAt: item.takenAt ?? card.visitedAt,
          source: GalleryPhotoSource.fromWire(item.source),
          sourceId: item.sourceId,
        ),
        credit: credit,
        cup: words,
        visit: card.id,
      ),
  ];
}
