# Home-screen widget · UX research (2026-10-16)

Job: partwise **ux**. Research only: no design, no code. Desk research and expert evaluation, single rater.
Nothing here is what users said or did; that is in "To test with real people".

Sources:
- The build as reviewed in `partwise-review-home-widget.md` and its 17 shots in `review-shots-home-widget/` (Android emulator, API 35, Pixel launcher). Those shots are "the journey as it is". No new emulator run.
- `docs/features/home_widget.md`.
- Code in `lib/features/home_widget/` and `lib/core/analytics/home_widget_events.dart`.
- The notification ask on `retention/local-notifications` (`visit_reminders/…/notification_preprompt_sheet.dart`). Journey 3 depends on it.
- Teardowns in `nook-marketing/research/2026-10-retention/teardowns/`: `tgtg.md` §3, `pinterest.md` part 2, `duolingo.md`.
- Refero flows, gathered by three flow scouts. The screenshots stay in the scratchpad and are not committed.

## Question

**Question:** How should a saver get from "I have a few Want to try cafes" to a widget they keep and act on? Which steps in the current promo → pin → glance → tap path lose them or mislead them?

**Product:** a local-discovery app with saved places, like Too Good To Go (favourites), Google Maps (saved), Beli, Mapstr.

**People:** Cebu cafe-goers on Android phones, often at large font scales. Signed-in, or guests with saves on the phone.
- Job: *When I'm deciding where to go for coffee, I want to see which of my saved cafes are open without opening an app, so I can pick one and go.*

**Journeys:**
1. A saver sees the promo → taps Add widget → launcher pin dialog (Add or Cancel) → the widget is on the home screen and they know it.
2. Days later: glances at the widget → decides to go → taps a cafe → cafe page → Directions.
3. Someone who said no to notifications is offered the widget as the alternative.

**Evidence:**
- The emulator review (17 shots), the source, and three teardowns.
- **No analytics.** The widget and its events exist only on `retention/home-widget` and have not shipped, so there is no funnel to quote. I am not estimating one.

## Journeys today

Step scores follow NN/g's PURE method: 1 = easy, 2 = takes effort, 3 = hard enough to give up. Single rater.

### J1. Promo → add → on the home screen (shots 14, 15, 16, 17)

| # | Step | What happens | Walkthrough fail | PURE |
|---|---|---|---|---|
| 1 | Reach the card | The card appears on the Saved tab after 3+ Want to try saves, or after 1+ save when notifications are "off". For guests it sits under the Want to try section, so with many saves it is below the fold. Signed in, it sits under the system list cards. The show is counted, and `widget_promo_shown` is logged, as soon as the rules decide, whether or not the card was ever on screen (`_decide()`). Each phone gets 2 shows in its lifetime. | Notice? (for guests with long lists) | 2 |
| 2 | Understand the offer | The title and body sit next to a small preview made from the person's own cafes, with live status dots (`16`). Clear. The "Prefer no notifications?" variant is shown to people who were never asked (`14`, review must-fix 8). | Right thing? (wrong variant) | 1 (saves) / 2 (no-notif) |
| 3 | Tap Add widget | The card disappears at once. `markAdded()` is written **before** the launcher answers. | — | 1 |
| 4 | Launcher dialog | Pixel's "Touch & hold the widget to move it around", with **Cancel** and **Add to home screen** (`15`). The preview shows sample cafes with made-up km ("A cafe you saved · 1.2 km"). The card had just shown the person's own cafes. | Connect? (the preview is no longer theirs) | 2 |
| 5a | Add | The launcher places the widget on some home-screen page. The person is still in Nook. Nothing in Nook confirms it, and nothing says where it went. | See it worked? | 2 |
| 5b | Cancel | Back in Nook, the card is gone for good (`added = true`). There is no route back except the launcher's widget picker. | See it worked? / no way back | 3 |

Score (Add path): **8**. Score (Cancel path): **9**, and it is a dead end.

States:
- Loading: not applicable.
- Pin unsupported: hidden (`canPin`), which is correct.
- Pin error: caught and printed to the debug log only, so the person sees nothing.
- Success: missing.
- Cancel: missing.
- Large text: buttons go uneven (`17`).

