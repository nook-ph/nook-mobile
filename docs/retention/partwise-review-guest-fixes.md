# Guest saves follow-ups (item 1 fixes) · partwise review (2026-10-16)

Job: **review** (mode ios, written for Android-first Flutter with Material controls; target code).
Nothing in `lib/` was changed.

Branch `retention/guest-fixes`, commits `3886410..e8dff1a` on top of `retention/local-notifications`.
It is judged against `partwise-review-guest-saves.md` and `partwise-ux-guest-saves.md`, and against the
decided product direction, which this review does not argue with: guest saves are unlimited; the
sign-up ask is soft, can always be dismissed, and is triggered by the engagement score (save, search
and directions 5, cafe view 0.5, a return within 30 days +5, ask at 20 or more, -5 per dismissal, at
most one ask in 7 days and 3 in all); the terms checkbox stays (App Store 1.2), with inline terms and
"Agree and continue with Google".

**Looked at: Android emulator** `Pixel_7_API_35` (emulator-5554, 1080×2400, 420dpi), debug builds
with `--dart-define=NOOK_ASK_THRESHOLD=5`, real `.env` (318 bytes), signed out (guest), GPS set to
Cebu (123.8854, 10.3157). The emulator clock was moved to 10:30 so the cafes were open, and set back
to the real time afterwards. The run covered one batch at font scale 1.0, one at font scale 2.0, and
one at font scale 1.0 with TalkBack on. The merge toast was seen through the debug preview
(`NOOK_PREVIEW_MERGE_TOAST=all` and `=partial`), not through a real sign-in. Signed-in states (the
list-plus icon) were checked **from the source only**.

TalkBack caveat: taps sent with `adb input` skip TalkBack's touch exploration, so the TalkBack focus
never moved and "double-tap to activate" could not be tried. That run confirms only what
`MediaQuery.accessibleNavigation` changes (which toasts stay up and show a close button). What a
TalkBack user can activate is judged from the accessibility tree (`uiautomator dump`: `clickable`,
merged labels).

Screenshots are in `review-shots-guest-fixes/` (JPEG, 540 wide):

| Shot | What |
|---|---|
| `01-home-empty`, `02-cafe-page` | Fresh guest; cafe page with top-right bookmark and the Been / Want to try pills |
| `03-top-save-ask`, `04-ask-inline-terms`, `05-after-ask-dismiss` | Top-right save as a guest → score ask (threshold 5) → Google tapped unticked → Not now: **no save confirmation** |
| `07-first-save-line` | "Saved on this phone. Sign in any time to keep it." · Undo |
| `09-saved-to-toast`, `17-been-toast` | "Saved to Want to try · Undo · View", "Added to Been · Undo · View" |
| `10-save-undo-no-effect`, `10c-remove-undo-no-effect`, `12-undo-works` | Undo, early runs (no effect) and later runs (works); see finding 11 |
| `11-home-rail-2`, `19-home-rail-viewed` | Your places: subtitle, See all, correct badges, newest first |
| `14-nudge`, `15-nudge-gone-tint`, `16-save-from-tint` | Back from Maps: "Save to Want to try?" · Save; pill stays tinted ("Suggested") after 10 s |
| `18-top-save-over-been` | A guest's Been cafe: the top-right bookmark shows empty, and tapping it **replaces Been** with Want to try |
| `20-saved-tab` | Guest Saved tab: title "Saved", 14sp card body |
| `30`–`36` (`-fs2`) | Font scale 2.0: Home, Saved card (stacked), toasts, sheet, inline terms, **truncated first-save line** |
| `40-merge-all`, `41-merge-partial` | "Moved 3 cafes to your account · View", "Moved 2 of 3 cafes to your account · Retry": **over the tab bar** |
| `42-nudge-save-firstline`, `43-ask-home-return` | Nudge Save → first-save line → back to Home → **the ask appears within seconds** |
| `51-talkback-save-toast` | TalkBack on: the save toast stays up with Undo · View · close (X) |

