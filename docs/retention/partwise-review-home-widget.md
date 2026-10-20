# Partwise review: home-screen widget "Your saved cafes" and its Saved-tab promo

Job: **review** (mode ios, Flutter Android-first, Material controls; target code). This review reports only. Nothing in `lib/` or `android/` was changed.
Branch `retention/home-widget`, commits `088d162..cfe0024`.

Looked at: Android emulator `Nook_Review_A` (emulator-5558, API 35, Pixel launcher, 1080x2400), debug x64 build, real `.env`. The test user was a signed-out guest with 4 Want to try saves: Steeped Beans (Sibonga, opens 1 PM), Cafe Julio (open until 10 PM), Brew Szn (opens 2 PM) and Flavour Coffee Station (open until 10 PM). Clock: Manila, 10:13 AM on Fri 16 Oct 2026. Both widget sizes were placed from the launcher's widget picker. The 2×2 is the 4×2 resized.

| State | Shot (`review-shots-home-widget/`) |
|---|---|
| Widget picker preview | `01_picker.jpg` |
| Empty, 4×2 / 2×2 | `02_empty_4x2.jpg`, `03_empty_2x2.jpg` |
| 4 saves, 4×2 / 2×2 | `04_4x2_light.jpg`, `05_2x2_light.jpg` |
| Tap a row on a cold start: opens details, Back lands on Home | `06_tap_row_cold.jpg` |
| Clock set to 12:59:30, then 13:00 and 13:07 | `07_turnover_1259.jpg`, `08_turnover_1300_not_updated.jpg`, `09_turnover_1307_still_stale.jpg` |
| Night mode | `10_4x2_dark.jpg`, `11_2x2_dark.jpg` |
| Font scale 2.0 | `12_4x2_font2.jpg`, `13_2x2_font2.jpg` |
| Promo, notifications never asked (API 35) | `14_promo_no_notifications.jpg` |
| "Add widget" opens the launcher dialog | `15_pin_dialog.jpg` |
| Promo, saves variant (after granting notifications) | `16_promo_saves.jpg` |
| Promo at font scale 2.0 | `17_promo_font2.jpg` |

Not seen on the device:
- **Distances.** The emulator's GPS provider never delivered a fix to `DeviceLocation`, so no row showed "· 1.2 km". Distance handling was checked in source only.
- **The stale state** ("Open Nook to update your cafes", 7 days on). Checked in source only.

The clock was restored to real time afterwards. The promo history in `FlutterSharedPreferences` was edited once on the device so that the second variant would show.

---

## Widget, 4×2   Looked at: emulator

### Must fix

1. **"Open now" is wrong for up to an hour after a turnover.**
   - **What happened:** The clock was set to 12:59:30. Steeped Beans opens at 1 PM. At 13:00 and again at 13:07 the widget still said "Opens 1 PM" and "2 open now" (`08`, `09`).
   - **Why:** `dumpsys alarm` shows the scheduled update as `RTC_WAKEUP origWhen=13:00:00 window=+1h0m0s`, with `maxWhenElapsed` 52 minutes later. The plugin's inexact path (`setAndAllowWhileIdle`) lets the system defer the alarm by up to an hour. The 2-hour `updatePeriodMillis` safety net is wider still.
   - **What users see:** Each row's line names a time, so a careful reader can work it out. The header count does not: it states "2 open now" with no time attached. The same lag hits closings: a cafe that closed at 10 PM can still read "Closes soon · 10 PM" at 10:50 PM.
   - **Who is affected:** The doc says "a few minutes late", which undersells it. With no exact-alarm permission, every user gets this.
   - **Fix, in order:**
     - (a) Arm each turnover with `AlarmManager.setWindow(RTC_WAKEUP, t, 10 * 60_000, pi)`. It needs no permission and keeps the window to about 10 minutes. This means a small Kotlin scheduler in `SavedCafesWidgetProvider`'s package, or a patch to `HomeWidgetScheduler.armNext`.
     - (b) Lower `updatePeriodMillis` in `res/xml/saved_cafes_widget_info.xml` to `1800000` (30 minutes, the platform minimum).
     - (c) Do not request `SCHEDULE_EXACT_ALARM` or `USE_EXACT_ALARM`. Play policy does not cover this use.
     - (d) Correct the "a few minutes late" line in `docs/features/home_widget.md`.

