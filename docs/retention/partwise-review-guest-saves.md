# Guest saves, keep-saves ask, Your places · partwise review (2026-10-16)

Job: **review** (mode ios, written for Android-first Flutter with Material controls; target code).
Nothing in `lib/` was changed.

Branch `feat/retention-v1` @ `c9d6027` (v1.1.5+13 debug build). **Looked at: Android emulator**
`Pixel_7_API_35` (1080×2400, 420dpi), app data cleared, signed out (guest), GPS set to Cebu.
One batch of screenshots plus one variant batch (font scale 2.0, system dark mode). Hover and
pressed states were checked in the source, not on screen. No real sign-in was completed, so
merging saves after sign-in (`GuestSavesSync._merge`) was checked **from the source only**.

Judged against the product direction already decided: guest saves have no cap, the sign-up ask
stays soft and can always be dismissed, and an engagement score will trigger it later.

Screenshots: `review-shots/` (JPEG, 540 wide). The ones referred to below:

| Shot | What |
|---|---|
| `10-home-empty` | Home, guest, no saves: the Your places rail is hidden |
| `11-home-rail-1` | Home after the first Want to try |
| `12b-home-rail-2`, `13-home-rail-been` | Home after a second save: **the newest saved card has no badge** |
| `30-cafe-page`, `31-cafe2-page` | Cafe page: Been / Want to try pills, top-right bookmark |
| `44-first-save-toast` | First guest save: "Saved on this phone. Sign in to keep it everywhere." |
| `45-top-bookmark-guest` | Top-right bookmark as a guest: still the "Sign in to save to a list" wall |
| `40-directions-out`, `41-back-in-app` | Directions opens Google Maps (first-run screen on a fresh emulator) |
| `42-nudge`, `46-nudge-cafe2`, `47-nudge-save-toast` | Back in Nook: "Save to Want to Try?" · Save, then "Saved for your next coffee run" |
| `48-been-toast` | Been as a guest: "Added to Been" |
| `20-saved-empty`, `21-saved-with-saves` | Guest Saved tab, empty and with saves plus the keep-saves card |
| `22-keep-saves-sheet`, `23-sheet-terms-nudge` | Sign-in sheet from the card; Google tapped before ticking the terms box |
| `14-home-fontscale2`, `24-saved-fontscale2` | Font scale 2.0 |
| `15-home-dark` | System dark mode: the app stays light (no dark theme anywhere in the app) |

---

## Ranked findings (all screens)

### Must fix (blocks the task or misleads)

1. **A saved cafe shows as unsaved in Your places.** Seen in `12b`/`13`: Flavour Coffee
   Station is in Want to try (its badge shows in House picks just below), but its Your places
   card has no badge. Cause: `CafeStatusBadge` (`lib/core/presentation/widgets/cafe_status_badge.dart:30`)
   decides when to rebuild by checking whether the status of *its own* `cafeId` changed. The
   rail puts the newest save first, so card 0's element is reused for a different cafe. When
   Flavour's status changed, card 0 was still Brew Szn: the check returned false, the cached
   state was never updated, and the rebuilt card read Flavour's status from that stale state.
   **Fix:** give each card a key, `HomeCafeCard(key: ValueKey(cafes[index].id), …)` in
   `YourPlacesRow`'s `itemBuilder` (`your_places_rail.dart:~222`). Better, fix the badge
   itself: use `context.select((CafeStatusCubit c) => c.state.statusFor(cafeId))` in place of a
   `buildWhen` tied to one id. Any list that reorders has the same bug.
2. **The cafe page still has a sign-in wall on a save.** Seen in `30`/`45`: the top-right
   bookmark (custom lists) opens "Sign in to save to a list" for a guest, right above a
   "Want to try" pill that uses **the same bookmark icon** and saves with no account. A guest
   who goes for the most familiar save spot, top right, hits the wall the feature was built to
   remove, and learns that saving needs an account. **Fix:** for guests, make the top-right
   button run the same Want to try save (or open a Want to try / Been choice). Use a
   list-plus icon for "Add to list" so the two controls stop looking alike. Keep the wall only
   for custom lists, and say so: "Make your own lists".

### Should fix

