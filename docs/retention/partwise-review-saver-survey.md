# Partwise review: saver survey sheet

Job: review (mode ios, Android-first with Material controls, target code). Reports only; no code changed.
Branch `retention/saver-survey`, commits c4b6936..548c0c9.

Screen: "What's kept you from going?" sheet over Home
Looked at: the Android emulator (`emulator-5562`, Pixel-class 1080x2400, debug build, guest,
`--dart-define=NOOK_FORCE_SAVER_SURVEY=true`) at font scale 1.0 and 2.0, with the keyboard open,
plus the accessibility tree from `uiautomator dump`. The app has no dark theme (single
`TAppTheme.lightTheme`), so there was no dark mode to check.

Screenshots: `review-shots-saver-survey/`

| File | What |
|---|---|
| `01-sheet-default.png` | Sheet as it opens, nothing picked, Send disabled |
| `02-two-picked.png` | Two picked: the other four dim and go inert |
| `03-other-keyboard.png` | "Something else" picked, field focused, keyboard open |
| `04-other-long.png` | 120 characters typed (truncated mid-word at "free da") |
| `05-thanks-toast.png` | After Send: "Thanks, that helps." |
| `06-fontscale-2.png`, `07-fontscale-2-scrolled.png` | Font scale 2.0, everything fits without scrolling |
| `08-fontscale-2-other-keyboard.png` | Font scale 2.0, keyboard open: the counter is cut by the hairline |

## Must fix (blocks the task or misleads people)

- **The "Tell us more" text is thrown away.** `saver_survey_sheet.dart:179` (`otherHint` at
  `saver_survey_reasons.dart:19`) asks for up to 120 characters, then `SaverSurveyAnswer.analytics()`
  sends only `other_text_present` and a length bucket. Nothing else reads `otherText`
  (grep finds no other use), so the text does not even stay on the phone; it is discarded when
  the sheet closes. A person who types a sentence is told "Thanks, that helps" for words nobody
  will read. That breaks "copy must match capability" (Responsibility). Fix, pick one:
  (a) drop the field: "Something else" becomes a plain checkbox row and the length bucket goes;
  (b) send the text to a place that is meant to hold free text (a `feedback` row in Supabase
  with RLS insert-only, not analytics) and say so in the hint: "Tell us more (optional, we read
  these)". (a) is the honest default until someone is going to read the answers.
- **The once-only flag is spent before the sheet is sure to open.** `SaverSurveyGate.evaluate()`
  calls `_store.markDone()` and `SessionPrompts.claim()` (`saver_survey_gate.dart:81-84`), and only
  afterwards does the host check again `!mounted || !_onHome` (`saver_survey_host.dart:100`). If the
  person taps a cafe while saves are being read (the account path is a network read), the survey
  is marked done and the run's prompt slot taken, but nothing is shown, ever. Fix: have `evaluate()`
  return the decision without side effects and add a `commit()` the host calls right before
  `showSaverSurveySheet` (after the second `_onHome` check). Keep "mark done as it opens" so a
  crash still counts.

## Should fix

- **No answer for "I'm still planning to go".** All six reasons are obstacles, and the title
  presumes one ("What's kept you from going?"). Someone who saved a cafe for a birthday next month
  has nothing true to pick except "Something else" or Skip, and the framing reads as "you should
  have gone by now". Add a first row `SaverSurveyReason('saving_for_later', 'Saving it for later')`
  and soften the line so it names no failure: keep the title, change the message to
  "No rush. If something's in the way, pick up to two." (`saver_survey_reasons.dart:15`).
  That also gives the data a needed control group: how many savers are simply not ready yet.
- **The message line is low contrast.** `StateStyles.muted` `#868584` on `#FEFEFE` is 3.65:1 for
  14sp body text (needs 4.5:1); the hint on the `tint` field is 3.17:1. It is a project token, so
  do not patch it here: report it against `lib/core/widgets/error/state_styles.dart` and propose a
  darker secondary (about `#6B6A69`, 5.3:1). Until then the message could use `ink` at 16sp, since
  "Pick up to two" is an instruction the person needs.
