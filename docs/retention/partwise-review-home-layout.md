# Partwise review: Home layout reader + top banner

Job: **review** (mode ios, Flutter Android-first, Material controls; target code). Reports only; no `lib/` change.
Branch `retention/home-layout` at `7f07ef1`. Contract: `nook-supabase/docs/HOME_LAYOUT.md` (schema 1).

Looked at: Android emulator (AVD `iPhone_16_Look`, 1180x2556), debug build, signed out (guest with 3 on-phone Been saves), GPS Cebu.

- With `--dart-define=NOOK_HOME_LAYOUT_FIXTURE=true`: banner, reordered shelves, renamed hand-picked House picks ("Editor's picks"), two custom picked shelves, one rule shelf, one shelf scheduled off, Laptop-friendly hidden, unknown builtin ignored, untouched builtins appended.
- Banner dismiss and banner tap.
- Without the fixture (built-in Home).
- Font scale 2.0, and night mode on.

Screenshots are in `review-shots-home-layout/`.

Note for whoever re-runs this: a dismissed banner stays dismissed across `adb install -r` (key `flutter.homeBannerDismissed` = `debug-fixture-1|Cebu Coffee Week is on`). On the first launch the banner did not show because an earlier session had closed it. Clear that pref, or change the fixture title, to see it again. That is the contract working as written (dismissed per version + title).

---

## Screen: Home with a published layout (fixture)   Looked at: emulator

### Must fix (blocks the task or excludes people)

- None. Every contract rule I could exercise rendered correctly: order, rename, exact pick order, custom shelves, hidden shelf, schedule off, unknown id ignored, builtins appended (`fixture-appended-builtins.png`, `fixture-end-with-location.png`). The banner opens its link and closes on tap.

### Should fix

1. **The banner's button label truncates at large text.** At font scale 2.0 the CTA reads "See crowd fav…" and the body is cut to "Five days of cupping session…" (`font2-banner.png`). An ellipsized button label hides what it does. In `home_banner_card.dart`, `_Pill` has `maxLines: 1`: let the CTA wrap to 2 lines. When `MediaQuery.textScalerOf(context).scale(16) > 24`, stack the image above the copy (full width, 16:9) instead of the 112px side column, so the copy gets the full card width.
2. **Closing the banner cannot be undone, and it vanishes with no transition.** One tap on a 24px disc removes it for good for that version. The shelves then jump up about 300px (`banner-dismissed.png`). Show a SnackBar "Announcement hidden" with an **Undo** action. `HomeBannerDismissStore` would need `undismiss(key)`, or `dismiss` could run only after the SnackBar closes. Collapse the slot with `AnimatedSize` (200ms, easeOut) so the content slides up instead of jumping.
3. **A layout that leaves `nearby` out pushes Near you to the bottom of Home.** With the fixture's order (and `respect_purpose: false`), Near you comes after five other shelves (`fixture-appended-builtins.png`). The built-in Home deliberately puts it first when the phone has a position (`home_page.dart`, comment above `seen`, docs/ux/find-a-cafe.md finding 4). The app follows the contract here, so fix it in the admin. nook-admin should always write `nearby` into the document, seeded at its default position, and warn when an admin drags it below the fold. Also add to HOME_LAYOUT.md: "builtins appended at the end lose their position-first behavior".
4. **The rule shelf has no "See all" and ends in a dead end.** "Specialty, best rated" (rule `tag` + `sort`, up to 20 cafes) has no See all, while every built-in sorted shelf does. The rule already describes a search. Give `HomeCafeSection` for `source == rule` an `onSeeAll` that opens search with the tag and sort, the way the built-in shelves pass `sort:`. Picked shelves (at most 30, hand-ordered) can stay without one.

### Could be better