### J2. Glance → decide → tap (shots 04, 05, 06, 08, 09, 12, 13)

| # | Step | What happens | Walkthrough fail | PURE |
|---|---|---|---|---|
| 1 | Glance | 4×2 widget: "Your saved cafes · 2 open now", then 3 rows of name + status (`04`). 2×2 widget: "Want to try" and one cafe, with about 60% of the tile empty and no count (`05`). | — | 1 (4×2) / 2 (2×2) |
| 2 | Decide | The status words are good: "Open until 10 PM", "Opens 1 PM". Three things undermine them. Turnovers land up to about an hour late, and "2 open now" carries no time (`08`, `09`, must-fix 1). Distance is either missing or frozen at the moment of the write (should-fix 3). At font scale 2.0 the status line is cut in half (`12`, must-fix 2). There is no "as of" stamp anywhere. | See it worked? (the state may be false, and nothing says how old it is) | 2 (3 at 2.0 font) |
| 3 | Tap a row | Cold start → the cafe page, and Back goes to Home (`06`). Works. The header target is 32dp (should-fix 4). | — | 1 |
| 4 | Land on the cafe | The page shows "Open until 10 PM" under the name, and Directions sits in the bottom bar (`06`). If the widget was stale, the page contradicts it: the widget said "Opens 1 PM" at 13:07, while the page says Open. | Connect? (two answers to one question) | 1 / 2 when stale |
| 5 | Go | Directions → Maps. On the local-notifications branch, the visit-reminder pre-prompt shows first. | — | 1 |

Score: **6** at default text; **8** at font scale 2.0 or during a stale turnover window.

States:
- Empty: shown, and good (`02`).
- Stale after 7 days: in source only.
- Dark mode: shown (`10`).
- Large text: broken (`12`).
- No location: shown. The rows simply carry no km.
- Offline: not applicable, the widget reads local frames.

### J3. Said no to notifications → widget instead (shot 14, plus the code on two branches)

On this branch nobody ever "says no". Nook does not ask for notifications on `retention/home-widget`. The ask lives on `retention/local-notifications`. It is a pre-prompt at the Directions tap: "Want a reminder around 4:35 PM?", with the buttons **Remind me** / **Just directions**. That is followed by the system dialog. After a system "Don't allow", Nook shows the toast "Notifications stay off. You can allow them in your phone's settings." and Maps opens about 1.2 s later.

| # | Step | What happens | Walkthrough fail | PURE |
|---|---|---|---|---|
| 1 | "Decline" | On this branch the trigger is just `areNotificationsEnabled() == false`. On Android 13+ that is true for anyone **never asked**. So most new installs land in this group. | Right thing? (the premise is false) | 3 |
| 2 | The card | "Prefer no notifications? Add the widget" (`14`) appears as the very first card. It takes one of the two lifetime shows, and it pre-empts the stronger "saves" card. | Connect? ("I never turned anything off") | 2 |
| 3 | Add / Not now | Same as J1 steps 3–5. | as J1 | 4 |

Score: **9**, measured against a premise that is wrong for most people who see it.

## How others do it

Refero has almost no Android widget flows, and no flow that runs past the OS step, so success and cancel are covered in no reference. The scouts' composites are labelled below.

### J1: promo → add