- **A full list makes you untick before you can change your mind.** With two picked the other four
  go inert (`_toggle`, `saver_survey_sheet.dart:71`; `enabled:` at :160). Swapping an answer takes
  two taps and the dimmed rows read as "unavailable" to TalkBack with no reason. Either let a third
  tap replace the oldest pick (keeps the limit, one tap), or keep the rule and give the dimmed rows
  a semantics hint "Up to two. Untick one to choose this."
- **TalkBack announces the barrier as "Scrim".** The first node in the dump is
  `content-desc="Scrim"`. Pass `barrierLabel: 'Close'` (or `MaterialLocalizations.of(context)
  .modalBarrierDismissLabel`) to `showModalBottomSheet` in `showSaverSurveySheet`. The same label
  likely shows on `ConfirmSheet`; fix there too if so.

## Could be better

- **At font scale 2.0 with the keyboard open, the "0/120" counter is cut by the hairline**
  (`08-fontscale-2-other-keyboard.png`). The scroll view's bottom padding is 8
  (`saver_survey_sheet.dart:130`); make it 16, or hide the counter until 100 characters.
- **When the content scrolls (keyboard open), text runs right up under the grabber** with no gap
  (`03`, `04`): the title is sliced 4px below the grabber. Put the grabber and the title outside
  the scroll view so only the reasons scroll, or add 12px between grabber and viewport.
- **Typing stops dead at 120 mid-word** (`04`: "...a free da"). Fine as a cap, but if the field
  stays (fix (b) above), show the counter in `danger` at the limit so it does not look like a bug.
- **A third private copy of the sheet pill button.** `_SheetButton` (`saver_survey_sheet.dart:305`)
  repeats the one in `confirm_sheet.dart`. Lift it to `lib/core/presentation/widgets/` when the
  next sheet needs it.
- **The forced flag did not open the sheet on the run that went through onboarding** (Home loaded
  behind the onboarding flow); it opened on the next cold start. Real rules exclude the first
  session anyway, so this only matters for QA; not investigated further.

## Working well

- **The trigger is respectful.** Once ever per phone, never on the first session, only after two
  open days, only with a Want to Try save at least 5 days old and no Been in 14 days, only on Home
  after the feed has settled 1.5s, and never on top of another prompt this run (`SessionPrompts`
  now covers the location row, guest sign-in sheets, the save toast and the directions nudge).
  Leaving is as easy as answering: Skip is the same size as Send, and swipe down, scrim tap and
  Back all close it and count as skipped.
- **The sheet itself is clean and native-feeling.** Project sheet anatomy (grabber, 24 radius,
  `0x66` barrier, hairline over the actions), rows are 48dp full-width targets, checkbox state is
  merged into each row so TalkBack reads "Haven't had time, checkbox, not checked", the title is a
  heading, Send is a disabled button until something is picked, and at font scale 2.0 every row
  wraps cleanly with Skip and Send still visible.

## Responsibility verdict

Timing, frequency and the exit are right. Two things are not: the free-text field promises a
listener that does not exist, and the reason list has no way to say "not yet, and that's fine",
which with the "haven't been yet" line tips the copy slightly toward guilt. Fix those and it is a
model ask.

## Scorecard

```text
Screen: Saver survey sheet          Looked at: rendered (Android emulator, 1.0 + 2.0 font scale)
Foundations   Typography 2 · Grids 2 · Color 1 · Communication 2
Structure     Proportion 2 · Clarity 2 · Precision 2 · Order 1
Behavior      Affordance 2 · Motion 2 · Efficiency 1 · Restraint 2
Impact        Visuals n/a · Universal 1 · Accessibility 1 · Responsibility 1
Total 24/30 (15 scored)

Fix
- Responsibility 1: saver_survey_sheet.dart:179 / analytics() — drop the free-text field or send
  the text somewhere it is read; move markDone/claim to just before the sheet opens; add
  "Saving it for later".
- Color 1: StateStyles.muted 3.65:1 on surface for the 14sp message — darken the token (~#6B6A69).
- Accessibility 1: barrierLabel "Scrim" -> "Close"; hint on dimmed rows; same muted contrast.
- Efficiency 1: third tap replaces the oldest pick instead of the list going inert.
- Universal 1: counter clipped at 2.0 with keyboard — bottom padding 8 -> 16.
- Order 1: _SheetButton duplicated from confirm_sheet.dart — share it.
```
