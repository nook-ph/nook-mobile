# Visit reminders (local notifications) · UX research (2026-10-16)

Job: **ux** (research only; no design, no code). Build: `retention/local-notifications` at `b65e185`.
Builds on `partwise-review-local-notifications.md` (the review) and its shots in
`review-shots-local-notifications/`. This is desk research and expert evaluation: the review's
device walk, the source in `lib/features/visit_reminders/` and `cafe_status_pills.dart`, three
Refero flows per journey, and the static teardowns of Too Good To Go, Google Maps, Pinterest and
Duolingo (`nook-marketing/.../research/2026-10-retention/teardowns/`). No user said or did any of
this; what needs real people is in the last section.

## Question

```text
Question: How should the one post-visit notification be asked for, timed and acted on so that
          a person who got directions to a cafe ends up with that cafe marked and rated, and
          never feels Nook asked about a visit that didn't happen?
Product:  cafe discovery / place saving, like Google Maps, Beli, Too Good To Go, Mapstr
People:   Cebu cafe-goers on Android phones, mostly guests (~150 installs, few accounts).
          "When I've just been to a cafe I found on Nook, I want to note how it was in a
          second, so my list remembers it for me."
Journeys: 1. Directions → asked about reminders → allow → visit → reminder → rate / mark Been /
             didn't go (guest and signed in)
          2. Save a cafe → asked about reminders → decide
          3. Change your mind later in Settings (turn off, blocked, re-enable)
Evidence: review walk on emulator (guest, 60 s debug delay), source, teardowns, Refero.
          Analytics: events exist in code (`notification_events.dart`) but this branch is not
          released, so there is no funnel. No numbers are estimated here.
```

## Journeys today

Scores are single-rater, 1 easy, 2 noticeable effort, 3 hard enough to give up. "Walkthrough"
names the cognitive-walkthrough question that fails: Q1 will they try, Q2 will they notice,
Q3 will they connect it to their goal, Q4 will they see it worked.

### 1a. Directions → reminder → rate (guest) — score 15

| # | Step | Score | Walkthrough / note |
|---|---|---|---|
| 1 | Cafe page, tap Directions; Maps opens. Nook remembers the trip **in memory only** (`_lastTrip`). | 1 | |
| 2 | Come back to Nook, to the same cafe page, within 60 min. Only then can the ask show. | 3 | Q1: a person driving or walking to the cafe is in Maps, not Nook. If Android kills Nook meanwhile, the trip is gone. |
| 3 | Sheet "Want a reminder to rate Three Two Brew after your visit?" · "about 90 minutes" · Turn on / Not now (shot 05). | 2 | Q3: "Turn on" names no result. The time is wrong when the return was late, after 19:30, or capped. Shown for a Closed cafe. |
| 4 | Android dialog, Allow (06). | 1 | |
| 5 | Sheet closes; page unchanged (07). | 2 | Q4: nothing says a reminder is set, or when. |
| 6 | Notification "How was Three Two Brew? / Tap to rate your visit" · Rate it / Didn't go (08). | 2 | Can arrive ~30 min after Turn on, next morning, or for a closed cafe. |
| 7 | Rate it → cafe page, Been marked, toast "Saved on this phone. Sign in to keep it everywhere." (09). | 3 | Q4 fails: no rating, the promise of steps 3 and 6 is broken. |
| 7′ | Didn't go → notification gone, nothing else (21). | 1 | Fine; Nook learns nothing from it but an event. |

### 1b. Same, signed in (from code) — score 16, completes

Steps 1-6 as above. Then:

| # | Step | Score | Note |
|---|---|---|---|
| 7 | Rate it → cafe page; Been is written; the ranking sheet opens at "How was Three Two Brew?" with Liked it / It was fine / Not for me (`cafe_ranking_flow.dart`). | 2 | The notification already asked "How was it?"; the answer is asked again in the app. |
| 8 | "Which did you like more?" comparisons against own Been cafes. | 2 | Optional, skippable. |
| 9 | Saving, then the score reveal. | 1 | Good closure (peak-end). |

A body tap (not Rate it) only opens the page: Been is not marked and no sheet opens, although the
body says "Tap to rate your visit".

### 2. Save → ask → decide — guest 7, signed in 6

| # | Step | Score | Note |
|---|---|---|---|
| 1 | Want to try. Guest first save: sign-in toast, no ask (10). | 1 | Right: one ask at a time. |
| 2 | Guest second save (signed in: first save); after 1.5 s, "Want visit reminders? When you get directions to a cafe, Nook sends one reminder afterwards so you can rate it." (11). | 3 | Q3: the person just saved a cafe; the sheet talks about Directions, which they did not do. Guests can't rate. |
| 3 | Turn on → dialog → Allow. | 1 | |
| 4 | Sheet closes, nothing confirms. | 2 | Q4. |