---

## Original findings: what is resolved

Review (`partwise-review-guest-saves.md`):

| # | Finding | Status | Evidence |
|---|---|---|---|
| 1 | Saved cafe shows as unsaved in Your places | **Resolved** | `11`, `19`: both cards show their badges, newest first. The badge now uses `context.select` on its current id, and the rail cards are keyed |
| 2 | Sign-in wall on the cafe page's top-right save | **Resolved** for the wall | `02`, `03`: a guest's tap saves Want to try. Signed in it shows list-plus / list-checks (source only). New problems: findings N2, N3, N6 |
| 3 | Terms checkbox in front of Google | **Resolved within the decision** | `04`: no red error; the terms open inline and the button becomes "Agree and continue with Google". Still two taps, as decided |
| 4 | No confirmation after the merge | **Resolved** | `40`, `41`: View on success; on a partial merge, an honest count and Retry. Leftovers stay on the phone. New problem: N7 (placement) |
| 5 | Nudge on a 6 s timer, offered once | **Resolved** | 10 s; no timeout under TalkBack; the pill stays tinted for the rest of the visit (`15`) |
| 6 | Targets under 48dp | **Resolved** for the three named | Saved card button, empty-state button and Not now are all 48. New problem: the new top-right control is 40dp (N2) |
| 7 | Five names for one thing | **Resolved** | Page title "Saved"; "Want to try" in sentence case throughout the UI (only code comments still say "Want to Try") |
| 8 | Your places doesn't say why | **Resolved** | Subtitle "Saved and recently viewed", See all → Saved (`11`). Minor gap: N10 |
| 9 | Keep-saves card at large text; 12sp body | **Resolved** | `31`: the button stacks under the text above 1.3×; body is 14sp |
| 10 | No Undo on save toasts | **Mostly resolved** | `09`, `17`: Undo · View. The first-save line has Undo but no View, and a save that triggers the ask gets no toast at all (N4) |
| Home scorecard | Badge text 10sp | **Resolved** | 11sp |

UX (`partwise-ux-guest-saves.md`): findings 1, 2, 4, 5, 7 and 8 are resolved as above. Finding 3 is
resolved within the decision. Finding 6 is implemented: the score ask appears at two value moments
(after a save, and on returning to Home), and it is dismissible, rate-limited and lowers the score
when dismissed. Its timing next to the directions nudge is new finding N5.

---

## New findings (ranked)

### Must fix (excludes people)

**N1. Under TalkBack the persistent toasts can't be closed, and the close button isn't announced as
a control.** With a screen reader on, the save, first-save, nudge and merge toasts never time out,
which is what the earlier review asked for. In the accessibility tree, though, the close button's
`Semantics(button, label: 'Close', excludeSemantics: true)` around a bare `GestureDetector`
(`toast_helper.dart`, `_showToastBar`, "if (persistent)") merges into the message: there is one node,
`"Saved to Want to try\nClose"`, with `clickable=false`. The tap handler is excluded with the
semantics, so the node has no tap action. A TalkBack user can only clear the toast by choosing Undo
or View, or by waiting for the next toast. The new top-right save has the same pattern
(`_TopBarSaveIcon`, `cafe_details_page.dart`): its node is `clickable=false`.
**Fix:** give the semantics the action, `Semantics(button: true, label: 'Close', onTap: () =>
toastification.dismiss(holder), excludeSemantics: true, …)`, and the same `onTap: onTap` in
`_TopBarSaveIcon`. Also wrap the message `Text` in `Semantics(container: true, liveRegion: true)`,
so it is a separate node and gets announced.

### Should fix

**N2. The top-right save is 40dp.** `_TopBarSaveIcon` is `width: 40, height: 40` (105px on the
dump), below the 48dp floor that the same branch applied everywhere else. **Fix:** keep the
40dp white circle, but wrap it in a 48×48 hit area (`SizedBox.square(48)` + `Center`). Share and Back
beside it are also 40, so do all three together.