5. **Two near-duplicate shelves can show at once.** "Specialty, best rated" (custom) and "Specialty coffee near you" (built-in) both appear (`fixture-end-with-location.png`). This is the admin's content, not an app bug. The admin preview could flag a custom rule shelf whose tag matches a visible built-in shelf.
6. **The "shown" event is logged from `build()`** (`HomeBannerSlot.build`, `_shown.add`). It is guarded once per key per run, so it is correct today. A side effect in build does fire for frames that never reach the screen (offstage tab, a page under a route). Move it to a post-frame callback after the first visible build, or wrap the slot in the existing `HomeRailImpression`-style visibility check.
7. **The close disc is small next to its target.** The 44pt target is right. The 24px white disc with a 16px glyph at the photo's top-right corner reads as small beside the 16sp title (`fixture-banner.png`). A 28px disc with a 16px glyph matches the Been chip's visual weight on cafe photos.

### Working well

- **The fallback keeps the old Home.** Without the fixture, Home is the built-in Home (`builtin-top.png`), including Near you leading once a position is known. The no-layout path (`planHomeSlots` → `defaultHomeSlots`) leaves nothing to drift.
- **The banner is restrained.** One sage card on white, flat like every other Nook card, one filled pill, on the existing tokens (`primary20`, `primary100`). The whole card is the target, with a semantics label that joins title, body and CTA. It reads as content, not an ad.

### Scorecard

```text
Screen: Home with layout (fixture)      Looked at: rendered (emulator)
Foundations   Typography 2 · Grids 2 · Color 2 · Communication 1
Structure     Proportion 2 · Clarity 2 · Precision 2 · Order 2
Behavior      Affordance 1 · Motion 1 · Efficiency 1 · Restraint 2
Impact        Visuals 2 · Universal 1 · Accessibility 1 · Responsibility 1
Total 25/32 (16 scored)

Fix
- Communication 1: an admin order can bury Near you (finding 3).
- Affordance 1 / Efficiency 1: no See all on rule shelves (finding 4).
- Motion 1: banner close jumps the page (finding 2).
- Responsibility 1: permanent dismiss with no undo (finding 2).
- Universal 1 / Accessibility 1: banner CTA and body truncate at 2.0 text (finding 1).
```

## Screen: Home banner (component)   Looked at: emulator (tap, dismiss, 1.0 and 2.0 text)

```text
Screen: Home banner                     Looked at: rendered (emulator)
Foundations   Typography 2 · Grids 2 · Color 2 · Communication 2
Structure     Proportion 2 · Clarity 2 · Precision 1 · Order 2
Behavior      Affordance 2 · Motion 1 · Efficiency 2 · Restraint 2
Impact        Visuals 2 · Universal 1 · Accessibility 1 · Responsibility 1
Total 27/32 (16 scored)

Fix
- Universal 1 / Accessibility 1: CTA ellipsized at 2.0 (finding 1).
- Motion 1 / Responsibility 1: instant, permanent dismiss (finding 2).
- Precision 1: 24px close disc vs 16sp title (finding 7).
```

## Screen: Home without a layout (built-in)   Looked at: emulator

No new findings. The order and shelves match the built-in Home: Your places, Near you, House picks, Specialty coffee near you, Fresh on Nook, Laptop-friendly (`builtin-top.png`). `builtin-end.png` is from a launch before the GPS fix had reached the app, so Near you is missing there; with location it leads, as before.

```text
Screen: Home built-in                   Looked at: rendered (emulator)
Foundations   Typography 2 · Grids 2 · Color 2 · Communication 2
Structure     Proportion 2 · Clarity 2 · Precision 2 · Order 2
Behavior      Affordance 2 · Motion n/a · Efficiency 2 · Restraint 2
Impact        Visuals 2 · Universal 2 · Accessibility 2 · Responsibility 2
Total 30/30 (15 scored)
```

(This is a parity check, not a fresh review of the built-in Home.)

## Dark mode

The app has no dark theme. With system night mode on, Home renders light (`dark-mode-request.png`). That is the app as it stands, not something this branch changed, so it is n/a here.

## Not checked

- The banner without an image (copy padding 44 on the right for the close button): read in source only.
- A banner image that fails to load (coffee-icon fallback): source only.
- A broken `nook://` link, and `https://` links: source only (`home_link.dart`).
- The real RPC path (`get_home_layout`, `get_cafes_by_ids` batching): not deployed; unit tests only.