### 3. Settings: off, blocked, on again — guest 12, signed in 10

| # | Step | Score | Note |
|---|---|---|---|
| 1 | Find Settings. Guest: gear on the Saved tab only (12). Signed in: Profile. | 3 guest / 1 | Q2 for guests: the Profile tab is where people look. |
| 2 | Row "Visit reminders · A reminder to rate a cafe about 90 minutes after you get directions to it" under **Permissions** (13). | 2 | "Not asked" and "turned off" both show the same Off switch. |
| 3 | Flip on → system dialog directly (14). Deny → switch flips back with no word (15). | 2 | Q4. |
| 4 | Second denial → greyed switch, "Notifications for Nook are off in your phone's settings." · Open settings (16) → Android app page (17) → back, On (18). | 2 | Works. Honest, recovers. |
| 5 | Mute only the "Visits and ratings" channel in Android → Settings still says On. | 3 | Code (`areEnabled` is app-level). Nothing arrives, nothing explains. |

States: loading n/a (local), offline n/a for scheduling; offline at "Rate it" signed in shows
"Couldn't update. Please try again." (code). Undo after turning reminders off: not needed, the
switch is its own undo.

## How others do it

Refero has no Google Maps, Uber, Grab, Airbnb, TGTG or Duolingo flows for these journeys and
no Android notification screens. Where Refero is thin, the teardowns (static APK analysis, exact
strings) fill in; they are labelled.

