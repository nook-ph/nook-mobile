/// PostHog events for profiles and the coffee gallery, sent through
/// `logAppEvent`. Named object_verb in the past tense, like
/// `signup_code_submitted` and `rank_photo_added`. No ids of other people
/// and no free text go in the properties.
abstract final class ProfileEvents {
  /// Someone's public profile loaded. Properties: `source` (one of
  /// [ProfileViewSource]), `is_self`, `highlights_public`.
  static const profileViewed = 'public_profile_viewed';

  /// The share sheet for a profile closed. Properties: `own`, `result`
  /// (`success`, `dismissed` or `unavailable`).
  static const profileShared = 'profile_shared';

  /// Photos saved to the owner's gallery. Properties: `count`, `source`
  /// (`gallery` or `rank`), `has_drink`, `has_note`.
  static const galleryPhotosAdded = 'gallery_photos_added';

  /// A visitor reported a photo. Properties: `reason`.
  static const photoReported = 'photo_reported';

  /// A visitor reported a person (their name, photo or bio). Properties:
  /// `reason`.
  static const profileReported = 'profile_reported';

  /// A user blocked someone. Properties: `from` (`profile` or `review`).
  static const userBlocked = 'user_blocked';

  /// The owner turned their gallery on or off for visitors. Properties:
  /// `public`.
  static const visibilityChanged = 'profile_visibility_changed';
}

/// Where a public profile was opened from, for [ProfileEvents.profileViewed].
abstract final class ProfileViewSource {
  static const review = 'review';
  static const search = 'search';
  static const crew = 'crew';
  static const preview = 'preview';
  static const link = 'link';

  /// The credit on a cafe's community photo.
  static const cafePhotos = 'cafe_photos';
}

/// PostHog events for a cafe's community photos (the strip on cafe details
/// and its "See all" grid), sent through `logAppEvent`. Every one carries
/// `cafe_id` and `surface` (one of [CafePhotoSurface]).
abstract final class CafePhotoEvents {
  /// The photos loaded and at least one was shown. Properties: `count`
  /// (all the cafe's photos the viewer may see). Once per screen.
  static const viewed = 'cafe_photos_viewed';

  /// A photo opened full screen. Properties: `position` (0-based).
  static const opened = 'cafe_photo_opened';

  /// A photo's credit opened its author's profile.
  static const authorTapped = 'cafe_photo_author_tapped';

  /// "See all" on the strip.
  static const seeAllTapped = 'cafe_photos_see_all_tapped';

  /// "Add a photo" on a cafe with none yet. Properties: `signed_in`.
  static const addTapped = 'cafe_photo_add_tapped';
}

/// Where a [CafePhotoEvents] event came from.
abstract final class CafePhotoSurface {
  static const strip = 'strip';
  static const grid = 'grid';
  static const viewer = 'viewer';
}
