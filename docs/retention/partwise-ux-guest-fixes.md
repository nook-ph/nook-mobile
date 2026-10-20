# Guest saves follow-ups (item 1 fixes) · UX research (2026-10-16)

Job: partwise **ux**. This is desk research and an expert walkthrough of branch
`retention/guest-fixes` @ `4a68151`. It is not user research, and nothing here reports what a user
said or did. "The journey as it is" comes from the review run (`partwise-review-guest-fixes.md`,
shots in `review-shots-guest-fixes/`, emulator-5554, ask threshold lowered to 5 for the run) and from
the source in `lib/features/guest_saves/`. No emulator was used for this study.

This study builds on the review's findings N1–N8; it does not repeat them. Where a review finding
already names the fix, this doc says only what the *flow* should be around it.

Product decisions taken as fixed: guest saves are unlimited; the ask is soft, always dismissible
and triggered by the engagement score; the terms checkbox stays (App Store 1.2).

## Question

**Now that a guest can save freely and is asked by score, does the ask land at a moment of value,
does it back off properly when declined, and does it stay out of the way of the trip?**

- **Product:** local cafe discovery and saving (Android-first Flutter), like Beli, Mapstr, Google
  Maps Saved, Blackbird.
- **People:** a guest in Metro Cebu on an Android phone, deciding where to go now or soon. Job:
  *When I find a cafe I might go to, I want to keep it where I'll see it again, without making an
  account, so I can actually go next time I'm out.*
- **Journeys:**
  1. Guest opens Nook → browses → saves → keeps saving → is asked at a value moment → signs in or
     not → saves moved.
  2. Directions → Maps → back → nudge / reminder.
  3. A guest who declined the ask twice keeps using Nook.
- **Evidence:** the review's 31 shots, the source (`sign_up_ask_rules.dart`, `engagement_score.dart`,
  `sign_up_ask_on_home.dart`, `save_actions.dart`, `directions_save_nudge.dart`,
  `launch_cafe_directions.dart`, `guest_saved_page.dart`, `main_screen.dart`), the earlier study
  `partwise-ux-guest-saves.md`, and Refero. **No funnel data:** the `signup_ask_*`,
  `guest_saves_merged` and `directions_save_nudge_*` events exist only on this branch.

### The score rules as built (code)

| Rule | Value |
|---|---|
| Points | save 5, search 5, directions 5, cafe view 0.5, one return session within 30 days +5 (once ever) |
| Asked when | score ≥ 20, has saves, fewer than 3 asks ever, last ask ≥ 7 days ago |
| Where | right after a guest save (`after_save`, not when the save came from the directions nudge), and on any return to Home after a 900 ms settle (`home_return`) |
| Decline | −5 (equal to one save) |
| Not counted as asks | the Profile-tab sign-in sheet, the visit reminder's "I went" ranking sheet, the review/report walls, the notification pre-prompt before Maps |

## Journeys today

Single-rater step scores (NN/g PURE: 1 easy, 2 noticeable effort, 3 hard enough to give up).
Walkthrough questions: try / notice / connect / see it worked.

### J1. Open → save → keep saving → ask → sign in or not → saves moved

| # | Step | Seen in | Score | Walkthrough fails |
|---|---|---|---|---|
| 1 | Home, opens a cafe (+0.5) | `01`, `02` | 1 | — |
| 2 | First save (pill or top-right): pill fills; "Saved on this phone. Sign in any time to keep it." · Undo | `07` | 1 | — (truncates at 2.0×: N8) |
| 3 | Later saves: "Saved to Want to try · Undo · View" | `09` | 1 | — |
| 4 | The save that crosses 20: the sheet opens **instead of** the confirmation; the filled pill is hidden behind it, and the title is about "saves" in general | `03` | 2 | **see it worked** |
| 5 | Sheet: tick terms (or tap Google once to reveal inline terms) → Agree and continue with Google / Continue with email / Not now | `04`, `35` | 2 | — (two taps, as decided) |
| 6a | Not now: sheet closes, no toast, no Undo | `05` | 2 | **see it worked** (N4) |
| 6b | Google → account → saves move → "Moved 3 cafes to your account · View", over the tab bar | `40`, `41` (debug preview) | 1 | — (placement: N7) |
| 7 | Or: the ask comes on a plain return to Home, 0.9 s after landing, covering Your places | `43` | 2 | **try**: they came to Home to do something else |

