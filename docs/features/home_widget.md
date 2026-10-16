# Home-screen widget: "Your saved cafes"

Android only for now. Shows up to three Want to try cafes, open ones first
(nearest first for the first 3 hours after the app wrote, when it had a
position; else newest saved), then closed ones by how soon they open. The
header reads "2 open · 3:10 PM": the count and the time it was drawn.
Package: `home_widget` 0.10.0.

## Pieces

| | File |
|---|---|
| What to show, laid out for a week | `lib/features/home_widget/domain/saved_cafes_widget_data.dart` |
| Writes it on start, resume and every Want to try change | `lib/features/home_widget/presentation/saved_cafes_widget_sync.dart` |
| Draws it and arms its turnovers (RemoteViews; 4×2 = 3 cafes, 2 at large text; 2×2 = count + 1) | `android/app/src/main/kotlin/app/nookph/SavedCafesWidgetProvider.kt`, `res/layout/saved_cafes_widget_*.xml` |
| Taps → app | `lib/features/home_widget/presentation/widget_links.dart`, `widget_link_opener.dart` |
| "Add widget" card on Saved | `lib/features/home_widget/presentation/widgets/home_widget_promo_card.dart`, rules in `domain/widget_promo_rules.dart` |
| Events | `lib/core/analytics/home_widget_events.dart` |

## Data and refresh

The widget cannot run Dart, and "open now" changes while the app is closed.
So the app writes frames for the next 7 days: one at every moment a saved
cafe opens, enters the 30-minute closing-soon window or closes, and at every
Manila midnight. The provider shows the last frame that has started.

Each time the provider draws, it arms one alarm for the next frame's start
(or the payload's end) with `AlarmManager.setWindow(RTC_WAKEUP, t, 10 min)`.
That needs no exact-alarm permission (and Nook must not ask for one: Play
policy does not cover this use), so a turnover lands **within about 10
minutes** of the opening or closing. On the emulator (API 35, clock set to
12:58:30 before a 1 PM opening) `dumpsys alarm` showed `origWhen=13:00
window=+10m`, and the widget turned over at about 13:05, re-arming for the
next frame. Two limits:

- Android 12+ will not make the window shorter than 10 minutes.
- In Doze (screen off, phone still for a while) the alarm can wait for the
  next maintenance window. Nobody is looking at the widget then; the next
  draw shows the right frame.

`updatePeriodMillis` (30 min, the platform minimum) is the safety net, and
the system redraws widgets after a reboot or an app update, which re-arms
the alarm. The plugin's `scheduleWidgetUpdates` is not used: its fallback
without the exact-alarm permission (`setAndAllowWhileIdle`) was measured
landing up to an hour late. Past the 7 days the widget says "Open Nook to
update your cafes" instead of showing hours that may be stale.

Because the count can only be as fresh as the last draw, it carries the
draw time ("2 open · 3:10 PM", "None open · 3:10 PM", in the phone's 12/24 h
format), so it reads as a claim about that moment.

Both sizes are titled "Your saved cafes", the name the launcher and the
"Widget added" toast use. The 2×2 shows the title, the count and the first
cafe (the first open one when any is). At font scales above 1.2 (Android's
"Large" is 1.15) the provider draws `*_large.xml` layouts: the 4×2 shows two
rows instead of three, names ellipsize before status lines, and on both
sizes the count takes the title's place in the header (the title comes back,
as "Saved cafes", only in the empty state). The 2×2's status line may take
three lines. Rows and headers are at least 48dp tall; rows wrap their text,
so if the font grows before the next redraw the last row is cut off rather
than every status line. A font-size change reaches the widget at its next
draw: the next turnover, the 30-minute refresh or the next app start.

Distances come from the position the app already has
(`DeviceLocation.position`); the widget never asks for location. They are
kept only in frames that start within 3 hours of the write
(`SavedCafesWidgetData.distanceFreshFor`): after that the person may be
elsewhere, so the km come off and open cafes go back to newest saved first.
The launcher's preview (`saved_cafes_widget_preview.xml`) shows sample
names and no distances. Signed in,
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

Shown at most twice per phone, 14+ days apart, never once a widget was
added from it, never with a widget already placed or on a launcher that
cannot pin:

- 3+ Want to try: "See your saved cafes on your home screen" / "Your saved
  cafes and when they open, without opening Nook.";
- a real decline of notifications (and 1+ Want to try), once: "Prefer no
  notifications? Add the widget".

For guests the card sits after the first three Want to try rows (or after
the last, for a shorter list); signed in, under the Want to try and Been
cards. A show is **spent only when the card is seen**: half of it on screen
for a second, on the visible tab and route (`OnScreenDetector`).

"Add widget" asks the launcher to place it and hides the card for the
session. On the next resume the app compares the widget count with the one
at the tap (re-reading once after 1.5 s): if it rose, the card is retired and
a toast says "Widget added. Look for “Your saved cafes” on your home
screen."; if not, nothing is said and the remaining show stays. At large
text the two buttons stack, "Add widget" on top.

**What counts as notifications off** (`domain/notification_decline.dart`):
the system "Don't allow" after Nook's own ask, notifications turned off in
Settings after being allowed, notifications on with the "Visits and ratings"
channel muted, or notifications disabled below SDK 33 (where they start on).
On SDK 33+ they start off until the app asks, so "off and never asked" is
unknown and passes `notificationsOff: null`; the saves card shows instead.
The answers come from the visit-reminder service's record of its asks
(`data/visit_reminder_decline.dart`, `VisitReminderService.notificationAnswers`):
a system ask that was never granted, a grant that is now off, or the muted
channel. The pre-prompt's "Just directions" is not a decline: the system
dialog never showed. `decline_kind` on `widget_promo_viewed` is one of
`system_denied`, `settings_off`, `channel_muted`, `sdk_disabled`.

## Events

`lib/core/analytics/home_widget_events.dart`:

| Event | When | Properties |
|---|---|---|
| `widget_promo_shown` | The rules decided to offer the card this session | `reason`, `show` |
| `widget_promo_viewed` | Half the card on screen for 1 s; spends the show | `reason`, `show`, `decline_kind` for `no_notifications` |
| `widget_promo_added` | "Add widget" tapped | `reason` |
| `widget_pin_result` | Next resume after the tap | `result` (`added` / `cancelled` / `unknown`), `reason` |
| `widget_promo_dismissed` | "Not now" | `reason` |
| `widget_installed_count_changed` | Count differs from the last look | `count`, `previous`, `source` (`promo` within 10 min of a tap, else `launcher`; inferred) when it rose |
| `widget_tapped` | The widget opened the app | `target` |

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