3. **The terms checkbox sits in front of the one-tap Google sign-in.** Seen in `22`/`23`:
   Google needs the box ticked first, and tapping it without the tick shows red text: "Tick the
   box to agree before you continue." That turns the soft ask into tick, tap, and maybe an
   error (`sign_in_choices.dart:172`). **Fix:** replace the checkbox with one line under the
   buttons: "By continuing you agree to the Terms of Use and Privacy Policy" (links kept), and
   record acceptance when a provider is tapped. Before shipping, check with whoever owns
   App Store guideline 1.2 (user-generated content) that agreeing this way is enough. If it
   is not, keep the checkbox but tick it automatically and show it only on the first account
   creation.
4. **Nothing confirms the move after sign-in.** In the source only: `GuestSavesSync._merge`
   (`guest_saves_sync.dart:70`) reloads the lists without telling the user anything. If some
   saves fail to move, it also says nothing, and those leftovers are thrown away on sign-out
   (`aba9a06`). The sheet promised "everything you saved on this phone moves to your account",
   so the user should see it happen. **Fix:** when `merged > 0`, show the toast "Moved 3 cafes
   to your account" with a "View" button that opens the Saved tab. When some fail: "2 of 3
   moved. We'll try the rest again", and retry on the next start.
5. **The save nudge disappears on a timer and is offered once.** Seen in `42`/`42b`: the toast
   lasts 6 s (`directions_save_nudge.dart:131`) and is never offered again for that cafe in
   that session. On the first attempt in this review it had gone before Save was tapped,
   because returning from Maps takes a moment to settle. Six seconds is also short for a
   control with an action when TalkBack is on (WCAG 2.2.1). **Fix:** 10 s, and no timeout when
   `MediaQuery.accessibleNavigationOf(context)` is true. Alternatively, keep a quiet
   highlight on the Want to try pill after the toast goes, so the offer stays where the user
   already looks.
6. **Tap targets under 48dp.** The keep-saves card's "Sign in" and the empty state's "Find a
   cafe" are 40dp tall (`guest_saved_page.dart` `_PillButton`, `minHeight: 40`). The sheet's
   "Not now" is 44dp (`guest_sign_in_sheet.dart`, `height: 44`). **Fix:** `minHeight: 48` on
   both. The card button can keep its look by padding the hit area instead.
7. **One thing, five names.** The tab says "Saved", the page title says "Your lists"
   (`GuestSavedPage.title`), Home says "Your places", and the copy switches between
   "Want to Try" (nudge, empty state) and "Want to try" (pills, sections, badges). **Fix:**
   title the guest page "Saved" to match the tab, and use "Want to try" in sentence case
   everywhere: `DirectionsSaveNudge.message` → "Save to Want to try?" and
   `GuestSavedPage.emptyTitle`/`emptyBody`.

### Could be better

8. **Your places doesn't say why a cafe is in it.** The rail mixes Want to try with recently
   viewed cafes (`yourPlaces()`), and viewed cafes have no badge. With finding 1, two of two
   cards looked unsaved. **Fix:** a subtitle through the existing `HomeSectionTitle(subtitle:)`,
   e.g. "Saved and recently viewed", and `onSeeAll` → the Saved tab, so the rail leads
   somewhere (Home's other shelves already have "See all").
9. **The keep-saves card at large text.** At font scale 2.0 (`24`) the card's text column
   shrinks to about 3 words a line over 7 lines, because the button keeps its width.
   **Fix:** above a 1.3 text scale, stack the button under the text (a `Wrap`, or a `Column`
   switched on `MediaQuery.textScalerOf`). The body is also 12sp, below the 14sp the rest of
   the screen uses for secondary text: make it 14.
10. **The save confirmation has no Undo.** "Saved for your next coffee run" (`47`) and "Added to
    Been" (`48`) have no action, while removing a save offers Undo. **Fix:** add "Undo" (or
    "View", which opens the Saved tab) to the save toasts too, so adding and removing behave
    the same way.

Seen but left alone: the app has no dark theme (`15`), across the whole app, not just this
feature. The Home "See cafes near you" card did not appear in this run (GPS was set by the
emulator; out of scope).

### Working well