**N3. A guest's Been cafe looks unsaved at the top, and tapping it silently replaces Been.** In
`18`, the bookmark is empty while Been is selected. Tapping it runs `toggleGuestStatus(tapped:
wantToTry)`, which turns Been into Want to try, with only a toast to say so. The account has no
equivalent: signed in, the same position opens a list sheet. **Fix:** for guests, fill the icon when
the cafe has any status (a check for Been, the bookmark for Want to try). When the status is Been, a
tap shows "Already in Been" with "Move to Want to try" as its action, instead of switching.

**N4. A save that triggers the ask is never confirmed.** `_confirmGuestSave` returns as soon as
`maybeAsk` shows the sheet (`save_actions.dart`, `if (asked …) return`). After "Not now" (`05`),
there is no toast, no Undo and no View, only the filled pill behind where the sheet was. The sheet
title, "Keep your saves on any phone", doesn't mention the save that just happened either.
**Fix:** when the sheet closes without a sign-in, show the usual
`savedToMessage(status) · Undo · View` toast. Optionally open the sheet with a line that confirms the
save ("Saved to Want to try") above the title.

**N5. The ask lands seconds after the directions nudge.** In `42` → `43`, Save on the nudge is
followed by Back to Home, and the score sheet opens about 1 s later. The "one ask per trip" guard
covers only the save that comes from the nudge (`source != SavesSource.directionsNudge`).
`SignUpAskOnHome` treats the very next Home visit as a value moment, so the trip still gets two asks.
**Fix:** after a nudge has been shown, skip the `homeReturn` trigger for the rest of that session.
For example, record `DirectionsSaveNudge.offered` or a timestamp, and have `SignUpAskOnHome` skip
the ask within 30 min of it.