2. **At font scale 2.0 the status lines are cut in half** (`12`).
   - **What happened:** All three rows show the name, then the top half of "Open until 10 PM". The header title truncates to "Your saved caf…".
   - **Why:** The rows are `layout_weight=1` slices of a fixed widget height, and the text is in `sp`.
   - **Fix:** Give `saved_cafes_widget_medium.xml` a large-text variant that shows two rows, plus a provider check on `resources.configuration.fontScale >= 1.3`. Alternatively, drop the separate status line at large scales and put "Cafe Julio · until 10 PM" on one line. The status line matters more than the name's second word. If a row must lose something, ellipsize the name, never the status.

### Should fix

3. **Distances freeze for a week.** `_write()` computes `distanceMeters` once from the position at write time. All frames for the next 7 days carry that "· 1.2 km" and sort open cafes nearest-first by it. Someone who saved cafes in Cebu City and then spends the week in Lapu-Lapu sees the wrong "nearest" and wrong km until they next open Nook. Fix in `SavedCafesWidgetData.build`: keep distances only in frames that start within about 3 hours of `generatedAt`. After that, drop the " · km" suffix and fall back to newest-saved order. Or drop distance from the widget entirely; the hours are what it is for.

4. **The header tap target is 32dp** (`android:minHeight="32dp"` on `@id/header`, both layouts). It opens Saved, so it is a real control, and 32dp is below 48dp. Raise it to `48dp` and take the space from the medium layout's 14dp root padding. Or let the whole top band, including the padding, take the tap by moving the click to a wrapper that spans it.

### Could be better

5. **The picker description promises something narrower than the widget shows.** "Your Want to try cafes that are open now" (`saved_cafes_widget_description`, `01`), but the widget also lists closed cafes with their opening times. Say "Your Want to try cafes and when they're open".

### Working well

- The empty state names what belongs there and offers the action: "Save cafes to see them here" / "Find a cafe" (`02`). Night mode is a real dark version, not an inversion (`10`). The derived colors pass: muted 7.0:1, brand 7.3:1 on `#18201B`. In light mode, muted `#767574` is 4.56:1 and the brand header is 9.0:1.
- Taps work cold and warm. A row opens the cafe's details, and Back lands on Home, not on the launcher (`06`). The words always carry the status, so the dot's color is extra, not the only signal.

```text
Screen: Widget 4×2          Looked at: rendered (emulator)
Foundations   Typography 2 · Grids 2 · Color 2 · Communication 2
Structure     Proportion 2 · Clarity 2 · Precision 2 · Order 1
Behavior      Affordance 1 · Motion n/a · Efficiency 2 · Restraint 2
Impact        Visuals 2 · Universal 1 · Accessibility 0 · Responsibility 0
Total 23/30 (15 scored)

Fix
- Responsibility 0: alarm window up to 1 h, so "2 open now" is false after an opening or closing. Use setWindow at 10 min and updatePeriodMillis 30 min (finding 1).
- Accessibility 0: status lines clipped at 2.0. Add a large-text layout with 2 rows (finding 2).
- Universal 1: distance frozen for 7 days (finding 3).
- Affordance 1: 32dp header target (finding 4).
- Order 1: widget colors are hex copies of app tokens, and the dark set has no source in the app (documented in values-night). Fine for now. Move them to the design file when dark tokens exist.
```

---

## Widget, 2×2   Looked at: emulator

### Must fix

- The same turnover lag as finding 1. This size has no count, so only the row line is stale.

### Should fix

6. **The small size shows one cafe and leaves about 60% of the tile blank** (`05`, `11`). It also drops the "N open now" count, which is the one thing a glance needs. In `saved_cafes_widget_small.xml`, show two rows with single-line names. At large text, keep one row (it wraps cleanly at 2.0, `13`). Or keep one row and add the count under it: "+1 more open".

### Could be better

7. **The two sizes have two titles.** The small one says "Want to try" (`saved_cafes_widget_title_small`) and the medium one says "Your saved cafes". These are the same thing with two names. "Saved cafes" fits at 2×2.

