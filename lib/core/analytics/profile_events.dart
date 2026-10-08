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

  /// A user blocked someone. Properties: `from` (`profile`).
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
}