Total **11** (7 steps; 6a/6b scored once, as the worse branch).

### J2. Directions → Maps → back → nudge / reminder

| # | Step | Seen in | Score | Walkthrough fails |
|---|---|---|---|---|
| 1 | Taps Directions. If a visit reminder would go out and notifications are off, the pre-prompt sheet comes first, naming the time | code (`launchCafeDirections`), local-notifications review | 2 | — |
| 2 | Google Maps opens (+5) | `13` | 1 | — |
| 3 | Back in Nook, same cafe page; 0.6 s later "Save to Want to try?" · Save, 10 s; pill stays tinted | `14`, `15` | 1 | — |
| 4 | Save → first-save line or "Saved to … · Undo · View" (no score ask: the nudge source is excluded) | `42` | 1 | — |
| 5 | Back to Home → the score sheet opens about 1 s later | `43` | 2 | **try** (N5) |

Total **7** (5 steps). A single trip can carry three asks: notifications before Maps, the save
nudge on return, and the sign-up sheet on Home.

### J3. A guest who declined twice keeps using Nook (code, not walked)

Worked through the rules with a typical guest (four saves, a few views):

| # | Moment | What happens | Score |
|---|---|---|---|
| 1 | Day 0, 4th save: ask 1. Not now → score 20.5 → 15.5 | sheet, no confirmation of the save | 2 |
| 2 | Same week: one more save puts the score back over 20; the cooldown alone holds the ask | — | 1 |
| 3 | Day 7+, first save or first Home return: ask 2, **the same sheet, same copy**. Not now | sheet | 2 |
| 4 | Day 14+, first save or Home return: ask 3, same sheet. Not now | sheet | 2 |
| 5 | After that, no score ask ever again, whatever happens (50 saves, a new phone on the way) | — | 1 |
| 6 | Throughout: the Saved tab leads with the keep-saves card, no way to tuck it away; Profile tab tap opens a sign-in sheet; "I went" on a reminder opens the ranking sign-in sheet, none of which count toward the 7-day spacing | `20`, code | 2 |

Total **10** (6 steps). The decline costs one save's worth of points, so it hardly moves the next
ask; the 7-day cooldown is the only real back-off, and the three-ask cap the only stop.

## How others do it

Refero is thin for all three journeys: it has no flow of a guest save followed by a soft ask, no
guest-to-account merge, and no true leave-and-return-from-Maps. The scouts ran about 30 queries.
The flows below are the nearest real ones; findings resting on the gap are marked `inferred`.
Contact sheets are local only (`/tmp/claude-1000/ux-guest-fixes/ux-j1..j3/`, not committed).

**J1 (save, then the ask)**
- **ASOS** (refero.design/flows/2937, 13 steps): the guest's heart goes straight to an OS sign-in
  alert; the save is dropped, the form is long and the flow ends with no resume. The anti-pattern
  Nook has already left.
- **Google Translate** (flows/12143, 4 steps): "Back up your translation history" dialog, shown
  once there is history. Body: "Securely save translation history to your Google Account. View
  your translations on any device…". Three buttons, the decline worded as a positive choice:
  **"Use Translate without an account"**, "Manage history", **Back up history** (primary).
- **Promova** (screen 6b3754f8): "Save your progress / Create a profile to save your progress",
  after a lesson, with **MAYBE LATER** as a small text link and a close X. Tripsy's modal
  (flows/2370) states the stake plainly: "access from other devices and a backup in case you lose
  your device. You can delete your account at any time."
