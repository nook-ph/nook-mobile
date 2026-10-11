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
/// `get_cafe_cups` (newest cups first, their photos flattened) so each
/// photo carries its cup's stars and note and a moderated cup hides its
/// photos. Falls back to [legacy] (the `user_photos` read) where the Cups
/// RPCs don't exist yet.
///
/// Pages are counted in cups, not photos: [CommunityPhotoPage.nextOffset]
/// is the next cup.
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
      'get_cafe_cups',
      params: {
        'p_cafe_id': cafeId,
        'p_sort': CupSort.recent.wire,
        'p_limit': limit.clamp(1, 100),
        'p_offset': offset,
        'p_photo_limit': 0,
      },
    );
    final cafe = await cafeRead;
    final page = CupsJson.cafeCups(raw, cafeId: cafeId);
    final me = _client.auth.currentUser?.id;
    final photos = [
      for (final card in page.cards)
        ...cupPhotosToCommunity(
          card,
          cafeId: cafeId,
          cafeName: cafe.name,
          cafeArea: cafe.area,
          me: me,
        ),
    ];
    final total = page.stats.photoCount;
    return CommunityPhotoPage(
      photos: photos,
      total: total < photos.length ? photos.length : total,
      hasMore: page.hasMore,
      nextOffset: offset + page.cards.length,
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
          id: item.id,
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
