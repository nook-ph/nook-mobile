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

/// PostHog events for a cafe's "Latest cups" stories (the tray on cafe
/// details and its full-screen viewer), sent through `logAppEvent`. Every
/// one carries `cafe_id`.
abstract final class CafeStoryEvents {
  /// The viewer opened from the tray. Properties: `story_position`
  /// (0-based, which person was tapped), `story_count`, `unseen` (whether
  /// that person had anything new).
  static const opened = 'cafe_stories_opened';

  /// A photo shown in the viewer. Properties: `photo_id`,
  /// `story_position`, `photo_position`.
  static const viewed = 'cafe_story_viewed';

  /// The poster tapped in the viewer. Properties: `photo_id`.
  static const authorTapped = 'cafe_story_author_tapped';

  /// Played past the last photo of the last person. Properties:
  /// `story_count`.
  static const completed = 'cafe_stories_completed';
}

/// PostHog events for Cups (reviews and the gallery as one card per person
/// per cafe), sent through `logAppEvent`. Every one carries `cafe_id` when
/// there is a cafe.
abstract final class CupEvents {
  /// The composer opened. Properties: `source` (one of [CupSource]),
  /// `editing` (you already had a cup there), `backend` (`cups` or
  /// `legacy`).
  static const composerOpened = 'cup_composer_opened';

  /// A cup was posted or edited. Properties: `has_photo`, `has_note`,
  /// `has_rating`, `photo_count` (new photos), `created`, `marked_been`,
  /// `source`, `backend`.
  static const posted = 'cup_posted';

  /// Your cup was deleted. Properties: `backend`.
  static const deleted = 'cup_deleted';

  /// Helpful toggled on someone else's cup. Properties: `voted`,
  /// `target` (`cup` or `review`).
  static const helpfulToggled = 'cup_helpful_toggled';

  /// A cup was reported. Properties: `reason`, `target` (`cup`, `review`
  /// or `photos`).
  static const reported = 'cup_reported';

  /// "Rank it" on the posted toast, opening the ranking flow for the cafe.
  static const rankItTapped = 'cup_rank_it_tapped';
}

/// Sharing your own cup as a story image (docs/features/share_cup_story.md
/// §1).
abstract final class CupShareEvents {
  /// The cup share sheet opened. Properties: `cafe_id`, `cup_id`, `entry`
  /// (one of [CupShareEntry]), `has_photo`, `photo_count`, `layout`
  /// (`photo` or `note`).
  static const opened = 'cup_share_opened';

  /// A target was handed the image or link. Properties: `cafe_id`,
  /// `cup_id`, `entry`, `target` (`system`, `overlay` for the transparent
  /// PNG, `copy_link`), `result` (the share sheet's status: on Android
  /// `success` means a target was picked, not sent), `layout`,
  /// `photo_source` (`cup`, `device` or `none`), `photo_index`,
  /// `has_handle`.
  static const shared = 'cup_shared';

  /// Rendering or sharing failed. Properties: `stage` (`render`,
  /// `write_file`), `target`, `error` (exception type only).
  static const failed = 'cup_share_failed';

  /// The cafe's @handle was copied. Properties: `cafe_id`, `entry`
  /// (`share_sheet`).
  static const handleCopied = 'cafe_handle_copied';
}

/// Where the cup share sheet was opened from, for [CupShareEvents].
abstract final class CupShareEntry {
  static const postedToast = 'posted_toast';
  static const cupMenu = 'cup_menu';
  static const storyViewer = 'story_viewer';
  static const profile = 'profile';
}

/// Where the cup composer was opened from, for [CupEvents].
abstract final class CupSource {
  static const cafeSection = 'cafe_section';
  static const cupsPage = 'cups_page';
  static const storiesTray = 'stories_tray';
  static const emptyState = 'empty_state';
  static const rankReveal = 'rank_reveal';
  static const visitBlock = 'visit_block';
  static const profile = 'profile';
  static const guestReturn = 'guest_return';
}
