import 'package:nook/features/gallery/data/gallery_repository_impl.dart';
import 'package:nook/features/gallery/domain/entities/community_photo.dart';
import 'package:nook/features/gallery/domain/i_community_photos_repository.dart';
import 'package:nook/features/gallery/domain/i_gallery_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// [ICommunityPhotosRepository] on Supabase. Two reads: one page of
/// `user_photos` for the cafe, then the authors' `profiles`.
///
/// What may be shown is decided by RLS, for guests too
/// (`user_photos_select_public` and `_anon`): hidden and moderated photos,
/// galleries their owner made private, review photos of a hidden review and
/// anyone blocked either way never come back. The viewer's own photos come
/// back through `user_photos_select_own`, so the visible filters are
/// repeated here for them. `user_photos.user_id` points at `auth.users`,
/// not `profiles`, so the authors cannot be embedded in the first read.
class CommunityPhotosRepositoryImpl implements ICommunityPhotosRepository {
  CommunityPhotosRepositoryImpl({required SupabaseClient client})
    : _client = client;

  final SupabaseClient _client;

  static const _columns =
      'id, user_id, cafe_id, image_url, drink_name, caption, taken_at, source, '
      'source_id, moderation_status, cafes(name, neighborhood, city)';

  @override
  Future<CommunityPhotoPage> getCafePhotos(
    String cafeId, {
    required int limit,
    int offset = 0,
  }) async {
    final me = _client.auth.currentUser?.id;
    try {
      final response = await _client
          .from('user_photos')
          .select(_columns)
          .eq('cafe_id', cafeId)
          // Own photos are visible to their owner when hidden too; the
          // cafe page shows only what everyone else can see.
          .eq('is_hidden', false)
          .eq('moderation_status', 'visible')
          // Served by user_photos_cafe_taken_idx. Ties newest id first, as
          // sortGallery orders them, so the viewer swipes in strip order.
          .order('taken_at', ascending: false)
          .order('id', ascending: false)
          .range(offset, offset + limit - 1)
          .count(CountOption.exact);
      final rows = response.data;
      final total = response.count;

      final authorIds = {for (final row in rows) row['user_id'] as String};
      final authors = authorIds.isEmpty
          ? const <Map<String, dynamic>>[]
          : await _client
                .from('profiles')
                .select('id, username, full_name, avatar_url, is_suspended')
                .inFilter('id', authorIds.toList());
      final byId = {for (final a in authors) a['id'] as String: a};

      final photos = <CommunityPhoto>[];
      for (final row in rows) {
        final author = byId[row['user_id']];
        final credit = author == null ? null : _credit(author, me);
        // No username to credit (an unfinished or removed account) or a
        // suspended author: leave the photo out rather than show it
        // uncredited.
        if (credit == null) continue;
        // Pins are for the owner's own profile; here the order is by date.
        photos.add(
          CommunityPhoto(
            photo: galleryPhotoFromRow(row).copyWith(clearPin: true),
            credit: credit,
          ),
        );
      }
      return CommunityPhotoPage(
        photos: photos,
        total: total < photos.length ? photos.length : total,
        hasMore: rows.length == limit && offset + rows.length < total,
        nextOffset: offset + rows.length,
      );
    } on PostgrestException catch (e) {
      throw GalleryException('Could not load the photos.', cause: e);
    }
  }

  static PhotoCredit? _credit(Map<String, dynamic> row, String? me) {
    final username = (row['username'] as String?)?.trim() ?? '';
    if (username.isEmpty || row['is_suspended'] == true) return null;
    final name = (row['full_name'] as String?)?.trim();
    final avatar = (row['avatar_url'] as String?)?.trim();
    final id = row['id'] as String;
    return PhotoCredit(
      userId: id,
      username: username,
      fullName: name == null || name.isEmpty ? null : name,
      avatarUrl: avatar == null || avatar.isEmpty ? null : avatar,
      isSelf: id == me,
    );
  }
}
