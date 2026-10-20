# Guest saves and the keep-saves ask · UX research (2026-10-16)

Job: partwise **ux**. This is desk research and an expert walkthrough of branch
`feat/retention-v1` @ `c9d6027` on the Android emulator (Pixel 7, API 35, signed out). It is not
user research, and nothing here reports what a user said or did. The "as it is" screens come
from the review: see `review-shots/` and the two contact sheets `ux-sheet-guest-save.jpg` and
`ux-sheet-directions-nudge.jpg`. Companion review: `partwise-review-guest-saves.md`.

Product direction, taken as decided: guest saves have no cap, the sign-up ask stays soft and
can always be dismissed, and an engagement score will trigger it later.

## Question

**How does a guest get from first open to a save they keep, and back again, and where does
the current flow lose them?**

- **Product:** a local cafe discovery and saving app, like Beli, Mapstr, Google Maps Saved,
  Blackbird. Lookup-driven, used weekly to monthly (retention plan R7).
- **People:** someone in Metro Cebu with an Android or iPhone, often with a friend, deciding
  where to go now or soon. Job: *When I find a cafe I might like, I want to keep it somewhere
  I'll see it again, so I can actually go next time I'm out, without making an account first.*
- **Journeys:**
  1. Guest opens Nook → browses → saves a cafe → is asked to keep saves / signs in → comes back later.
  2. Sub-journey: Directions tap → Google Maps → back in Nook → save nudge.
- **Evidence:** the running branch, its source, `research/2026-10-retention/NOOK_RETENTION_PLAN.md`
  (PostHog and DB figures as of 2026-10-15), the teardowns brief (Pinterest, Beli, Mapstr, TGTG,
  Google Maps, Duolingo), and Refero flows. No funnel exists for these journeys: the
  `keep_saves_prompt_*`, `signin_prompt_*`, `directions_save_nudge_*` and `home_rail_*` events
  are on this branch but not live. The only live figures are 6 of 147 external users ever
  saved, all signed in, with a median of ~54 days to first save (plan §2.1, R4).

## Journeys today

Step scores are single-rater, NN/g PURE: 1 = easy, 2 = noticeable effort, 3 = hard enough to
give up. The four walkthrough questions are: try (will they try the right thing), notice
(will they see the control), connect (will they link it to their goal), see it worked.

### J1. Open → browse → save → keep-saves ask → sign in → come back

| # | Step (seen) | What the person must decide or know | Confirms | Score | Walkthrough fails |
|---|---|---|---|---|---|
| 1 | First open: 3 onboarding slides (Skip top right) → "What are you looking for?" (4 options) → "A few to start with" (3 cafes, "Show me everything") | Pick a purpose, or skip | Lands on Home | 2 | — |
| 2 | Home: House picks, Fresh on Nook…; no Your places while empty (`10`) | Which cafe to open | Cafe page | 1 | — |
| 3 | Cafe page: Been / Want to try pills, plus a top-right bookmark (`30`) | Which control saves | — | 2 | **notice/connect**: two bookmark icons; the top one leads to a sign-in wall (`45`) |
| 4 | Taps Want to try: pill fills; toast "Saved on this phone. Sign in to keep it everywhere." · Sign in, 6 s (`44`) | Ignore, or sign in now | Filled pill | 1 | — |
| 5 | (Ignores it.) Later saves: "Saved for your next coffee run" / "Added to Been", with no Undo (`47`, `48`) | — | Toast + pill | 1 | — |
| 6 | Home again: "Your places" first, with saved and recently viewed cafes (`11`, `12b`) | — | The rail | 2 | **see it worked**: the newest saved card has no badge (review finding 1); nothing says why a cafe is there |
| 7 | Saved tab: "Your lists", keep-saves card, then Want to try / Been (`21`) | Sign in now? | — | 1 | — |
| 8 | Sign in from the card: sheet "Keep your saves on any phone", terms checkbox, Continue with Google, Continue with email, Not now (`22`) | Tick the terms, pick a provider | — | 2 | **try**: Google without the tick shows a red error (`23`) |
| 9 | Google account → (username step, then) back in the app; saves move to the account | — | **Nothing** (code: `GuestSavesSync._merge` is silent) | 2 | **see it worked** (code, not walked) |
| 10 | Comes back days later: Home opens on Your places | — | The rail | 1 | — |

Single-rater total: **15** (10 steps). Steps 9–10 after sign-in were judged from the source; no
real account was created.

