# Partwise review: local notifications (visit reminders)

Job: **review** (mode ios, Flutter Android-first with Material controls; target code). Reports only, no code changed.
Build: `retention/local-notifications` at `f551bd9` (commits `4259800..f551bd9`).
Looked at: Android emulator Pixel 7 API 35 (emulator-5554), debug build with
`--dart-define=VISIT_REMINDER_DELAY_SECONDS=60`, guest (signed out), app data cleared before each run,
time zone set to America/Chicago so local time (15:05) fell inside 09:00–21:00, Asia/Manila restored after.
One batch at font scale 1.0, one at 2.0. Dark mode n/a (app ships one light theme).
Screens in `review-shots-local-notifications/`.

What I checked on the device:
- Directions, then back to the cafe page: the pre-prompt appears; Turn on, system dialog, Allow; the notification arrived about 60 s after the tap.
- Rate it as a guest: the cafe page opens and the cafe is marked Been. **No rating happens.**
- Didn't go dismisses the notification and gives no other feedback, which is fine.
- First guest save shows the sign-in toast and no ask (by design). The second save shows "Want visit reminders?".
- Settings: Not asked, deny once (the switch flips back with no message), deny twice (Blocked plus Open settings), Open settings goes to the app's notification page, turning it on there shows the switch On when I come back.

Checked from source only (not visible in a screenshot): the 90-minute timing, deferral and the daily cap (`visit_reminder_rules.dart`), whether the OS permission is checked per app or per channel (`local_notifier.dart:172`), and the contrast of the muted token (`profile_tokens.dart:9`).

---

## Ranked findings

### Must fix (the copy promises what the phone does not deliver)

1. **A guest cannot rate, but every surface says they will.** The Directions sheet says "so you can rate it while it is fresh". The save sheet says "so you can rate it". The Settings detail says "A reminder to rate a cafe". The notification says "Tap to rate your visit" / "Rate it". On the device, a guest who taps Rate it gets Been marked silently and the toast "Saved on this phone. Sign in to keep it everywhere." (shot 09). Ranking or rating needs an account (`cafe_status_pills.dart` `_rateFromReminder`). The sheet is only reachable signed out (guest flow) or signed in, so most people who see this ask today are guests, and the core promise is false for them.
   Fix: pick the words by session. For a guest, the sheet says "Want a reminder to mark Three Two Brew as Been after your visit?" and the notification says "How was Three Two Brew?" / "Mark it Been", with the action labelled "I went" or "Mark Been". Or keep "rate" and have Rate it open the sign-in sheet with "Sign in to rate it", keeping the Been mark. Whichever you pick, the sheet, the Settings detail and the notification must use one verb.

2. **"In about 90 minutes" is often wrong.** The delay counts from the Directions *tap* (`requestPermission` schedules from `trip.at`), but the sheet appears when the person comes back, up to 60 minutes later, so the notification can arrive about 30 minutes after "Turn on". Taps after 19:30 are moved to 10:00 the next day. The daily cap can skip it, or a later tap can replace it (`plan`). None of this shows in the sheet or the Settings detail. In a release build this is the whole promise.
   Fix: make the sheet say what was actually scheduled. Work out `fireAt` before showing the sheet and say "We'll send one notification around 4:35 PM" or "…tomorrow at 10 AM". If no reminder can be scheduled (outside the window or capped), do not show the Directions ask at all. Settings detail: "A reminder to rate a cafe after you get directions to it, between 9 AM and 9 PM."

3. **It asks about, and reminds about, cafes that are closed.** I tapped Directions on Three Two Brew, shown as "Closed · opens 8 AM", and still got the ask and then "How was Three Two Brew?" (shots 05, 08). In Manila at 04:00 every cafe I saw was Closed. "How was it?" about a visit that could not have happened is the first thing that will make someone tap "Don't allow" or turn notifications off for good.
   Fix: in `onDirections`/`afterDirections`, skip (new `ReminderSkipReason.closed`) when the cafe is closed at the tap and does not open before `fireAt`. The details page already has the hours.