**N6. The removal toast still times out under TalkBack.** The guest removal ("Removed from Want to
try · Undo", `toggleGuestStatus`) passes no duration, so it closes after the default 5 s even when a
screen reader is on. This was seen with TalkBack on, and it is the one toast where Undo matters most.
**Fix:** `duration: toastDurationFor(context, const Duration(seconds: 5))`. The signed-in pills'
removal toast probably needs the same; it was not checked.

**N7. The merge toast covers the tab bar.** In `40` and `41` it sits over Home / Map / Saved /
Profile, hiding the Saved tab that its own View opens. It is shown through `toastContext` with no
`bottomOffset`, unlike the cafe page's toasts. **Fix:** pass the shell's bottom bar height as
`bottomOffset` in `showMergeToast`, or have `_showToastBar` lift toasts over `MainShell`'s
navigation bar by default.

**N8. The first-save line truncates at large text.** At font scale 2.0 (`36`) it reads "Saved on this
phone. Sign in an…": `maxLines: 2`, next to the Undo button. The part cut off is the only mention of
an account. **Fix:** a shorter line, "Saved on this phone · Undo · View" (View also teaches where saves
live, which the first save currently doesn't). Or allow 3 lines when
`MediaQuery.textScalerOf(context).scale(1) > 1.3`.

### Could be better

**N9. The inline terms fail contrast.** "Your account follows the Terms…" uses `AuthText.small`:
12sp `AuthColors.muted` `#868584` on `#FEFEFE` is **3.65:1**, under 4.5:1. That is the text a guest
now agrees to by tapping. This is a token issue, so report it rather than patch around it: darken
`AuthColors.muted` to about `#6B6A69` (4.9:1). Applies to the checkbox line too.

**N10. "See all" leads to a page that has only half the row.** Cafe Julio, recently viewed, is in
Your places (`19`) but not on Saved (`20`). **Fix:** label the link "See saved", or add a "Recently
viewed" section at the bottom of the guest Saved page.

**N11. Undo had no effect twice early in the run.** In the first minutes, Undo on a save toast
(`10-save-undo-no-effect`) and Undo on a removal toast (`10c-remove-undo-no-effect`) left the pill
unchanged. Three later tries worked (`12-undo-works`, and the save-toast Undo). It could not be
reproduced and the cause is unknown, so this is not a confirmed bug. The first failures happened
shortly after the ask sheet closed. A widget test that does save → ask dismissed → save → Undo would
settle it.

**N12. The keep-saves card is one button for TalkBack but not for touch.** It merges into a single
clickable node ("Keep your saves… / Sign in"), but a tap on the card body does nothing; only the pill
responds. **Fix:** make the whole card call `onSignIn`, keeping the pill as the visible action.

Source-only notes (not ranked): choosing "Continue with email" counts the ask as accepted
(`SignUpAskAnswer(accepted: choice != null)`) even if the person then backs out of `/login`, so they
get no −5 and an ask is still used up. Toggling a save off and on with Undo adds +5 each time, so the
score can be pumped. Neither changes what anyone sees today.

### Working well

- **The inline terms (`04`, `35`).** One tap on Google opens the terms in place, with a 200 ms
  ease-out, no red text, and a button that says what tapping it means. It meets the 1.2 requirement
  with no error state, and it holds up at 2.0× text.
- **The nudge and its fallback (`14`, `15`).** Ten seconds, sentence case, and the pill keeps a quiet
  "Suggested" tint once the toast is gone, so the offer stays where the eye already is. This is the
  District/Blackbird pattern the ux study recommended.
- **Your places now explains itself (`11`).** The subtitle, See all and correct badges make it read
  as "my cafes", and keying the cards fixes the badge bug in the shared widget, not just in this one
  rail.

---

## Scorecards

Scored once, from the emulator. 0 = a real problem, 1 = works with a gap, 2 = solid.

```text
Screen: Home, Your places rail               Looked at: emulator (+ font scale 2.0)
Foundations   Typography 2 · Grids 2 · Color 2 · Communication 2
Structure     Proportion 2 · Clarity 1 · Precision 2 · Order 2
Behavior      Affordance 2 · Motion n/a · Efficiency 2 · Restraint 2
Impact        Visuals 2 · Universal 2 · Accessibility 2 · Responsibility 2
Total 29/30 (15 scored)   was 22/30
Fix
- Clarity 1: See all opens a page without the recently viewed half (N10).
```

```text
Screen: Cafe page, top-right save + pills    Looked at: emulator (+ font scale 2.0, TalkBack tree)
Foundations   Typography 2 · Grids 2 · Color 2 · Communication 1
Structure     Proportion 2 · Clarity 1 · Precision 2 · Order 2
Behavior      Affordance 1 · Motion n/a · Efficiency 2 · Restraint 2
Impact        Visuals 2 · Universal 2 · Accessibility 1 · Responsibility 1
Total 25/30 (15 scored)   was 24/30
Fix
- Accessibility 1 / Affordance 1: 40dp target; no tap action in its semantics (N1, N2).
- Responsibility 1 / Clarity 1: Been shows as unsaved at the top and a tap replaces it (N3).
- Communication 1: for guests there are now two controls for one action; acceptable, but the top one should mirror the pills' state (N3).
```

```text
Screen: Save toasts (first-save line, Saved to · Undo · View, removal)   Looked at: emulator (+ 2.0, TalkBack)
Foundations   Typography 2 · Grids 2 · Color 2 · Communication 2
Structure     Proportion 2 · Clarity 1 · Precision 2 · Order 1
Behavior      Affordance 2 · Motion 2 · Efficiency 2 · Restraint 2
Impact        Visuals n/a · Universal 1 · Accessibility 0 · Responsibility 2
Total 25/30 (15 scored)   new surface
Fix
- Accessibility 0: close unreachable under TalkBack; the removal toast still times out (N1, N6).
- Clarity 1: no confirmation when the save opened the ask (N4).
- Universal 1: the first-save line truncates at 2.0× (N8).
- Order 1: the removal toast skips toastDurationFor; the first-save line lacks View (N6, N8).
```

```text
Screen: Directions → back nudge              Looked at: emulator (+ TalkBack)
Foundations   Typography 2 · Grids 2 · Color 2 · Communication 2
Structure     Proportion 2 · Clarity 2 · Precision 2 · Order 2
Behavior      Affordance 2 · Motion 2 · Efficiency 2 · Restraint 1
Impact        Visuals n/a · Universal 2 · Accessibility 1 · Responsibility 2
Total 28/30 (15 scored)   was 25/28
Fix
- Restraint 1: the score ask follows on Home within seconds (N5).
- Accessibility 1: shared toast close issue (N1).
```

```text
Screen: Guest Saved tab + keep-saves card    Looked at: emulator (+ font scale 2.0)
Foundations   Typography 2 · Grids 2 · Color 2 · Communication 2
Structure     Proportion 2 · Clarity 2 · Precision 2 · Order 2
Behavior      Affordance 1 · Motion n/a · Efficiency 2 · Restraint 2
Impact        Visuals 2 · Universal 2 · Accessibility 2 · Responsibility 2
Total 29/30 (15 scored)   was 23/30
Fix
- Affordance 1: the card is one button for TalkBack, but only the pill takes a touch (N12).
```

```text
Screen: Score-triggered ask sheet            Looked at: emulator (threshold 5; after save + on Home return)
Foundations   Typography 2 · Grids 2 · Color 1 · Communication 1
Structure     Proportion 2 · Clarity 1 · Precision 2 · Order 2
Behavior      Affordance 2 · Motion n/a · Efficiency 2 · Restraint 1
Impact        Visuals 2 · Universal 2 · Accessibility 2 · Responsibility 2
Total 26/30 (15 scored)   new surface
Fix
- Clarity 1 / Communication 1: interrupts a save without confirming it, and nothing confirms it afterwards (N4).
- Restraint 1: second ask in one trip after the nudge (N5).
- Color 1: terms text 3.65:1 (N9).
```

```text
Screen: Sign-in sheet, inline terms          Looked at: emulator (+ font scale 2.0)
Foundations   Typography 2 · Grids 2 · Color 1 · Communication 2
Structure     Proportion 2 · Clarity 2 · Precision 2 · Order 1
Behavior      Affordance 2 · Motion 2 · Efficiency 2 · Restraint 2
Impact        Visuals 2 · Universal 1 · Accessibility 2 · Responsibility 2
Total 29/32 (16 scored)   was 24/30
Fix
- Color 1: AuthColors.muted on white is 3.65:1 at 12sp (N9).
- Universal 1: at 2.0× "Agree and continue with Google" wraps to two lines inside the fixed 48dp button (`SheetSignInChoices.buttonHeight`), with almost no padding (`35`); let the button grow (minHeight instead of height).
- Order 1: the sheet still hard-codes colors (note carried over; the Figma frame defines them).
```

```text
Screen: Merge toast (debug preview)          Looked at: emulator (all + partial)
Foundations   Typography 2 · Grids 1 · Color 2 · Communication 2
Structure     Proportion 2 · Clarity 2 · Precision 2 · Order 2
Behavior      Affordance 2 · Motion 2 · Efficiency 2 · Restraint 2
Impact        Visuals n/a · Universal 2 · Accessibility 1 · Responsibility 2
Total 28/30 (15 scored)   new surface
Fix
- Grids 1: sits over the tab bar (N7).
- Accessibility 1: shared close issue under TalkBack (N1).
```

Totals: Home 29/30 · Cafe page 25/30 · Save toasts 25/30 · Nudge 28/30 · Saved tab 29/30 ·
Ask sheet 26/30 · Sign-in sheet 29/32 · Merge toast 28/30. These scores are for comparing before and
after a fix, not for comparing products.
