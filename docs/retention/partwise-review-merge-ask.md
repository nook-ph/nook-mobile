# Partwise review: merge ask sheet

Job: **part**, then **review** (mode ios, Flutter Android-first; target code). Built in
`lib/features/guest_saves/presentation/widgets/merge_ask_sheet.dart`, shown by `GuestSavesSync`.
References: `docs/references/guest-saves/README.md` (Merge ask sheet).

Looked at: no emulator or device was available here. The sheet was rendered to PNG from a
throwaway widget test with Poppins and Lucide loaded (390x844 and 360x640, text scale 1.0 and
2.0), next to the notification pre-prompt for comparison. Shots in `review-shots-merge-ask/`.
Not seen on a device: the open and close motion, TalkBack, and the wait for another open sheet
(covered by a widget test instead).

## Findings and what was done

### Should fix

1. **Two names for one thing.** The first title said "Add 3 saves from this phone?" and the toast
   after "Add them" says "Moved 3 cafes to your account". **Fixed:** the title is now
   "Add 3 saved cafes?", which uses "cafes" like the toast.
2. **The title wrapped at 390.** "Add 3 saved cafes from this phone?" broke onto a second line with
   "phone?" left alone on it. **Fixed:** the title is shorter, and "this phone" now only appears
   in the reason line.
3. **"Add them" for one cafe.** **Fixed:** the button reads "Add it" when there is one save, so it
   matches "Add it to your account?".

### Could be better (left)

4. At 2.0x text and 360 wide the sheet is taller than the screen and scrolls, the same as the
   pre-prompt does. That is acceptable for a one-off ask.
5. After "Not now" nothing confirms that the cafes stayed on the phone. The reason line says where
   they are, and adding a toast here would put a second message on top of the merge toast.

### Working well

- Every value matches the notification pre-prompt and guest sign-in sheet: the same grabber, the
  56 tinted circle, the 20/14 type, `ProfilePillButton`, the 48-high text action and the 0.4 scrim.
  Nothing new was styled.
- Dismissal is honest. "Not now", a swipe, the scrim and Back all keep the saves on the phone and
  move nothing (`MergeAskAnswer.dismissed` is logged separately).

## Scorecard (after fixes)

```text
Screen: Merge ask sheet     Looked at: rendered (widget-test PNG), no device
Foundations   Typography 2 · Grids 2 · Color 2 · Communication 2
Structure     Proportion 2 · Clarity 2 · Precision 2 · Order 2
Behavior      Affordance 2 · Motion n/a · Efficiency 2 · Restraint 2
Impact        Visuals 2 · Universal 1 · Accessibility 2 · Responsibility 2
Total 29/30 (15 scored)

Fix
- Universal 1: at 2.0x text the sheet scrolls (left; the pre-prompt does the same).
```