States: empty Saved (shown, `20`); empty rail (hidden, shown, `10`); save failure ("Couldn't
save. Please try again.", code); Undo after remove (code); offline (not reachable in this run);
merge partial failure (code: silent).

### J2. Directions → Maps → back → save nudge

| # | Step (seen) | Decide / know | Confirms | Score | Walkthrough fails |
|---|---|---|---|---|---|
| 1 | Taps Directions in the bottom bar (`30`) | — | Google Maps opens (`40`; first-run screens on a fresh phone are Maps', not Nook's) | 1 | — |
| 2 | Comes back to Nook (Back, or the recents screen) | — | The same cafe page | 1 | — |
| 3 | After 0.6 s, a toast: "Save to Want to Try?" · Save, 6 s, once per cafe per session (`42`) | Save or ignore | — | 2 | **notice**: in one of two runs it was gone before it could be tapped |
| 4 | Taps Save: pill fills; "Saved for your next coffee run" (or, on a guest's first save, the keep-saves line) (`47`) | — | Pill + toast | 1 | — |

Single-rater total: **5** (4 steps).

## How others do it

Refero has no flow that shows a guest save followed by a soft ask, a merge confirmation, or a
prompt on returning from directions. Two scouts ran ~13 queries between them. The flows below
are the nearest real ones, and findings that depend on the missing parts are marked
`inferred`. Contact sheets: `/tmp/claude-1000/ux-guest-saves/` and
`/tmp/claude-1000/ux-directions-nudge/` (local only, not committed). The teardowns brief
(`teardowns/README.md` §1–3) covers the gap: Pinterest web caps guest saves at 2, asks at a
score, and carries saves into the account with "Saved 2 … to your list".

**J1**
- **ASOS** (refero.design/flows/2937, 13 steps): the heart on a guest's item goes straight to
  an OS sign-in alert with no reason given, then a web sign-in page that opens on SIGN IN, not
  JOIN. Nothing is saved as a guest. This is the hard wall Nook just removed.
- **Airbnb** (flows/6393, 3 steps, signed in): heart → "Save to wishlist" sheet → toast with a
  thumbnail, "Saved to <list>" · **Change**. You save first and re-file later.
- **Blackbird** (flows/9026, 5 steps): one **Save** button next to Get Directions → a "Save to"
  sheet with two fixed lists, **Favorites** and **Want to Go** → the chosen lists stay on the
  page as filled pills. Google Maps' Saved tab (screen 7d12720e) leads with "Recently saved".
- Soft-ask copy found: Promova "Save your progress / Create a profile to save your progress",
  with Apple and email buttons, "MAYBE LATER" and an X. There is no terms tick before the
  provider buttons. Google Maps' own first run, seen on the emulator (`41`): "Make it your map ·
  Sign in for quick access to your favorite places", with Skip.
- **Pattern:** one save control on the place page; confirmation shown on the page itself
  (filled state), not only in a toast. **Split:** whether a guest can save at all (ASOS no;
  Pinterest yes, capped; Nook yes, uncapped).

**J2**
- **Blackbird** (flows/9026): Save and Get Directions sit side by side, and there is no prompt
  on return: the saved state is simply visible on the page.
- **District** (flows/12862): after the outbound action (a confirmed booking), a bottom sheet
  offers the next step ("Invite your guests") with an X. The follow-up stays on the page
  afterwards ("Pay bill").
- **Airbnb** (flows/6388): a self-dismissing toast, "Saved to Wanderlust" · Change, over a
  heart that stays filled.
- **Pattern:** the follow-up appears on the screen the person comes back to, costs one tap,
  and costs nothing to ignore. **Split:** a modal sheet with an X (District) or a passive state
  on the page (Blackbird, Airbnb). None of them offers the follow-up once and then takes it
  away.

## Findings

Ranked by severity, then evidence.

1. **Major · seen · J1 step 3.** A guest who taps the top-right bookmark gets "Sign in to save
   to a list", next to a Want to try pill with the same icon that saves freely. *Cost:* the
   most familiar save position teaches the old lesson, "saving needs an account". Since 30 of
   46 real users never took an action, the first save attempt matters most. *Reference:*
   Blackbird has one Save that opens Favorites / Want to Go; Airbnb has one heart. *Change:* for
   guests, the top-right control saves to Want to try (or offers Want to try / Been). Give
   custom lists a distinct "Add to list" icon, walled only for list creation.
2. **Major · code · J1 step 9.** After sign-in the saves move silently, and failures are silent
   too. *Cost:* the sheet promised "everything you saved on this phone moves to your account".
   With no confirmation, the person can't tell that the account kept anything, at the moment
   that most shapes how sign-up is remembered (peak-end). *Reference:* the teardowns brief
   (Pinterest: "Saved 2 … to your list"); Airbnb confirms every save with a toast. *Change:* a
   toast "Moved 3 cafes to your account" · View; on partial failure, say so and retry.
3. **Major · seen · J1 step 8.** A terms checkbox comes before Continue with Google. *Cost:*
   the one-tap ask becomes tick + tap, and skipping the tick shows an error in red (`23`), on
   the step meant to feel lightest. *Reference:* Promova and Google Maps show provider buttons
   with no tick. *Change:* "By continuing you agree to…" under the buttons, with acceptance
   recorded on tap. Confirm first that this satisfies App Store guideline 1.2 for a UGC app.
4. **Moderate · seen · J2 step 3.** The nudge is a 6 s toast, shown once per cafe per session,
   and it can be gone before the person looks. *Cost:* the moment it targets, the Directions tap
   (35% of users did one; plan §2.1), is the most common high-intent action, and a missed
   offer isn't repeated. *Reference:* District keeps the follow-up visible until dismissed;
   Blackbird and Airbnb leave a persistent saved state. *Change:* 10 s, no timeout under
   TalkBack, and keep the Want to try pill visibly "ready" (a light tint) for the rest of that
   page visit.
5. **Moderate · seen · J1 steps 6 and 10.** "Your places" doesn't say why a cafe is in it, the
   newest saved card loses its badge, and the rail doesn't lead to Saved. *Cost:* the "second
   open looks different" reward (plan §3.1) is the main reason to come back. If a saved cafe
   looks unsaved, the reward reads as a random shelf. *Reference:* Google Maps "Recently saved"
   on the Saved tab; the teardowns' "Visited 3 of 8". *Change:* fix the badge (review finding
   1); add the subtitle "Saved and recently viewed" and See all → Saved. Later, show progress
   ("Been to 1 of 3").
6. **Moderate · inferred · J1 steps 4–7.** The ask appears once as a toast (first save, 6 s),
   then only on the Saved tab card. A guest who never opens Saved never sees it again.
   *Cost:* within the decided soft direction this is acceptable, but it gives the coming
   engagement score only one surface to work with. *Reference:* teardowns §1 (Pinterest asks
   when a score crosses ~20, Google one-tap at the ask). *Change:* when the score lands, use it
   to show **one** dismissible sheet (the same keep-saves sheet) at a moment of value: after
   the 3rd save or the 2nd session with saves. Each dismissal lowers the score. No cap, no
   blocking second ask: the decided direction overrides Pinterest here.
7. **Minor · seen · J1 steps 5–7.** One thing has five names: "Saved" tab, "Your lists" page,
   "Your places" rail, "Want to Try" and "Want to try". *Cost:* recognition over recall: the
   person has to work out that these are the same collection. *Change:* the page title
   "Saved", sentence case "Want to try" everywhere (review finding 7).
8. **Minor · seen · J1 step 5.** Save toasts have no Undo or View, while remove toasts have
   Undo. *Reference:* Airbnb's "Saved to … · Change". *Change:* "Saved to Want to try · View"
   (opens Saved), which also teaches where saves live.

## Recommended flow

**J1** (changes in bold)

1. First open → onboarding (unchanged; out of scope).
2. Home → cafe page.
3. **One save affordance:** the Want to try / Been pills, and for guests the top-right control
   does the same save (no wall).
4. Save → pill fills → first-save line "Saved on this phone. Sign in to keep it everywhere."
   · Sign in (**10 s**).
5. Later saves → "**Saved to Want to try · View**".
6. Home → "Your places" (**badge fixed, subtitle, See all → Saved**).
7. **At the engagement threshold (later): one keep-saves sheet**, dismissible, at a value moment.
   Until then the Saved tab card.
8. Sheet → **Continue with Google in one tap (terms as a line, not a tick)**.
9. **"Moved 3 cafes to your account" · View.**
10. Comes back → Your places.

Single-rater score: **15 → 11** (step 3: 2→1, 6: 2→1, 8: 2→1, 9: 2→1).

**J2**: Directions → Maps → back → "Save to Want to try?" · Save (**10 s, no timeout under
TalkBack, the pill stays tinted**) → "Saved to Want to try · View". Score **5 → 4**.

## To test with real people

| Question | Method | Task / prompt | Success |
|---|---|---|---|
| Do guests try to save at all, and where do they tap first? | First-click test, 5 people, signed out | "You like this cafe and want to remember it for later. Show me what you'd do." (cafe page) | ≥4 of 5 tap the pills or a save that works, not the walled control |
| Does "Saved on this phone" make the risk clear? | 5-second test on `44` | "What just happened? Is anything at risk?" | ≥4 of 5 say it's saved but only on this phone |
| Is the terms tick a real drop point? | 5-person task test (think aloud) | "Keep your saves so you don't lose them if you change phones." | All 5 finish; note any hesitation or error at the tick |
| Do people notice the post-directions nudge? | Task test, in person, with Maps | "Get directions here, then come back to Nook." | ≥3 of 5 notice the offer unprompted |
| Does "Your places" read as "my cafes"? | 5-second test on `12b` | "What is the first row on this screen?" | ≥4 of 5 say "places I saved or looked at" |
| Do guests hit the ask, and does it convert? (analytics, HEART: Adoption, Task success) | PostHog, 3 weeks after release | — | Signals: `keep_saves_prompt_shown` → `_tapped` → `signin_completed` by `surface`; `first_save` guest vs signed in; `directions_save_nudge_shown` → `_tapped`; `home_rail_card_tapped{rail:your_places}`. Add: `guest_saves_merged {count, failed}` (finding 2) |
| Do savers come back? (HEART: Retention) | PostHog cohort | — | Share of day-0 guest savers with an open on a later day within 7 days, against non-savers (the plan's activation definition) |
