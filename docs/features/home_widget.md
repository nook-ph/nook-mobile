# Home-screen widget: "Your saved cafes"

Android only for now. Shows up to three Want to try cafes, open ones first
(nearest first when the app has a position, else newest saved), then closed
ones by how soon they open. Package: `home_widget` 0.10.0.

## Pieces

| | File |
|---|---|
| What to show, laid out for a week | `lib/features/home_widget/domain/saved_cafes_widget_data.dart` |
| Writes it on start, resume and every Want to try change | `lib/features/home_widget/presentation/saved_cafes_widget_sync.dart` |
| Draws it (RemoteViews; 4×2 = 3 cafes, 2×2 = 1) | `android/app/src/main/kotlin/app/nookph/SavedCafesWidgetProvider.kt`, `res/layout/saved_cafes_widget_*.xml` |
| Taps → app | `lib/features/home_widget/presentation/widget_links.dart`, `widget_link_opener.dart` |
| "Add widget" card on Saved | `lib/features/home_widget/presentation/widgets/home_widget_promo_card.dart`, rules in `domain/widget_promo_rules.dart` |
| Events | `lib/core/analytics/home_widget_events.dart` |

## Data and refresh

The widget cannot run Dart, and "open now" changes while the app is closed.
So the app writes frames for the next 7 days: one at every moment a saved
cafe opens, enters the 30-minute closing-soon window or closes, and at every
Manila midnight. The provider shows the last frame that has started.
`HomeWidget.scheduleWidgetUpdates` arms an alarm for each frame (inexact:
the app holds no exact-alarm permission, so a turnover can land a few
minutes late), `HomeWidgetScheduledUpdateReceiver` re-arms them after a
reboot or update, and `updatePeriodMillis` (2 h) is the safety net. Past
the 7 days the widget says "Open Nook to update your cafes" instead of
showing hours that may be stale.

Distances come from the position the app already has
(`DeviceLocation.position`); the widget never asks for location. Signed in,
the cafes are the account's Want to try list (`list_cafes` now also selects
`operating_hours`); signed out, the guest saves on the phone.

## Links

`nook://cafe/<id>?via=widget` (a row), `nook://saved?via=widget` (the
header), `nook://home?via=widget` (empty state). Android hands the link to
Flutter as the route, where go_router would read the host as part of the
path, so the router's redirect sends it to `/` and `MainShell` opens it on
top (Back lands on Home). On a cold start, and when the activity is
recreated, the link is read from the plugin instead
(`initiallyLaunchedFromHomeWidget` / `widgetClicked`; `MainActivity`
keeps the new intent). One tap seen twice within 3 s opens once.

## Promo

Shown at most twice per phone, 14+ days apart, never after "Add widget",
never with a widget already placed or on a launcher that cannot pin:

- 3+ Want to try: "See your saved cafes on your home screen";
- notifications off for Nook (and 1+ Want to try), once: "Prefer no
  notifications? Add the widget".

"Notifications off" is `NotificationManagerCompat.areNotificationsEnabled()`.
On Android 13+ that is also false for someone who was never asked, so until
the visit-reminder branch (which asks) lands, most Android 13+ users read as
off. Once it merges, consider keying this to "declined the ask or blocked
the channel" instead.

## iOS: not built

A WidgetKit extension cannot be added compile-safely without Xcode: it is a
new target in `Runner.xcodeproj` (pbxproj), with its own bundle id and
provisioning profile. What it needs:

1. Xcode: File → New → Target → Widget Extension (`NookWidget`), SwiftUI,
   no Live Activity; deployment target matching Runner.
2. An App Group (`group.app.nookph`) on both Runner and the extension, in
   the Apple Developer account and both entitlements files.
3. `HomeWidget.setAppGroupId('group.app.nookph')` before the first write,
   and make `HomeWidgetPluginPlatform.isSupported` true on iOS (with
   `iOSName: 'NookWidget'` on `updateWidget`).
4. A `TimelineProvider` that reads `saved_cafes_v1` from
   `UserDefaults(suiteName:)` and returns one `TimelineEntry` per frame
   (`t` is the entry date), policy `.after(until)`: the same frames, so no
   scheduling is needed on iOS.
5. `.widgetURL` / `Link` with the same `nook://…?via=widget` links, and
   `nook` as a URL scheme in `Info.plist` so taps open the app.
6. iOS has no pin API, so the promo would need a how-to sheet instead of
   "Add widget"; until then `canPin()` keeps it hidden on iOS.