- **Pattern:** the ask names the thing it protects, and comes when that thing exists. **Split:**
  decline as "later" (Promova), as "cancel" (Tripsy), or as a full alternative ("without an
  account", Google Translate). None shows a merge confirmation; Nook's merge toast is ahead of
  every reference found.

**J2 (leave the app, come back)**
- **District** (flows/12862): after the booking, one bottom sheet ("Invite guests") over the
  confirmed page; the contacts permission appears only if the person picks contacts. No
  notification or sign-up ask in the same flow; the rating comes later, on its own screen
  (flows/12916).
- **komoot** (flows/8397): after finishing a route, five follow-ups in one wizard (stars first,
  then photos, people, highlights, save) with **Skip all** on every step: many asks, but one
  surface and one exit.
- **Fresha** (flows/4974): nothing is pushed; "Add to calendar" and directions are standing rows
  on the appointment, and the reminder is set in the OS calendar, so the app never asks for
  notification permission.
- **Pattern:** one push per trip at most, attached to the result the person cares about; the OS
  permission sits behind the person's own tap. **Split:** push one sheet (District), push one
  skippable wizard (komoot), or push nothing (Fresha).

**J3 (after declining)**
- **Tripsy** (flows/2370): a permanent "Save your trips / Login or create an account" card at the
  top of Settings, no dismiss; the modal it opens is the only ask.
- **Vocabulary** (flows/3811): only a "Sign in" row under Account in Settings, which becomes
  "Account" once signed in. No badge, no interruption.
- **Google Translate** (above): the profile icon in the header stays as the entry; the dialog's
  "without an account" answer is a real choice, not a deferral.
- **Pattern:** after a decline, what remains is a standing, labelled entry in a place the person
  visits on purpose (Settings, profile slot, the saved area), worded as navigation, never as a
  warning. **Split:** whether the push ask returns at all (Promova implies yes; Tripsy and
  Vocabulary show none). None escalates copy after a decline, none offers "don't ask again".

## Findings

Ranked by severity, then evidence. They build on N1–N8; a finding that extends one says so.

1. **Major · seen + code · J1 step 4 (extends N4).** The ask takes the place of the save's
   confirmation, and the sheet talks about "your saves" in the abstract. *Cost:* the one moment the
   person has just shown intent ends with a blocking sheet about accounts, and the thing they did
   is hidden behind it; after Not now, nothing confirms it either. The ask feels like a toll on the
   save, which is what the unlimited-saves decision is meant to avoid. *Reference:* Google
   Translate asks when history exists and names it; Promova names "your progress". *Change:* the
   flow should be **confirm, then ask**. The sheet opens with the confirmation as its first line
   ("✓ Flavour Coffee Station saved to Want to try"), the title names the count ("Keep your 4
   cafes on any phone"), and on any close without sign-in the normal save toast (Undo · View)
   follows, as N4 says.
2. **Major · code + seen · J2, whole trip (extends N5).** Three separate ask systems can each fire
   once around one trip: the notification pre-prompt before Maps, the save nudge on return, the
   score sheet on the next Home. N5's fix (skip `home_return` after a nudge) closes only one pair;
   the pre-prompt and the score sheet know nothing of each other, and the pull sheets (Profile tab,
   "I went") don't count either. *Cost:* the Directions tap is Nook's most common high-intent
   action (35% of users, plan §2.1), and it is where asks pile up. *Reference:* District and komoot
   show one push surface per outcome; Fresha none. *Change:* one **session ask budget** shared by
   every surface: at most one *sheet* per session (the pre-prompt, the score ask, or a reminder
   sheet), toasts like the nudge don't spend it; and when the person dismisses any sign-in sheet
   they opened themselves (Profile tab, a review wall), no score ask in that session.
3. **Moderate · seen · J1 step 7.** A plain return to Home is treated as a value moment. *Cost:*
   people come back to Home to go somewhere else (search, the next cafe); 0.9 s later a sheet
   covers Your places (`43`). It is the most frequent trigger and the least related to saves.
   *Reference:* Google Translate asks on the history surface; Tripsy and Vocabulary put the entry
   where the person goes on purpose. *Change:* replace `home_return` with **opening Saved (or "See
   all") with 3+ saves**, where the sheet is about exactly what is on screen. Keep `after_save`.
4. **Moderate · code · J3 steps 1–4.** Declining barely backs off. −5 is one save, so the score is
   back over 20 within a save; the 7-day cooldown alone spaces asks 2 and 3, which then arrive at
   the first save or Home return of the week, with identical copy. After the 3rd there is never
   another score ask, even for a guest with 50 saves. *Cost:* the same question three weeks in a
   row reads as not listening; then permanent silence misses the one case where the stake has
   grown. *Reference:* no reference escalates copy; Tripsy/Vocabulary keep a standing entry
   instead of re-asking. *Change:* make each decline cost more: cooldown 7 → 21 days after the
   second decline, and threshold +10 per decline. Ask 2 carries the stake in plain words
   ("Your 9 cafes are only on this phone"), not pressure. After the 3rd ask, allow one more only
   when saves have doubled since the last one. Offer a positive decline on ask 2+: "Keep using on
   this phone" (Google Translate's "without an account"), which ends score asks.
5. **Moderate · code · J1 step 5, J3.** "Continue with email" is logged as accepted the moment it
   is tapped (`SignUpAskAnswer(accepted: choice != null)`), even if the person backs out of
   `/login`: no −5, an ask used, and `signup_ask_accepted` over-counts. *Cost:* the one funnel this
   feature exists to move will report a conversion that didn't happen; the back-off rules also
   misfire for that person. *Change:* treat it as accepted only when a session starts within the
   sheet's lifetime or the `/login` visit; log `signup_ask_completed` separately.
6. **Moderate · inferred · J3 step 6.** After declines the Saved tab still leads with the full
   keep-saves card, above the person's own cafes, on every visit. *Cost:* the tab they open for
   their cafes opens on our ask; mild, but it's the surface they return to most. *Reference:*
   Tripsy keeps a top card, but in Settings, a page visited rarely; Vocabulary uses one row.
   *Change:* keep it permanent (no dismiss needed), but after the second decline move it below the
   lists as a one-line row: "On this phone only · Sign in".
7. **Minor · code · J1 steps 2–3.** Undo re-adds +5 on every toggle (save → Undo → save), and a
   removal takes nothing off. *Cost:* the most indecisive guest reaches the ask soonest, on a save
   they may just have reversed. *Change:* points for a cafe's save once per cafe; removing or
   undoing takes them back.
8. **Minor · code · J3.** Other sign-in sheets don't mention saves: the Profile tab sheet says
   "Your cups, lists and rankings…", and the search origin picker says "Sign in to save places",
   next to cafes that save freely. *Cost:* a guest with saves who signs in from there isn't told
   their cafes come along; "save places" contradicts what they learned. *Change:* when the guest
   has saves, add the line "Your N saved cafes move to your account"; rename the origin wall to
   "Sign in to keep Home and work".

## Recommended flow

**J1** (changes in bold)

1. Home → cafe page (+0.5).
2. Save → pill fills → first-save line **"Saved on this phone · Undo · View"** (N8).
3. Later saves → "Saved to Want to try · Undo · View". **Points once per cafe; Undo takes them
   back.**
4. Score ≥ 20 and **session budget unspent**, at **a save** or **opening Saved / See all with 3+
   saves** (not a bare Home return).
5. Sheet: **first line confirms the save ("✓ Flavour Coffee Station saved")**; title **"Keep your
   4 cafes on any phone"**; terms (as decided); Agree and continue with Google / Continue with
   email / **Not now**.
6a. Sign in → "Moved 4 cafes to your account · View", **above the tab bar** (N7) → Saved.
6b. Not now → **the usual save toast with Undo · View**; −5 and **threshold +10**; budget spent
    for the session.

Score **11 → 7** (step 4: 2→1, step 6: 2→1, step 7 removed; the sheet itself stays at 2, as decided).

**J2**

1. Directions → (pre-prompt only if a reminder is due; **spends the session's sheet budget**).
2. Maps → back → nudge toast "Save to Want to try?" · Save, 10 s, pill tinted (unchanged; a toast
   does not spend the budget).
3. Save → save toast.
4. Home → **no sheet this session** if the budget was spent or a nudge was shown (N5).

Score **7 → 5** (step 5 removed; the pre-prompt stays at 2 when it shows).

**J3**

1. Ask 1 declined → **threshold +10**, cooldown 7 days.
2. Ask 2 (at a save or on Saved) → **copy with the stake ("Your 9 cafes are only on this
   phone")** and a third choice **"Keep using on this phone"**, which ends score asks.
3. Declined → **cooldown 21 days, threshold +10**; **the Saved card becomes a one-line row below
   the lists.**
4. Ask 3 only **if saves have doubled since ask 2**; never more than that.
5. The row on Saved, the Profile tab sheet (**now naming the N cafes that come along**) and the
   reminder's ranking sheet remain as pull entries; **any of them dismissed blocks score asks for
   that session.**

Score **10 → 6** (step 1: 2→1, the save is confirmed; steps 3 and 4: 2→1 through spacing and copy; step 6: 2→1).

## To test with real people

| Question | Method | Task / prompt | Success |
|---|---|---|---|
| Does the ask feel like a toll on the save? | 5-person task test, think aloud, signed out, threshold lowered | "Save three cafes you'd like to try." (ask fires on the 3rd) | ≥4 of 5 say the cafe was saved, unprompted, after the sheet; none says they had to sign in to save |
| Which version of the sheet reads as "protect what I have"? | Five-second test, two variants (as built vs count + confirmation line) | "What is this asking you, and what happens if you say no?" | ≥4 of 5 on the variant say "saves stay either way" |
| Is Saved a better ask moment than Home? | First-click test on `43` vs a Saved-tab ask mock | "You came back to look for a place to go now. What do you do?" | On Home, how many close the sheet before anything else (expected high) |
| Does "Keep using on this phone" feel like a real choice? | 5-person task test, ask 2 mock | "You've been asked this before. Do what you'd normally do." | People pick it without hesitation, and say they'd still find Sign in later (on Saved) |
| Does a trip with a pre-prompt and a nudge feel like too much? | In-person task test with Maps | "Get directions here, then come back to Nook and keep browsing." | Count spontaneous complaints / sighs per ask; none past the first |
| Do people notice the Saved row after it shrinks? | Tree / first-click test | "Where would you go to make sure your cafes are safe if you change phones?" | ≥4 of 5 reach Saved or Profile first |

**Analytics to add** (HEART goals → signals → events):

| Goal | Signal | Event / property to add |
|---|---|---|
| Task success: the ask converts honestly | sheet shown → session started | `signup_ask_completed {trigger, ask_number, provider}` fired on the session, not the tap; keep `signup_ask_accepted` as "provider chosen" (finding 5) |
| Happiness: the ask isn't a toll | how people leave the sheet | `signup_ask_dismissed {how: not_now | swipe | back | stay_on_phone, saves_count}` |
| Adoption of the budget rule | asks we held back | `signup_ask_suppressed {reason: session_budget | cooldown | max_asks | below_threshold, trigger}` (sampled) |
| Task success at the trip | asks per directions trip | `directions_trip_asks {pre_prompt, nudge, signup}` counts per session, or a `session_id` on all three existing events |
| Engagement integrity | undo churn | `guest_save_removed {source: undo | pill}` |
| Task success after merge | people see what moved | `merge_toast_view_tapped {count}` |
| Retention | declining doesn't drive churn | cohort: guests with 2 `signup_ask_dismissed` → share with an open in days 8–30, against guests never asked |