### Should fix

4. **Settings says On when the reminders channel is muted.** `areEnabled()` reads the app-level switch (`areNotificationsEnabled`), not the "Visits and ratings" channel. Someone who mutes only that channel in Android settings sees "Visit reminders: On" while nothing arrives.
   Fix: on Android, also read the channel's importance (`getNotificationChannels`, importance none = blocked) and show the existing blocked state with Open settings.

5. **No confirmation after Turn on → Allow.** The sheet closes and the page looks exactly as before (shot 07). The person cannot tell whether a reminder is set or when.
   Fix: one toast after the grant: "Reminder set for around 4:35 PM", with the time from finding 2. After a grant from the save ask: "Visit reminders on. Turn them off in Settings."

6. **Denying from Settings flips the switch back with no word** (shot 15). On the first refusal nothing changes. On the second the blocked text appears.
   Fix: after a refused request in `_setReminders`, show "Notifications stay off. You can allow them in your phone's settings." The blocked row already covers later visits.

7. **"Turn on" doesn't name a result, and the save ask doesn't fit the moment.** "Turn on" sits under a question about a reminder for one cafe. "Remind me" answers the question. The save sheet appears right after "Want to try" but talks about Directions, a different action the person has not taken.
   Fix: Directions sheet primary is "Remind me". Save sheet primary is "Turn on reminders". The save sheet reason leads with the saved cafe: "When you head to a cafe you saved, Nook can remind you to rate it after."

### Could be better

8. **Muted text fails contrast.** `ProfileTokens.muted` `#868584` on white is about 3.7:1. That is under 4.5:1 for the 14 sp sheet reason and the 12 sp Settings detail and blocked text, which carry the promise and the blocked explanation. Keep the token here and report it. The token owner should darken it to about `#6F6E6C` (4.9:1).
9. **The notification body and the tap do different things.** The body says "Tap to rate your visit", but a body tap only opens the cafe. Only the Rate it button marks Been. Make the body descriptive ("You were heading there about 90 minutes ago") or make a body tap behave like Rate it.
10. **Settings is reachable only from the Saved tab gear for guests.** The guest Profile tab is the expected home, and "Turn it off any time in Settings" assumes people can find it. Add the same gear, or a Settings row, to the guest Profile tab.
11. **Visit reminders sits under "Permissions".** It is a feature preference. Location next to it is a pure OS permission row with a value and chevron, and the two blocked states look different (value text versus a disabled switch plus a link). Move it to a "Notifications" group so later channels have somewhere to go.

### Working well
- **The ask is restrained and well timed.** It is capped at 3 ever, 7 or more days apart, never after the one-time sign-in toast, never on top of another route, and only within 60 minutes of Directions. Not now is as easy as Turn on. Keep this.
- **The blocked Settings state is honest and recovers.** It says plainly that the phone has notifications off, Open settings lands on Nook's notification page, and the switch catches up when the app resumes (shots 16–18).
- **It holds up at font scale 2.0** with nothing clipped (shots 19, 20, 22).
- **The notification is quiet and correct**: default importance, an inexact alarm, one channel with a clear name, two actions, and auto-cancel.

---

## Scorecard

```text
Screen: Pre-prompt after Directions      Looked at: rendered (emulator, 1.0 + 2.0)
Foundations   Typography 2 · Grids 2 · Color 1 · Communication 2
Structure     Proportion 2 · Clarity 1 · Precision 2 · Order 2
Behavior      Affordance 1 · Motion 2 · Efficiency 2 · Restraint 2
Impact        Visuals 2 · Universal 1 · Accessibility 1 · Responsibility 0
Total 25/32 (16 scored)

Fix
- Responsibility 0: guest can't rate; "about 90 minutes" counts from the tap and ignores deferral and caps; asks for closed cafes (findings 1–3)
- Clarity 1: "Turn on" names no result; no confirmation of when (5, 7)
- Affordance 1: no feedback after the grant (5)
- Color 1 / Accessibility 1: muted reason text 3.7:1 (8)
- Universal 1: copy gives a duration and ignores the 09–21 window and next-day deferral (2)
```

