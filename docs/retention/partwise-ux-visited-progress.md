# "Been to X of Y" progress · UX research (2026-10-16)

Job: partwise **ux**. This is desk research plus an expert walkthrough of branch
`retention/visited-progress` at `12b19b4`. It is not user research; nothing here reports what a
user said or did. The journey "as it is" comes from the review screenshots in
`review-shots-visited-progress/` (Android emulator, guest, GPS Cebu, guest saves rewritten per
state). Companion doc: `partwise-review-visited-progress.md`. Refero contact sheet is kept
locally at `/tmp/ux-visited-progress/sheet-b.png` and is not committed.

## Question

**Does seeing "Been to X of Y" move someone who saved cafes to go to the rest, and where does
the loop from save → visit → progress → next visit break?**

- **Product:** local cafe discovery and saving, like Google Maps Saved ("Want to go"), Beli
  (been / want to try, ranking), Mapstr, Letterboxd's watchlist. Used when going out, weekly to
  monthly.
- **People:** someone in Metro Cebu on an Android phone who has saved a few cafes to Want to
  Try, as a guest or signed in. Job: *When I've saved cafes I want to try, I want to see which
  ones I still haven't been to and be nudged toward the next one, so my list turns into actual
  visits instead of a pile.*
- **Journey:** save cafes to Want to Try → visit some → see progress → be motivated to visit
  the rest.
- **Evidence:** the review's screenshots and source (`PlacesProgress`,
  `PlacesProgressPill`, `cafe_status_pills.dart`); the retention plan and teardowns brief
  (`nook-marketing/research/2026-10-retention/teardowns/README.md`); Refero flows. **No funnel
  exists** for this journey: the pill has no events and the branch is not released. Live
  context only: 6 of 147 external users had ever saved as of 2026-10-15 (retention plan §2.1),
  week-1 retention under 7%.

## Journey today

Scores are single-rater, after NN/g PURE: 1 easy, 2 noticeable effort, 3 hard enough to give
up. Walkthrough questions: try / notice / connect / see it worked.