### Journey 1: post-visit prompt
- **Drinkit** (coffee ordering, [flow 11014](https://refero.design/flows/11014)): "Order ready.
  All good?" with Yes / No tiles. One tap records; item and store chips, then free text, are
  optional deeper steps; ends on "Thanks for the review!".
- **Instagram call rating** ([flow 2886](https://refero.design/flows/2886)): a persistent
  "call ended" card; tap it, tap a star, done. The star is the submit. Two taps.
- **District** (events, [flow 12916](https://refero.design/flows/12916)): "How was your
  experience?" for a named event with its poster; Not good / Liked it, then aspect thumbs and
  text revealed only after; explicit Submit.
- Teardowns: **Google Maps** puts 5 stars and a reply in the notification itself, and
  "Didn't go here" turns a wrong guess into a correction ("Pick the place you visited").
  **Too Good To Go** sends one local "How was your experience at [store]?" 90 min after
  *pickup* (a known event), moved to the next day outside a window.

**Pattern:** the first control is one low-effort answer that counts on its own; detail is
optional and comes after. The thing being rated is named and pictured. **Split:** whether the
first tap submits (Instagram, Maps: yes; District: no). None of the Refero flows handles "didn't
go"; only Google Maps does, because only it guesses visits the way Nook does.

### Journey 2: pre-permission ask
- **Apple Podcasts** ([flow 5543](https://refero.design/flows/5543)): Follow → "Get Notified About
  New Episodes" · Enable Notifications / Not Now → iOS dialog → follow checkmark.
- **TIDAL** ([flow 13129](https://refero.design/flows/13129)): Follow → small sheet with the
  artist's photo, "Get notified about your favorite artists' new releases" · Notify me / Not now.
- **CapWords** ([flow 6122](https://refero.design/flows/6122)): no explainer; the person picks a
  reminder time, flips the toggle, then the system dialog. Confirmation is the time on the row.
- Also: **Fuse** ([flow 8731](https://refero.design/flows/8731)) is the only one with a
  "Notifications enabled" toast. Teardowns: **Pinterest** asks after a save with a promise about
  *that* save ("Want to be notified with more Pins like this?"); **Duolingo** caps asks at ~3 per
  context, 7+ days apart, with "Continue without reminders".

**Pattern:** the ask is tied to the action just taken and promises more of *that thing*; two
choices; the original action completes either way. **Split:** explainer sheet (Podcasts, TIDAL)
vs the setting as the ask (CapWords); a concrete time (CapWords) vs a content type (others).

### Journey 3: settings
- **Joi** ([flow 4388](https://refero.design/flows/4388)): one row per type, with the timing on
  the row ("15 min before") and a toggle; changes apply at once.
- **Lumy** ([flow 6168](https://refero.design/flows/6168)): when the OS blocks what it needs, a
  persistent card says exactly what is off and why, with Open Settings, until fixed.
- **222** ([flow 9326](https://refero.design/flows/9326)): rows named by what is sent ("invites"),
  value shown on the row.
- Teardowns: TGTG, Google Maps and Pinterest all group by **what is sent**, under a
  Notifications heading, one channel per kind.

**Pattern:** a flat list of kinds, each showing its current value and what or when it sends.
**Split:** only Lumy handles an OS block explicitly; none shows signed-out Settings.

## Findings

Ranked by severity, then evidence. The review's must-fixes are the input here; these say what
the flow should be.

### 1. Major · code + seen · J1 step 2 — the Directions ask reaches the wrong people, or no one
The ask exists only if the person returns to the same cafe page within 60 minutes, from a trip
held in memory. Someone actually heading to the cafe is in Maps; someone who comes back within
the hour is more likely browsing than visiting (inferred), so the reminder is offered mostly to
people who did not go, and Android killing the backgrounded app erases the trip (code). The
ask's timing is also why "about 90 minutes" lies (review 2): the slot was fixed at the tap.
Reference: Podcasts, TIDAL and Pinterest ask *at* the action, before its result; TGTG schedules
off a known event. **Change:** ask at the Directions tap, before Maps opens, only when the ask is
allowed (permission not asked, under the 3-ask cap) and the cafe is open or opens before the
slot: sheet "Get directions to Three Two Brew" with "Remind me around 4:35 PM" (primary, opens
Maps after the dialog) and "Just directions". The time is real because it is computed from this
tap. Drop the return-to-page ask. Every later Directions tap is unchanged, one tap.

### 2. Major · seen + code · J1 step 7 — the notification asks a question Nook can't record for most people
Review 1 found guests can't rate. The flow fix is to make the notification ask what everyone can
answer, and keep "How was it?" for the app, where it is already asked (signed-in, the ranking
sheet asks it again, so the question is asked twice today). Reference: Drinkit "All good?" and
Google Maps "Didn't go here": the first answer counts by itself. **Change:** notification
"Did you make it to Three Two Brew?" · body "Mark it Been in one tap." · actions **I went** /
**Didn't go**. I went (button or body tap, the same thing) marks Been, then in the app:
signed in, the ranking sheet at "How was it?" as today; guest, the same three answers (Liked it /
It was fine / Not for me), kept on the phone with the guest save and carried into the ranking on
sign-in, followed by "Sign in to add it to your ranking" (not a generic sign-in toast). Every
surface uses one verb: "mark it Been". Settings detail: "After you get directions, one reminder
to mark the cafe Been."

### 3. Major · seen · J1 steps 3, 6 — reminders for cafes that were closed
Review 3. What the flow should be: the closed check belongs at the moment the ask is shown (finding
1), because that is where the slot is known. Closed now and not opening before the slot: no ask,
no reminder, ordinary Directions. Closed now but opening before the slot (e.g. tap at 7:30, opens
8:00): schedule from opening time, not from the tap. A person planning tomorrow's trip at night
gets nothing, which is right; TGTG's "Notify me when it opens" is a separate, later feature.

### 4. Major · code · J3 step 5 — Settings says On while the channel is muted
Review 4. A person who muted "Visits and ratings" in Android sees On and gets nothing; this is
the case people write to support about ("I turned it on and nothing comes"). Reference: Lumy's
persistent card naming what is off. **Change:** treat a muted channel as blocked; show the
blocked state with "Reminders are muted in your phone's settings" · Open settings.

### 5. Moderate · seen · J2 step 2 — the save ask spends a lifetime ask on a promise about a different action
The save sheet promises a reminder after Directions, right after a save, and uses one of three
lifetime asks on it. Pinterest and TIDAL promise more of the saved thing; Nook has no such
notification yet. **Change:** remove the save trigger. If finding 1 ships, a saved cafe's first
Directions tap is where the ask lands anyway, with a reason the person can see. Bring a save ask
back only with a save-related channel ("Your saved cafes": opens now, posts something new).

### 6. Moderate · seen · J1 step 5, J2 step 4, J3 step 3 — no word after Allow, or after Deny
Review 5 and 6. The flow should end each branch with one line: Allow from Directions →
the Maps handoff happens and, back in Nook, nothing (the sheet already said the time; repeating
it is noise); Allow from Settings → the row's detail now reads On and the time rule; Deny anywhere
→ "Notifications stay off. You can allow them in your phone's settings." Fuse is the only
reference with an explicit enabled toast; the others confirm through the original action's state.
With finding 1, the original action (Directions) is itself the confirmation.

### 7. Moderate · code · J1 step 7′ — "Didn't go" teaches Nook nothing
It logs an event and stops. Google Maps uses it to correct the guess. **Change:** after Didn't go
on a cafe the person has tapped Directions to twice without going, stop offering its reminder
for 30 days; keep the cafe's Want to try. No extra screen.

### 8. Minor · seen · J3 steps 1-2 — Settings is hard to find for guests and filed under Permissions
Review 10 and 11. Reference: every teardown groups by what is sent under Notifications; Joi puts
timing on the row. **Change:** guest Profile tab gets the same gear; the row moves to a
"Notifications" group with detail text that states the rule, and "Not asked" reads as Off with
"Tap to allow" rather than looking identical to turned off.

## Recommended flow

### J1 (guest and signed in) — before 15/16, after 8/10
1. Tap Directions on a cafe that is open (or opens before the slot), first time and ask allowed:
   sheet "Get directions to Three Two Brew" · **Remind me around 4:35 PM** / Just directions.
   *(changed: moved from the return trip to the tap; real time; closed cafes excluded)* · 1
2. Remind me → Android dialog → Allow → Maps opens. *(Deny → one line, then Maps)* · 1
3. ~90 min later, in 09:00-21:00: "Did you make it to Three Two Brew?" · I went / Didn't go.
   *(changed: answerable by everyone)* · 1
4. I went (button or body) → cafe page, Been marked with a haptic. · 1
5. Sheet "How was it?" Liked it / It was fine / Not for me. *(guest: kept on phone)* · 1
6. Signed in: comparisons, then score (as today, optional). Guest: "Sign in to add it to your
   ranking" with Google one-tap; Skip keeps Been on the phone. · 2 / 2
7. Didn't go → gone; a repeat miss on the same cafe pauses its reminder for 30 days. · 1

Guest total 8, signed in 10 (with comparisons).

### J2 — before 7/6, after 1
Save → "Saved for your next coffee run". No notification ask. *(changed: trigger removed until a
saved-cafes channel exists)*

### J3 — before 12/10, after 6
1. Gear on Profile (guest and signed in) → Settings → **Notifications** → "Visit reminders ·
   After you get directions, one reminder to mark the cafe Been, 9 AM-9 PM." · 1
2. Off: instant, cancels pending. On from not asked: system dialog; deny → one line. · 2
3. Blocked app-wide or channel muted: one card, "Reminders are off in your phone's settings" ·
   Open settings; switch catches up on return. · 2 → 1 after the first time (seen working). · 1+1
Total 6.

## To test with real people

| Question | Method | Task / prompt | Success |
|---|---|---|---|
| Does an ask at the Directions tap feel like help or a toll? | 5-person task test, think aloud | "You want to go to Three Two Brew now. Get there." (prototype with the new sheet) | ≥4 of 5 reach Maps without hesitation; none says it got in the way |
| Do people answer "Did you make it?" more readily than "How was it?" | Five-second test, two variants of the notification | "What would you tap?" | Variant answers predict an action, not a dismissal, in ≥4 of 5 |
| Will guests sign in to keep a rating they already gave? | 5-person task test | After "I went" and "Liked it": "Do whatever you'd normally do next." | Sign-in chosen, or Skip chosen knowing the rating stays on the phone |
| Is 90 minutes right for Cebu cafe visits? | Diary prompt / 5 short interviews | "Last cafe trip: when did you leave, when did you leave the cafe?" | A delay that lands after most visits end |
| Do guests find Settings? | First-click test | "Turn off Nook's visit reminders." from Home | ≥4 of 5 first click on Profile or a gear that leads there |
| Is "Didn't go" read as safe, not as a complaint? | 5-person interview on the notification | "What happens if you tap Didn't go?" | Expect "nothing bad, it stops asking" |

### Analytics to add (HEART)

| Goal | Signal | Event / property to add |
|---|---|---|
| The ask reaches people who go (Adoption) | Asks shown per Directions tap, and why not | `notification_preprompt_skipped` with `reason`: `closed`, `cap`, `gap`, `granted`, `blocked`, `not_back` (today's silent paths) |
| Today's return-trip ask works at all (baseline before changing it) | Minutes from Directions to return to the cafe page | `directions_returned` with `minutes_since_tap`, `app_was_killed` (trip missing) |
| Timing is honest (Happiness) | Delivered vs promised | add `promised_at` and `is_open_at_tap` to `post_visit_reminder_scheduled`; `post_visit_reminder_delivered` on catch-up with `fire_at` |
| The reminder gets answered (Task success) | Opened, I went, Didn't go, swiped away | `post_visit_reminder_dismissed` (Android delete intent); keep `opened` / `didnt_go` |
| Answer becomes a rating (Task success) | Reminder → Been → bucket → score | `source: reminder` on `mark_been` and ranking completion; guest `guest_rating_kept` and `guest_rating_synced` |
| Notifications don't wear out (Retention) | Turn-offs and mutes after a reminder | `notification_state` on app open: `app_enabled`, `channel_importance`; `visit_reminders_toggled` gains `days_since_last_reminder` |
| Pushes help retention, not just opens | Holdout | a 10% holdout that never gets the ask (Pinterest's practice); compare 7-day return. At ~150 installs, read it as direction, not proof |

## Next

`overhaul` is not needed; the next job is a `part` for the Directions sheet (finding 1) and a
`tweak` for the notification copy and Settings row (findings 2, 4, 8). Refero screenshots stay in
`/tmp/partwise-ux-notif/` and are not committed.