- **Days** (countdown events; [flow 7797](https://refero.design/flows/7797)), 6 steps.
  - "Add Widget" is one of four round actions **on the person's own item**.
  - It opens a 5-dot carousel: an intro mock that uses their own event, long-press, search "Days", pick variant and size, then an FAQ ("Why is the widget not showing?") and Done.
  - It does not detect success.
- **(Not Boring) Weather** ([flow 3588](https://refero.design/flows/3588)), 2 steps.
  - A permanent widget icon in the header opens a sheet: "Add a Widget / See the current weather conditions and forecast right on your home screen", with previews of both sizes.
  - There is no button, only "Learn more". It is pull, not push.
- **Mindllama** ([flow 5508](https://refero.design/flows/5508)): Settings → Widgets → one screen with tabs for Home / Lock / Control Center, each tab showing three steps at once. Also pull, with no data preview.
- **Pinterest Android** (teardown, not Refero).
  - The server decides when to show it: "Stay inspired with widgets / Get your Pinterest feed right on your home screen", a 3-step how-to, and **Try it**, which calls `requestPinAppWidget` directly.
  - Two sizes: up to 6 Pins at 5×2, and a 1-Pin 2×2.
- **Too Good To Go** (teardown): **no** in-app promo at all. The widget is found from the launcher picker only.

**Pattern:** the offer shows the person's own content in a widget mock, and the add step is one action.

**Split:** push card (Pinterest, Nook) or pull entry (Weather, Mindllama, TGTG). Nobody shown confirms success or handles cancel. Android is the only platform where an app *can* know, through `requestPinAppWidget`'s success callback or an installed-count check on resume. Nook already has the count check.

### J2: glance → tap

Composites: real widget screens plus real landing screens from same-kind products. The tap → land step is inferred.

- **Todoist** widget ([screen](https://refero.design/screens/1780a536-0c1d-4d73-aa47-89c791199dcb)).
  - The header carries the count ("Today 8"), so the glance answers "how much" before any row is read.
  - Rows are single-line and truncated. The small size keeps the label and count and drops rows.
- **Orbit** widget ([screen](https://refero.design/screens/30154bae-afc3-4c59-b252-20ef0a380be6)), with landing analogs from **Subo** ([flow 8586](https://refero.design/flows/8586)) and **Uber Eats** favourites ([screen](https://refero.design/screens/cef26bd9-5865-4852-96c0-e4a73c2094cd)).
  - Each row has a relative-time chip ("3 DAYS"), most urgent first.
  - The tap opens a detail page that **restates the same cue** ("Expires in 4 days").
  - Uber Eats groups unavailable favourites with "Available at 11:30 AM" instead of hiding them.
- **Waterllama** sizes ([flow 11534](https://refero.design/flows/11534)), with **voila** ([screen](https://refero.design/screens/fed8b989-5a7e-4e5f-b6d1-85c367105d0c)) and **Blackbird** ([screen](https://refero.design/screens/40912fec-7c6a-4e39-a65a-e8183b6f6c84)) as place-page analogs.
  - The small size drops secondary slots but keeps the headline number.
  - voila's page puts "CLOSED · Opens at 11AM Sun" and the directions button **in one row at the top**.
- **TGTG** widget (teardown): favourites available right now, with pickup time. Refresh every 2 h plus an hourly job. Empty state "ADD MORE FAVOURITES".

**Pattern:**
- One status or time cue per row.
- A count or total in the header.
- A tap lands on the item, which restates the cue next to the next action.

**Split:** a full page (Subo, voila) or a preview over the list (Structured). No reference shows a freshness stamp or a stale state. Nook's 7-day "Open Nook to update" state is unreferenced.

### J3: decline → alternative

- **DailyArt** ([flow 3311](https://refero.design/flows/3311)).
  - Priming screen, then the OS prompt, then a reminder-time question, then "Add your Widget / … art at your fingertips at all times!".
  - The widget step is shown **to everyone**, whatever the answer. It never mentions the decline.
- **Daylish** ([flow 8003](https://refero.design/flows/8003)): on "Don't allow" the bell controls just go inert. No alternative, no explanation, no re-ask. This is the silent-decline case.
- **Headspace / Imprint / Luma** (single screens: [Headspace](https://refero.design/screens/3f091357-fc6b-4556-8885-615df0d06ce8), [Imprint](https://refero.design/screens/826157e3-4b52-455e-b44a-62c326953a07), [Luma](https://refero.design/screens/3112acc5-8153-40a6-b832-ed4471d15056)).
  - The app's own "Not now" sits under the primary button, so the app can tell "later" (OS prompt not used) from "denied".
  - Headspace's OS prompt offers "Allow in Scheduled Summary", a digest offered as an alternative inside the same dialog.
- **Duolingo** (teardown, not Refero): "Don't like notifications? Try our widget instead!", with a one-tap add and a reward for installing. It is aimed at users who **turned notifications off**.

**Pattern:** none of the references words the alternative as "you said no". Duolingo is the exception, and it only does so for people who really did switch notifications off.

**Split:** the alternative goes to everyone (DailyArt), to nobody (Daylish), or only to true decliners (Duolingo).

## Findings

Ranked by severity, then evidence. Each finding gives the severity, then the evidence type, then the step.

### 1. Major · code + seen · J3 step 1, J1 step 2: the notifications-off card reaches the wrong people and takes the better card's slot

**Problem**
- On Android 13+, "notifications off" means "never asked" for most installs (`14`, review must-fix 8).
- The card's premise is false for them.
- It burns one of the two lifetime shows and pre-empts "See your saved cafes on your home screen".

**Cost:** the first impression of the widget is a question that does not apply. The persuasive saves variant may then never show, because the next show is 14 days away and is the last one.

**Reference:** Duolingo aims its line only at people who turned notifications off. DailyArt avoids presuming by not mentioning the decline at all.

**Change**
- Trigger the decliner card only on a recorded decline:
  - SDK < 33 with notifications disabled; or
  - a system "Don't allow" recorded by the visit-reminder service (it already counts `systemAsks` and `everGranted`; a denial is `asks > 0 && !everGranted`); or
  - a later blocked channel.
- Do **not** count "Just directions" as a decline. It is "not now" for one trip.
- Until `retention/local-notifications` merges, pass `notificationsOff: null` on SDK 33+.
- Show the card at the next **Saved-tab visit after the person comes back from Maps**, not in the denial toast, which Maps covers about 1.2 s later.
- Word it for what was declined. They said no to a visit reminder, not to "updates": "No reminders, then. See which saved cafes are open from your home screen."

### 2. Major · seen · J2 step 2: the glance can be wrong, and nothing on it says how old it is

**Problem**
- Openings and closings land up to about 1 h late (`08`, `09`).
- "2 open now" states a fact with no time attached.
- At font scale 2.0 the status line, the thing the person decides on, is cut in half (`12`).

**Cost**
- The widget's single promise is "which ones are open now".
- A wrong "Opens 1 PM" at 13:07 is followed by the cafe page saying Open. Worse, a "Closes soon · 10 PM" at 10:50 PM sends someone to a closed door.
- For a cafe trip, being sent to a closed cafe is the peak-end moment that decides whether they keep the widget.

**Reference**
- Orbit and voila restate the same cue on the landing page, so the cue must be true.
- TGTG refreshes every 2 h plus hourly, but its rows show a pickup *window*, not a live claim.

**Change** (what the flow should be; the mechanism is in the review)
- Each turnover lands within about 10 min (`setWindow`).
- The count reads as a time-bound claim, e.g. "2 open · 1:07 PM", or the count is dropped near a turnover.
- At large text, two rows that keep the status and ellipsize the name.
- The landing page uses the *same words* as the row, so a mismatch is obvious and rare.

### 3. Major · code + seen · J1 step 5b: Cancel throws the offer away, and Add gets no confirmation

**Problem**
- `markAdded()` runs before the launcher answers. A Cancel in `15` ends the promo for good.
- An Add leaves the person in Nook, with no word that it worked or where the widget went.

**Cost**
- Someone who cancelled to look at the dialog's fake-km preview, or by accident, never sees the offer again.
- Someone who added does not know to go and look. The first glance, which is what makes the habit, is delayed.
- People would ask "where did it go?", which is support-level confusion.

**Reference**
- Days ends with an FAQ, "Why is the widget not showing?". It is the only reference that admits the step can fail.
- Pinterest pins directly, like Nook.
- No reference confirms success, but Android lets Nook do it.

**Change**
- Treat Add as an ordinary show.
- On the next resume, if `installedCount()` rose: mark added and show a SnackBar, "Widget added. Look for "Your saved cafes" on your home screen."
- If it did not rise: keep the card's remaining show, and show nothing now.
- Optional: pass a success callback to `requestPinAppWidget` instead of polling on resume.

### 4. Moderate · code · J1 step 1: a "show" is spent and logged even when the card is never seen

**Problem**
- `_decide()` writes the show and logs `widget_promo_shown` when the rules pass, not when the card is on screen.
- For guests the card sits under the whole Want to try section, so with many saves it can be below the fold.

**Cost**
- One of only two lifetime offers can be spent invisibly.
- The analytics will overstate reach and understate the add rate.

**Reference:** Pinterest's server-timed upsell and Days's on-item action both appear where the person already is.

**Change**
- Count and log the show when at least half the card has been visible for about 1 s.
- For guests, place the card directly under the Want to try heading's first rows, or under the sign-in card, rather than after the full list.

### 5. Moderate · seen · J1 step 4: the launcher dialog shows someone else's cafes

**Problem:** the card's preview is the person's own cafes (`16`). The launcher dialog then shows "A cafe you saved · 1.2 km" with made-up distances (`15`).

**Cost**
- At the commit moment, the picture switches from "mine" to "generic sample", which is the least persuasive version.
- The fake km also promise a feature (distance) the widget often cannot keep.

**Reference:** Days's mock uses the person's own event at every step.

**Change**
- Drop the distances from the preview layout.
- The preview layout is static (Android 12+ `previewLayout`), so it cannot show the person's own cafes. Keep the sample names, but make them plainly samples.
- The card stays the persuasive picture.

### 6. Moderate · seen · J2 step 1: the 2×2 widget answers the wrong question

**Problem:** one cafe, no count, and 60% of the tile empty (`05`).

**Cost:** the glance cannot answer "is *any* of my places open?".

**Reference**
- Todoist's small size keeps the count and drops rows.
- Waterllama's small size keeps the headline number.

**Change:** at 2×2, show the count plus the first open cafe ("2 open · Cafe Julio until 10 PM"), or two single-line rows.

### 7. Moderate · inferred · J2 step 4: the landing page does not pick up from the glance

**Problem:** a widget tap opens the standard cafe page. The status sits under the name, and Directions is in the bottom bar (`06`). That works, but nothing acknowledges that they came to decide whether to go now.

**Cost:** a small one. They have to find the hours and the action on a page built for browsing.

**Reference:** voila puts the status and the directions button together in the top card.

**Change**
- With `via=widget`, keep the page but bring the status and Directions next to each other above the fold.
- When the cafe has closed since the widget frame was drawn, say so plainly: "Closed now. Opens 7 AM tomorrow".

### 8. Minor · seen · J2: two names for one thing

**Problem:** the 4×2 is titled "Your saved cafes" and the 2×2 "Want to try". The picker description says "open now" but the widget also lists closed cafes (review items 5 and 7).

**Change:** use "Saved cafes" everywhere, with the description "Your Want to try cafes and when they're open".

### 9. Minor · seen · J1 step 2: the body promises "open now"

**Problem:** the saves card says "Which ones are open now, without opening Nook." That is only safe once finding 2 is fixed.

**Change:** until then, use "Your saved cafes and when they open, without opening Nook."

## Recommended flow

Changed steps are marked **[changed]**.

### J1. Promo → add

1. **[changed]** The card appears on Saved after 3+ Want to try saves, placed near the top of the Want to try section. A show is counted only when the card is actually seen.
2. The title "See your saved cafes on your home screen", the body "Your saved cafes and when they open", and a preview of their own cafes. Buttons: Not now / Add widget, stacked at large text.
3. Add widget → the launcher dialog **[changed: preview without fake km]**.
4. **[changed]** Back in Nook:
   - If added: a SnackBar, "Widget added. Look for "Saved cafes" on your home screen." The card is retired.
   - If cancelled: no message. The second show stays available, 14+ days later.

Score: 8 → **5** (1, 1, 2, 1).

### J2. Glance → tap

1. **[changed]** 4×2: "Saved cafes · 2 open", with turnovers within about 10 min. At large text, 2 rows that keep the status. 2×2: the count plus the first open cafe.
2. **[changed]** The status words are always true to within about 10 min. There is no frozen distance: drop it, or keep it only near the write.
3. Tap a row → the cafe page.
4. **[changed]** Arriving `via=widget`: the status and Directions sit together at the top, in the same words as the row.
5. Directions → Maps (with the visit-reminder ask, if eligible).

Score: 6 (8 at large text) → **4** at any text size.

### J3. Declined → widget

1. **[changed]** A real decline is recorded: a system "Don't allow" after "Remind me", or notifications disabled on SDK < 33. "Just directions" and "never asked" do not count.
2. The denial toast shows as today. Maps opens.
3. **[changed]** At the next Saved-tab visit, if there is 1+ Want to try, no widget placed, and the cap allows: "No reminders, then. See which saved cafes are open from your home screen." Shown once.
4. Same as J1 steps 3–4.

Score: 9 (for the wrong audience) → **5** (for the right one).

## To test with real people

| Question | Method | Task / prompt | Success |
|---|---|---|---|
| Does "Prefer no notifications?" read as a judgement or a helpful option to people who did decline? | 5-person task test (decliners only) | Run the Directions → "Remind me" → Don't allow path, return to Saved, and think aloud on the card | 4/5 describe it as an option, not a reproach |
| After Add, do people find the widget on the home screen? | 5-person task test | "Add the widget, then show me where it is" | 4/5 find it within 10 s, with and without the SnackBar |
| What do people expect "2 open now" to mean, and when do they stop trusting it? | Five-second test on `04`, then follow-up questions | "What does this tell you? Would you go now?" | They read it as "right now", and would trust it within 15 min |
| At large text, which matters more: the cafe's full name or its status? | First-click/preference test with two variants | "Which of these tells you where to go?" | The status-kept variant is preferred |
| Is a 2×2 with one cafe useful, or is the count wanted? | 5-person preference test | Show the 2×2 one-row version beside the count + row version | 4/5 pick count + row |
| Why do people cancel the launcher dialog? | Short in-app question after a cancel, shown once (TGTG's "what stopped you?" style) | "Didn't add the widget? Not now / Not useful / Didn't understand / No space" | Answers spread enough to act on |
| Does the widget bring people back, or only add taps for people who would open Nook anyway? | Holdout (Pinterest's habit holdouts) | 10% never see the promo | Widget cohort D30 retention beats the holdout |

**Analytics to add** (HEART goals → signals → events):

| Goal | Signal | Event / property |
|---|---|---|
| Adoption: the offer is seen | The card was actually on screen | `widget_promo_viewed` {reason, show}, fired when at least 50% is visible for 1 s. Keep `widget_promo_shown` as "decided". |
| Adoption: the pin completes | The launcher result | `widget_pin_result` {result: added / cancelled / error, reason}, from the resume count check or the success callback |
| Adoption: where installs come from | The promo or the launcher picker | `source` on `widget_installed_count_changed`: `promo` if within 10 min of `widget_promo_added`, else `picker` |
| Task success: the glance was true | The widget said open, and the cafe was open at the tap | `shown_tone` and `frame_age_min` on `widget_tapped` for target=cafe. On the cafe page, `widget_status_mismatch` when the live status differs. |
| Engagement: they act | Taps that lead to a trip | `widget_tapped` → `cafe_directions_tapped` with `via=widget` (property on the existing directions event) |
| Retention: they keep it | Removal | `widget_installed_count_changed` with count < previous (already logged); report as a removed-within-7-days rate |
| Retention: it brings them back | Opens from the widget per active week; D7/D30 for installers vs holdout | `holdout` super-property, as visit-reminders does |
| Right audience (J3) | Who sees the decliner card | `decline_kind` {system_denied, sdk_disabled} on `widget_promo_viewed` when reason = no_notifications |

## Next

The review's three must-fixes are the flow fixes in findings 1–3: the decliner trigger, a true glance (turnovers, large text), and Cancel/confirm. Do those before shipping. The next partwise job is a `part` on the Saved-tab promo card (placement, stacked buttons, the confirmation SnackBar) and a `tweak` on the 2×2 layout.
