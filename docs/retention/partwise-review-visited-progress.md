# Partwise review: "Been to X of Y" progress pill

Job: **review** (mode ios, Flutter Android-first, Material controls; target code). Reports only; no `lib/` change.
Branch `retention/visited-progress` at `12b19b4`.

Looked at: Android emulator (AVD `iPhone_16_Look`, 1180x2556), debug build, signed out (guest), GPS Cebu. The guest saves (`flutter.guest_saves_v1`) were rewritten between launches to get each state, and the original saves were put back afterwards:

| State | Saves | Home "Your places" | Saved tab |
|---|---|---|---|
| some | 1 Been, 2 Want to Try | `some-home.png` | `some-saved.png` |
| 0 of N | 0 Been, 3 Want to Try | `zero-home.png` | `zero-saved.png` |
| all | 3 Been | `all-home.png` (no pill, by design) | `all-saved.png` |
| nothing saved | none | `empty-home.png` | `empty-saved.png` |
| font scale 2.0 | "some" | `f2-home.png` | `f2-saved.png` |
| night mode | "some" | — | `dark-mode-request.png` |

Signed-in counts (`PlacesProgress.fromLists`) were read in source only; no account was used.

---

## Screen: Saved tab (guest), header pill   Looked at: emulator

### Must fix

- None. The counts are right in every state. The pill is hidden with nothing saved. Its semantics label ("Been to 1 of your 3 places") says what is counted.

### Should fix

1. **The ring reads as a loading spinner.** At 1 of 3 the indicator is a short dark arc on a pale grey track, 14px, drawn with `CircularProgressIndicator`. That is the exact shape of Material's indeterminate spinner, so the header looks like it is still loading (`some-saved.png`, `some-home.png`). At 0 of N it is just a grey circle that reads as an empty radio button (`zero-saved.png`). In `places_progress_pill.dart`, replace the ring with a filled pie: a `CustomPaint` sector in `ListsTokens.brand` on a `ListsTokens.tint`-darker disc. Or drop the graphic below one Been and show the text alone. Raise the track to at least 3:1 against the pill fill: `ListsTokens.checkbox` on `ListsTokens.tint` is near 1.5:1.
2. **At large text the pill wins over the title.** At font scale 2.0, "Your lists" breaks onto two lines while the pill keeps its single line at full width (`f2-saved.png`). On Home, "Your places" does the same (`f2-home.png`). The title is the landmark and the pill is supplementary. In `ListsTitleRow` (and `HomeSectionTitle` with `trailing`), when the scaled title will not fit on one line beside the pill, put the pill on its own line under the title: a `Wrap` with `spacing: 12, runSpacing: 8`, or a `LayoutBuilder` check. The 14px ring also stays fixed while the text doubles; size it from the text style (`fontSize * 1.15`).
3. **"Been to 0 of 3" counts a goal that was never set.** The first time a guest saves anything to Want to Try, the header says they have been nowhere (`zero-saved.png`). That is a scold in the place that should feel like a start. Below one Been, show nothing, or show "3 to try" with the bookmark glyph. The pill then appears when it first has good news. `PlacesProgress.label` returns the copy, so this is one branch there plus a test case.

### Could be better

4. **The pill repeats counts already on the screen.** The Saved tab shows "Want to try 2" and "Been 1" as section headers right under the pill. The pill adds the sum, nothing new. That is fine as a summary, but it is the least needed of the two placements. If finding 3 hides the pill at 0, consider keeping the Saved-tab pill only for "all" ("Been to all 3"), where it does say something new, and letting Home carry the in-progress count.
5. **Home and Saved disagree in the "all" state.** Saved says "Been to all 3"; Home's Your places shows no pill (`all-home.png`, `all-saved.png`). The source comment explains why (no Want to Try left, nothing to point at), and that is a fair call. The finished state is the one worth celebrating, though, and Home is where people see it. One option: show the check pill on Home once, on the first launch after the last Want to Try turns Been, then never again.

### Working well

- **It is quiet.** A 12sp label in the brand green on the lists tint, no border, no shadow, using the lists feature's own tokens (`ListsTokens`, `listsText`). It sits on the title's line and does not push content down. Tabular figures keep "1 of 3" → "2 of 3" from jittering.
- **The empty state is honest.** With nothing saved, the pill draws nothing (`PlacesProgress.label` returns null). The empty state underneath keeps its "Start your Want to Try list" message and "Find a cafe" action.

### Scorecard

```text
Screen: Saved tab (guest) header        Looked at: rendered (emulator)
Foundations   Typography 2 · Grids 2 · Color 1 · Communication 1
Structure     Proportion 2 · Clarity 1 · Precision 2 · Order 2
Behavior      Affordance 2 · Motion n/a · Efficiency 2 · Restraint 1
Impact        Visuals 1 · Universal 1 · Accessibility 1 · Responsibility 2
Total 23/30 (15 scored)

Fix
- Clarity 1 / Visuals 1: ring reads as a spinner (finding 1).
- Color 1: ring track under 3:1 on the pill (finding 1).
- Universal 1 / Accessibility 1: pill crowds the title at 2.0, fixed 14px ring (finding 2).
- Communication 1: "Been to 0 of 3" (finding 3).
- Restraint 1: duplicates the section counts below (finding 4).
```

## Screen: Home "Your places" rail pill   Looked at: emulator

Findings 1, 2 and 3 apply here too. Home-only:

- **Pill and "See all" never meet.** `HomeSectionTitle` drops `trailing` when `onSeeAll` is set, and Your places has no See all today. If Your places gets a See all later, the pill silently disappears. Note this in the `trailing` doc comment, or put the pill before the See all.
- **It looks right at 1.0.** The pill's right edge lines up with the search field and the "See all" of the next shelf (`some-home.png`).

```text
Screen: Home Your places rail           Looked at: rendered (emulator)
Foundations   Typography 2 · Grids 2 · Color 1 · Communication 1
Structure     Proportion 2 · Clarity 1 · Precision 2 · Order 2
Behavior      Affordance 2 · Motion n/a · Efficiency 2 · Restraint 2
Impact        Visuals 1 · Universal 1 · Accessibility 1 · Responsibility 2
Total 24/30 (15 scored)

Fix
- Clarity 1 / Visuals 1 / Color 1: ring (finding 1).
- Universal 1 / Accessibility 1: 2.0 text (finding 2).
- Communication 1: 0-of-N copy (finding 3).
```

## Dark mode

The app has no dark theme. With system night mode on, it renders light (`dark-mode-request.png`). This branch did not change that, so it is n/a here.

## Not checked

- Signed-in counts from the Been and Want to Try system lists, and the lists reload after a status change: source only.
- The "Your lists" pill on the account Saved tab (`list_page.dart`): source only. It is the same `ListsTitleRow`, so findings 1 to 3 apply.
- Large counts ("Been to 48 of 132"): source only. The pill is intrinsic width with `maxLines: 1` and no flex, so at 2.0 text a long label next to "Your lists" may overflow the row. This is worth one widget test at `textScaler: TextScaler.linear(2)`.