| # | Step (seen unless marked) | What they must know or decide | Confirms | Score | Walkthrough fails |
|---|---|---|---|---|---|
| 1 | Cafe page → **Want to try** pill. Toast "Saved for your next coffee run" (guest's first save: the keep-saves line) | — | Filled pill, toast | 1 | — |
| 2 | Home "Your places" and Saved "Your lists" show a pill "Been to 0 of 3" with a 14px ring (`zero-home.png`, `zero-saved.png`) | What is being counted? | — | 2 | **connect**: the empty ring reads as an empty radio; "0 of 3" counts a goal never set |
| 3 | Choose which one to visit: Saved lists Want to try rows (photo, name, area, distance, open state, chevron); Home rail shows the same cafes as cards. No sort or filter by open now or nearest; the pill is not tappable (code: "Read-only") | Which saved cafe fits now | — | 2 | **try**: nothing on the pill leads to "the ones left" |
| 4 | Go: Cafe page → Directions → Google Maps | — | Maps opens | 1 | — |
| 5 | After the visit, come back and mark it: open Nook → find the cafe → Cafe page → **Been** pill. Guest: toast "Added to Been · Add a note". Signed in: the ranking flow. Nothing in Nook asks "did you go?" (code) | Remember to do it | Pill, toast | 3 | **try**: nothing prompts it; the directions nudge only offers "Save to Want to Try?" |
| 6 | See progress: pill now "Been to 1 of 3", the ring a short dark arc (`some-home.png`, `some-saved.png`). The toast does not mention progress | Did it move? | Only if they look | 2 | **see it worked**: the arc reads as a loading spinner (review finding 1) |
| 7 | Be pulled to the next one: no "2 left", no suggestion, no link from the pill | — | — | 3 | **try / notice**: no next step |
| 8 | Finish: Saved shows "Been to all 3" with a check; Home shows no pill (`all-saved.png`, `all-home.png`) | — | Only on Saved | 2 | **see it worked**: the one good-news moment isn't on Home |

Single-rater total: **16** (8 steps).

States: nothing saved (pill hidden, empty state "Start your Want to Try list", seen); 0 of N
(seen); some (seen); all (seen); text scale 2.0 (pill crowds the title, seen `f2-*`); large
counts (code only); signed-in counts (code only); offline (not reachable).

**How the count behaves (code, `places_progress.dart`):** `been of (been + wantToTry)`. Two
consequences:
- Saving one more Want to try lowers the ratio: "1 of 3" becomes "1 of 4". The action Nook
  most wants (saving) shows as going backwards.
- A cafe marked Been straight away, never on Want to try, raises both numbers. Someone who only
  logs places they've been sees "Been to all 5" without ever having had a goal.

## How others do it

Contact sheet: `/tmp/ux-visited-progress/sheet-b.png` (not committed).

- **Blackbird, challenge progress** ([9027](https://refero.design/flows/9027)), 8 steps:
  home tile "Spend $30, earn $10" → detail → **Accept** → "In progress · $0/$30" with "Pay with
  Blackbird for the activity to appear here" → home tile now "16 days left" with a ring. Its
  home also shows "Progress to 2X Rewards · 0/5 Dines". Notable: the person **opts in** to the
  goal before any 0 is shown, the screen says **how progress is made**, and progress updates
  itself from the action (paying, checking in) rather than from a manual tick.
- **Waterllama, daily goal** ([11531](https://refero.design/flows/11531)), 3 steps: big total
  and "22% of your goal" → one-tap drink icons on the same screen → "92%" → at 100% "Cheerful
  Tuesday!", confetti, "Celebrate my day!". Notable: **the action that moves progress sits next
  to the progress**, and the finish is a moment.
- **Netflix, My List** ([10568](https://refero.design/flows/10568)), 3 steps: My List with chips
  "TV Shows · Movies · Haven't Started · Started" → pick "Haven't Started" → the list of what's
  left, each with a play button. Notable: **"what's left" is one tap**, and each row has the
  next action on it.

Pattern: progress is shown where the next action is, and progress moves because of something
the person did in the app at that moment. Split: Blackbird and Waterllama make an explicit goal
(accepted, or set as a daily target); Netflix has no goal at all, just a filter for "not yet".

Teardowns brief (supporting): it already lists **"Visited 3 of 8" on the Your places rail**
(Google Maps) as item 2, and item 4 is the missing half of this loop: treat a directions tap as
a likely visit, and ~90 minutes later ask "How was [cafe]?" with a **"Didn't go"** answer (Too
Good To Go + Google Maps), then Beli's post-visit ranking. It also says not to copy streaks or
guilt copy (Duolingo).

## Findings

Ranked by severity, then evidence (`seen` > `code` > `inferred`).

1. **Major · code · step 5 — nothing turns a visit into a Been, so the count rarely moves.** The
   pill is only as good as the Been data, and Been depends on the person remembering, after
   leaving the cafe, to reopen Nook, find the cafe and tap Been. The directions nudge offers
   "Save to Want to Try?", never "Did you go?". *Cost:* for most savers the pill stays at
   "0 of N" for good, which makes it a reminder of not going rather than progress.
   *Reference:* Blackbird updates progress from the qualifying action; Waterllama puts the
   logging tap beside the total; the teardowns' TGTG/Google Maps pattern asks after a
   directions tap, with "Didn't go". *Change:* after a Directions tap on a Want to try cafe,
   on the next Nook open (and, later, in the 90-minute local notification from teardowns item
   4) show a one-line prompt "Did you make it to Cafe de Lilo?" · **Been** · Not yet. Add a
   one-tap "Mark Been" on Want to try rows in Saved (a trailing check, or swipe with a menu
   alternative so it is not drag-only, WCAG 2.5.7).
2. **Major · code · steps 3 and 7 — the pill is read-only, so progress never points at the
   next visit.** "Been to 1 of 3" says how far, not what next. *Cost:* the motivation the pill
   could create has nowhere to go; the person must work out which two remain and which is open
   or near (recall, not recognition). *Reference:* Netflix's "Haven't Started" chip; Blackbird's
   tile opens the detail with how to progress. *Change:* make the pill a button: it opens Saved
   on Want to try, sorted open-now first, then nearest. Under the pill on Home, one line
   "Nearest to try: Cafe de Lilo · 13.8 km · opens 11 AM" when there is one.
3. **Moderate · seen · steps 2 and 6 — the ring reads as a spinner or an empty radio.**
   (`some-saved.png`, `zero-saved.png`; review finding 1.) *Cost:* the pill looks like
   loading at 1 of 3 and like a control at 0. *Reference:* Waterllama and Blackbird lead with
   the number and use a ring that fills a visible share. *Change:* review finding 1 (filled
   pie or no graphic below one Been; track at 3:1).
4. **Moderate · seen · step 2 — "Been to 0 of 3" counts a goal the person never set.**
   (`zero-saved.png`.) Blackbird shows "0/5" too, but only after the person accepted the
   challenge. *Cost:* the first thing a new saver sees about their list is a zero, at the
   moment Nook wants them to feel they've started (the teardowns' "no guilt copy" rule).
   *Change:* below one Been, show "3 to try" with the bookmark glyph; show "Been to 1 of 3"
   from the first Been.
5. **Moderate · code · steps 1 and 8 — the ratio goes down when you save and is inflated by
   direct Beens.** (See "How the count behaves".) *Cost:* goal-gradient works only if the bar
   moves forward; here the healthy action (saving) moves it back, and the "all" state can show
   for someone with no Want to try history. *Reference:* Netflix avoids a ratio entirely;
   Blackbird's target is fixed once accepted. *Change:* show two counts, never a falling
   ratio: "1 been · 2 to try". If a ratio is kept, count only cafes that were on Want to try
   when marked Been; that needs a new additive column (e.g. `been_from_want_to_try`), never a
   change to existing rows (legacy-safe rule).
6. **Moderate · code · steps 6 and 8 — the moment progress moves is silent.** Marking Been
   shows "Added to Been · Add a note"; finishing the list shows nothing on Home. *Cost:* the
   peak of this journey (a visit logged, a list finished) passes without a beat, so the
   person doesn't connect the pill with what they just did (peak-end rule). *Reference:*
   Waterllama's "Cheerful Tuesday!" at 100%; Blackbird's tile changing to "In progress".
   *Change:* when a Want to try becomes Been, the toast says "Been to 2 of 3 · 1 left" (or "1
   been · 1 to try") and the pill animates its fill; at the last one, a one-time card on Home
   "You've been to all 3 · Find more to try" (review finding 5).
7. **Minor · seen — at text scale 2.0 the pill takes the title's line.** (`f2-saved.png`,
   `f2-home.png`; review finding 2.) *Change:* wrap the pill under the title.
8. **Minor · code — the pill and "See all" can't coexist on Home.** If Your places gets a See
   all, the pill silently disappears (review). With finding 2, the pill *is* the way into the
   list, which settles it.

## Recommended flow

1. Save to Want to try. Toast "Saved · 3 to try" *(changed: finding 4)*.
2. Home "Your places" header: **"3 to try"** (no zero), tappable *(changed: findings 2, 4)*.
3. Tap → Saved on Want to try, open-now first then nearest; or Home's line "Nearest to try:
   …" *(changed: finding 2)*.
4. Directions → Maps.
5. Next Nook open: **"Did you make it to Cafe de Lilo? · Been · Not yet"**; or one-tap Been
   on the Saved row *(changed: finding 1)*.
6. Toast **"1 been · 2 to try"**, the pill updates with a short fill animation *(changed:
   findings 5, 6)*.
7. The pill and "Nearest to try" now point at the next cafe *(changed: finding 2)*.
8. Last one: a one-time Home card "You've been to all 3 · Find more to try" *(changed:
   finding 6)*.

Single-rater: before **16** (8 steps), after **8** (8 steps, each 1).

Scope note: step 5's in-app prompt needs only the existing directions-tap signal and a local
flag; the 90-minute notification is teardowns item 4 and a separate build.

## To test with real people

| Question | Method | Exact task or prompt | Success |
|---|---|---|---|
| What does the pill say to people? | Five-second test, 5 people, `some-home.png` and `zero-home.png` | "What was the small grey label next to 'Your places' telling you?" | 4 of 5 say "how many I've visited"; nobody says "loading" |
| Does "0 of 3" feel like a start or a scold? | 5-person interview after the five-second test | "You just saved three cafes and see 'Been to 0 of 3'. How does that land?" vs "3 to try" | Preference and wording; any "makes me feel bad" counts against the zero |
| Can people find what's left? | First-click test on Home (`some-home.png`) | "Show me the saved cafes you haven't been to yet." | Today: count first clicks on the pill (it does nothing). After finding 2: 4 of 5 get there in one tap |
| Will people mark a visit unprompted? | 5-person task test, think aloud, on a phone with 3 Want to try saves | "You went to Coffee Madness yesterday. Tell Nook." | Under 30 s, without help; note who looks at the pill, Saved, or search first |
| Does the after-directions prompt get answered honestly? | Analytics (HEART: Task success) | Goal: visits get recorded. Signal: share of directions taps on Want to try cafes followed by a Been within 7 days. Events to add: `visit_prompt_shown`, `visit_prompt_answered` (`been`/`not_yet`), and a `source` on status changes (`prompt`, `row`, `cafe_page`) | Over 30% of prompts answered; "Not yet" is a real share (if 0%, people may be tapping Been to dismiss it) |
| Does progress bring people back? | Analytics (HEART: Retention) | Signal: savers with at least one Been who return within 14 days vs savers with none. Event to add: `places_progress_tapped` | Savers with a Been return more often; with ~150 installs read it as a direction, not a result |

Next job suggested: `part` for the pill and the "Nearest to try" line on Home, after the
two-counts vs ratio decision (finding 5) is made.
