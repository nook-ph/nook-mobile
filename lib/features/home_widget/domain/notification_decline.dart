/// Whether someone really turned Nook's notifications down, for the
/// "Prefer no notifications?" widget card.
///
/// On Android 13+ (SDK 33) notifications start off until the app asks, so
/// "off" alone mostly means "never asked". Only two things count as a
/// decline:
/// - the system "Don't allow" after Nook's own ask
///   ([NotificationDeclineSource.declinedAfterAsk]);
/// - notifications disabled on SDK < 33, where they start on, so off is a
///   choice the person made in Settings.
/// Anything else is unknown, and the widget card falls back to its saves
/// reason.
enum NotificationsState {
  /// Nook may post notifications.
  on,

  /// The system dialog was answered "Don't allow" after Nook asked.
  systemDenied,

  /// Disabled in Settings on SDK < 33.
  sdkDisabled,

  /// Never asked on SDK 33+, or nothing known.
  unknown;

  /// What `WidgetPromoRules.decide` takes as `notificationsOff`: true for a
  /// real decline, false when on, null when unknown.
  bool? get off => switch (this) {
    on => false,
    systemDenied || sdkDisabled => true,
    unknown => null,
  };

  /// `decline_kind` on the promo events, for a decline only.
  String? get declineKind => switch (this) {
    systemDenied => 'system_denied',
    sdkDisabled => 'sdk_disabled',
    _ => null,
  };

  /// Android 13, where POST_NOTIFICATIONS became a runtime permission.
  static const askSdk = 33;

  /// [enabled] is `areNotificationsEnabled()` (null unknown), [sdkInt] the
  /// phone's API level (null unknown), [declinedAfterAsk] from
  /// [NotificationDeclineSource] (null: never asked or not recorded).
  static NotificationsState resolve({
    required int? sdkInt,
    required bool? enabled,
    required bool? declinedAfterAsk,
  }) {
    if (enabled == true) return on;
    // Allowed later in Settings reads as on above; otherwise a recorded
    // "Don't allow" stands.
    if (declinedAfterAsk == true) return systemDenied;
    if (enabled == false && sdkInt != null && sdkInt < askSdk) {
      return sdkDisabled;
    }
    return unknown;
  }
}

/// Where a recorded answer to Nook's own notification ask comes from.
///
/// The ask lives on `retention/local-notifications` (the visit-reminder
/// pre-prompt at Directions, then the system dialog). This branch does not
/// ask, so [UnknownNotificationDecline] is the default and always says
/// "unknown".
///
/// **On merge:** implement this from the visit-reminder service and pass it
/// to `HomeWidgetPromo(declines: ...)`, or make it the default there.
/// A decline is a system ask that was answered without a grant
/// (`systemAsks > 0 && !everGranted`, or `shouldShowRequestPermissionRationale`
/// true after one denial). Do not count the pre-prompt's "Just directions":
/// that is "not now" for one trip, and the system dialog never showed.
abstract class NotificationDeclineSource {
  /// true: "Don't allow" after Nook's ask. false: asked and allowed. null:
  /// never asked, or not known.
  Future<bool?> declinedAfterAsk();
}

class UnknownNotificationDecline implements NotificationDeclineSource {
  const UnknownNotificationDecline();

  @override
  Future<bool?> declinedAfterAsk() async => null;
}