```text
Screen: Widget 2×2          Looked at: rendered (emulator)
Foundations   Typography 2 · Grids 2 · Color 2 · Communication 1
Structure     Proportion 1 · Clarity 1 · Precision 2 · Order 1
Behavior      Affordance 1 · Motion n/a · Efficiency 1 · Restraint 2
Impact        Visuals 2 · Universal 1 · Accessibility 2 · Responsibility 0
Total 21/30 (15 scored)

Fix
- Responsibility 0: turnover lag (finding 1).
- Communication 1 / Proportion 1 / Efficiency 1: one row in a 2×2 tile with no count (finding 6).
- Clarity 1: "Want to try" vs "Your saved cafes" (finding 7).
- Affordance 1, Universal 1, Order 1: as on the 4×2.
```

---

## Saved tab: "Add widget" promo card   Looked at: emulator

### Must fix

8. **"Prefer no notifications?" is said to people who never turned anything off** (`14`).
   - **What happened:** On a fresh API 35 install, Nook has never asked for notifications, so `areNotificationsEnabled()` is false. This variant was the first card shown. Its title presumes a choice the person never made. It also takes one of the two lifetime shows and pre-empts the stronger "See your saved cafes on your home screen" card.
   - **Who sees it:** The doc notes that most Android 13+ users read as "off" today, so most users would see this.
   - **Fix:** In `WidgetPromoRules.decide`, use the `noNotifications` reason only when the "off" is a real choice:
     - SDK < 33 and notifications disabled; or
     - the app's own permission request was answered "Don't allow". Record that when the visit-reminder ask lands. `shouldShowRequestPermissionRationale` is true after one denial.
   - **Until then:** Pass `notificationsOff: null` on SDK 33+, which the rules already treat as "unknown", so the saves card shows instead.

### Should fix

9. **Cancelling the launcher dialog throws the card away for good.** `_add()` calls `markAdded()` before `requestPin()`. After a Cancel in the launcher's "Add to home screen" dialog (`15`), `widget_promo_added` was already `true` on the device, and the card is never offered again. Nothing confirms success either. Fix: treat the tap as an ordinary show. On the next resume, if `installedCount()` went from 0 to 1 or more, mark added and show a one-line SnackBar: "Widget added to your home screen". The rules already hide the card while a widget is placed.

10. **The buttons go uneven at font scale 2.0.** "Add widget" wraps to two lines and grows taller than "Not now" (`17`). In `_PromoButton`, give both the same height. When the scaled labels will not fit side by side, stack them full width with "Add widget" on top (a `LayoutBuilder` check, or `Wrap` with each button full width).

### Could be better

- The body says "Which ones are open now, without opening Nook." That is true only once finding 1 is fixed. Until then, "Your saved cafes and when they open" (the other variant's line) is the safer promise.

### Working well

- The preview uses the person's own cafes with live dots ("Cafe Julio", "Flavour C…"), not a stock picture (`16`). That is the most persuasive thing on the card. The inner radius is worked out from the outer radius (12 − 8 = 4). The preview is kept out of the screen-reader order.
- The caps are respectful: at most two shows, 14 days apart, none while a widget is placed, none on a launcher that cannot pin. "Not now" closes the card without asking again in the same session.

```text
Screen: Saved-tab promo      Looked at: rendered (emulator)
Foundations   Typography 2 · Grids 2 · Color 2 · Communication 2
Structure     Proportion 2 · Clarity 2 · Precision 2 · Order 2
Behavior      Affordance 1 · Motion n/a · Efficiency 2 · Restraint 2
Impact        Visuals 2 · Universal 1 · Accessibility 1 · Responsibility 0
Total 25/30 (15 scored)

Fix
- Responsibility 0: notifications-off premise false on Android 13+ when never asked (finding 8).
- Affordance 1: Cancel = never again, no success feedback (finding 9).
- Universal 1 / Accessibility 1: uneven, wrapped buttons at 2.0 (finding 10).
```

---

## Found, left alone

- One widget tap right after `am force-stop` did not open the app. The next tap, also a cold start, did. This did not happen again. It may be the launcher swallowing the first tap after a reset, so it is not a finding.
- The launcher's pin dialog shows the preview layout's sample cafes with made-up distances ("A cafe you saved · 1.2 km", `15`). This is normal for a preview. Swap the km for no distance if it should not look like real data.