```text
Screen: Pre-prompt after save            Looked at: rendered (emulator, 1.0)
Foundations   Typography 2 · Grids 2 · Color 1 · Communication 1
Structure     Proportion 2 · Clarity 1 · Precision 2 · Order 2
Behavior      Affordance 1 · Motion 2 · Efficiency 2 · Restraint 2
Impact        Visuals 2 · Universal 2 · Accessibility 1 · Responsibility 1
Total 26/32 (16 scored)

Fix
- Responsibility 1: "so you can rate it" is false for guests (1)
- Communication 1 / Clarity 1: talks about Directions right after a save; "Turn on" (7)
- Affordance 1: no confirmation after grant (5)
- Color 1 / Accessibility 1: muted contrast (8)
```

```text
Screen: Notification "How was [cafe]?"   Looked at: rendered (shade, 1.0 + 2.0)
Foundations   Typography n/a · Grids n/a · Color n/a · Communication 2
Structure     Proportion n/a · Clarity 1 · Precision n/a · Order 2
Behavior      Affordance 1 · Motion n/a · Efficiency 2 · Restraint 2
Impact        Visuals 2 · Universal 2 · Accessibility 2 · Responsibility 0
Total 16/20 (10 scored)

Fix
- Responsibility 0: "Rate it" / "Tap to rate" marks Been for guests, no rating; fires for closed cafes (1, 3)
- Clarity 1 / Affordance 1: body says "Tap to rate" but a body tap only opens the page (9)
```

```text
Screen: Settings "Visit reminders" row (not asked / on / blocked)   Looked at: rendered (1.0 + 2.0)
Foundations   Typography 2 · Grids 2 · Color 1 · Communication 2
Structure     Proportion 2 · Clarity 1 · Precision 2 · Order 1
Behavior      Affordance 1 · Motion n/a · Efficiency 2 · Restraint 2
Impact        Visuals 2 · Universal 2 · Accessibility 1 · Responsibility 1
Total 24/30 (15 scored)

Fix
- Responsibility 1: On while the channel is muted; "about 90 minutes" (2, 4)
- Affordance 1: silent revert after a refusal (6)
- Clarity 1: detail promises a rating guests can't do (1)
- Order 1: under "Permissions"; blocked state shaped unlike Location's (11)
- Color 1 / Accessibility 1: 12 sp muted detail at 3.7:1 (8)
```

**Totals: 91/114 across the four surfaces (57 principles scored).** Responsibility is the weak group: 0, 1, 0, 1.

## Shots
| File | What |
|---|---|
| 03-cafe-details.jpg | Cafe page before Directions; cafe shown Closed |
| 05-preprompt-directions.jpg | Ask after coming back from Maps |
| 06-system-dialog.jpg | Android 13+ permission dialog after Turn on |
| 07-after-allow.jpg | After Allow: no confirmation |
| 08-notification-shade.jpg | "How was Three Two Brew?" with Rate it / Didn't go |
| 09-rate-it-guest.jpg | Guest Rate it: Been marked, sign-in toast, no rating |
| 10-save-toast*.jpg, 11-preprompt-save.jpg | First save (sign-in toast, no ask), then the save ask |
| 12-guest-saved-gear.jpg | Guest Saved tab gear |
| 13–18 | Settings: not asked, system dialog, denied once (silent), blocked, Android target page, on after return |
| 19, 20, 22 | Font scale 2.0: Directions ask, notification, Settings |
| 21-didnt-go.jpg | After Didn't go |
