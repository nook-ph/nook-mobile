import 'package:equatable/equatable.dart';
import 'package:nook/features/gallery/domain/entities/gallery_photo.dart';

/// Who added a gallery photo, as a cafe page credits them.
class PhotoCredit extends Equatable {
  const PhotoCredit({
    required this.userId,
    required this.username,
    this.fullName,
    this.avatarUrl,
    this.isSelf = false,
  });

  final String userId;

  /// Without the @.
  final String username;
  final String? fullName;
  final String? avatarUrl;

  /// The signed-in person's own photo: credited "You" and not a link.
  final bool isSelf;

  /// "@sai", or "You" on your own photo.
  String get label => isSelf ? 'You' : '@$username';

  @override
  List<Object?> get props => [userId, username, fullName, avatarUrl, isSelf];
}

/// A gallery photo shown on its cafe's page, with who added it. Only
/// photos anyone may see reach here: not hidden, not moderated, the
/// author's gallery public and no block either way (RLS on `user_photos`).
class CommunityPhoto extends Equatable {
  const CommunityPhoto({required this.photo, required this.credit});

  final GalleryPhoto photo;
  final PhotoCredit credit;

  String get id => photo.id;

  @override
  List<Object?> get props => [photo, credit];
}

/// One page of a cafe's community photos, newest first.
class CommunityPhotoPage extends Equatable {
  const CommunityPhotoPage({
    required this.photos,
    required this.total,
    required this.hasMore,
    required this.nextOffset,
  });

  final List<CommunityPhoto> photos;

  /// Every photo of the cafe the viewer may see, not only this page.
  final int total;

  /// Whether another page follows this one.
  final bool hasMore;

  /// Where the next page starts, in rows. Not `photos.length`: a row whose
  /// author can't be credited is read but left out.
  final int nextOffset;

  @override
  List<Object?> get props => [photos, total, hasMore, nextOffset];
}