- **The first save asks without walling** (`44`). The save happens first, the Want to try pill
  fills at once, and the ask is one line with a Sign in action that can be ignored. This
  matches the decided direction exactly, and the copy says what is at stake ("Saved on this
  phone").
- **The guest Saved tab is a real screen, not a sheet** (`21`). The card states its purpose in
  one line and comes before the saves without hiding them, and the rows reuse Home's meta and
  open-now lines, so a saved cafe reads the same everywhere. The empty state (`20`) says what
  belongs there, "It stays on this phone, no account needed", and offers "Find a cafe".
- **The nudge's guard rules are careful.** It never asks about a cafe that already has a
  status, never asks a signed-in user whose status is unknown (so it can't seem to forget a
  Been), and asks at most once per cafe.

---

## Scorecards

Scored once, from the emulator. 0 = a real problem, 1 = works with a gap, 2 = solid.

```text
Screen: Home with Your places rail          Looked at: emulator (Pixel 7, API 35)
Foundations   Typography 2 · Grids 2 · Color 2 · Communication 2
Structure     Proportion 2 · Clarity 1 · Precision 2 · Order 1
Behavior      Affordance 1 · Motion n/a · Efficiency 1 · Restraint 2
Impact        Visuals 2 · Universal 2 · Accessibility 1 · Responsibility 1
Total 22/30 (15 scored)

Fix
- Responsibility 1 / Affordance 1: the newest saved card shows as unsaved (finding 1).
- Clarity 1: no hint why a cafe is in "Your places" (finding 8).
- Order 1: the badge's rebuild check is wrong for any list that reorders; fix it in the shared badge, not per rail (finding 1).
- Efficiency 1: no "See all" to the Saved tab (finding 8).
- Accessibility 1: the badge text is 10sp (`cafe_status_badge.dart`, fontSize 10), under the 11 floor; make it 11–12.
```

```text
Screen: Cafe page, Been / Want to try        Looked at: emulator
Foundations   Typography 2 · Grids 2 · Color 2 · Communication 1
Structure     Proportion 2 · Clarity 1 · Precision 2 · Order 2
Behavior      Affordance 2 · Motion n/a · Efficiency 2 · Restraint 2
Impact        Visuals 1 · Universal 2 · Accessibility 2 · Responsibility 1
Total 24/30 (15 scored)

Fix
- Communication 1 / Clarity 1 / Visuals 1: two bookmark icons with different meanings; the top one walls guests (finding 2).
- Responsibility 1: the walled bookmark tells guests saving needs an account, which is no longer true (finding 2).
```

```text
Screen: Directions save nudge (toast)        Looked at: emulator
Foundations   Typography 2 · Grids 2 · Color 2 · Communication 2
Structure     Proportion 2 · Clarity 2 · Precision 2 · Order 1
Behavior      Affordance 1 · Motion 2 · Efficiency 2 · Restraint 2
Impact        Visuals n/a · Universal 2 · Accessibility 1 · Responsibility 2
Total 25/28 (14 scored)

Fix
- Affordance 1 / Accessibility 1: 6 s timeout with an action, offered once; easy to miss on return (finding 5).
- Order 1: "Want to Try" here, "Want to try" on the pill it sets (finding 7).
```

```text
Screen: Guest Saved tab with keep-saves card  Looked at: emulator (+ font scale 2.0)
Foundations   Typography 1 · Grids 2 · Color 2 · Communication 2
Structure     Proportion 2 · Clarity 1 · Precision 2 · Order 1
Behavior      Affordance 2 · Motion n/a · Efficiency 2 · Restraint 2
Impact        Visuals 2 · Universal 1 · Accessibility 1 · Responsibility 2
Total 23/30 (15 scored)

Fix
- Accessibility 1: Sign in / Find a cafe are 40dp tall (finding 6).
- Universal 1 / Typography 1: the card squeezes at large text; 12sp body (finding 9).
- Clarity 1 / Order 1: "Your lists" under a "Saved" tab; mixed Want to Try casing (finding 7).
```

```text
Screen: Sign-in sheet (keep-saves reason)    Looked at: emulator
Foundations   Typography 2 · Grids 2 · Color 2 · Communication 2
Structure     Proportion 2 · Clarity 2 · Precision 2 · Order 1
Behavior      Affordance 2 · Motion n/a · Efficiency 1 · Restraint 2
Impact        Visuals 2 · Universal 2 · Accessibility 1 · Responsibility 1
Total 24/30 (15 scored)

Fix
- Efficiency 1: a terms tick in front of one-tap Google (finding 3).
- Responsibility 1: "everything moves to your account" is promised, but nothing confirms it afterwards (finding 4).
- Accessibility 1: "Not now" is 44dp (finding 6).
- Order 1: the sheet hard-codes its colors (`_brand`, `_ink`, `_muted`) instead of using the auth/list tokens; note only, as the Figma frame defines them.
```

Totals: Home 22/30 · Cafe page 24/30 · Nudge 25/28 · Saved tab 23/30 · Sign-in sheet 24/30.
These scores are for comparing before and after a fix, not for comparing products.
