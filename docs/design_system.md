# Nook Mobile — Design System

The visual language of the Nook Flutter app: what to use, where it lives, and where the
code currently disagrees with itself.

This document is **normative** — the "Use this" columns are the rule, including where the
codebase does not yet follow them. Every deviation is listed explicitly in
[Known deviations](#known-deviations) rather than quietly normalised, so this doc can be
trusted as a target instead of a description of the mess.

Before this file, the entire design documentation for the app was one line in `CLAUDE.md`.
Nothing here is invented: every value is cited to the code it came from.

---

## 1. Principles

These are read off the code, not aspirational. They're what the app already does well and
what new work should stay consistent with.

1. **Flat, not floating.** Depth is drawn with a 1px hairline border, never a shadow.
   All 30 `elevation:` values in the app are `0`. There are exactly 2 `BoxShadow`s.
2. **The photo is the product.** Cafe cards are a photo with text beneath. Images fade in
   with no spinner or shimmer (`placeholder: SizedBox.shrink()`), so the grid never flickers.
3. **Green is for accent, not surface.** The brand green anchors identity through small,
   deliberate marks — the rating star, a chip border, the active tab. Backgrounds are white.
4. **Skeletons, not spinners.** Loading renders the real card shape via `Skeletonizer`, so
   layout never jumps.
5. **Adaptive by default.** Taps and buttons render Cupertino on iOS and Material elsewhere
   (`AdaptiveTap`, `Adaptive*Button`). Don't reach for a raw `InkWell`.
6. **Survive text scaling.** Horizontal lists are measured from a real prototype card
   (`PrototypeHeight`) instead of a hardcoded height. Never hardcode a height that contains text.

---

## 2. Color

**Source of truth:** `lib/utils/theme/custom_themes/color_scheme.dart`
**Access:** `context.colorScheme.<token>` (via `lib/utils/extensions.dart:5-12`)

### Brand ramp

| Token | Hex | Use |
|---|---|---|
| `primary` / `primary100` | `#344E41` | Brand green. Active nav, primary buttons, section emphasis. Contrast on white **9.6:1 (AAA)**. |
| `primary80` | `#3A5A40` | Toast background, pressed states. |
| `primary60` | `#588157` | Rating star, tag chip borders, banners. **Non-text only** — 3.9:1 fails AA for body text. |
| `primary40` | `#A3B18A` | Sage. Decorative fills. |
| `primary20` | `#DAD7CD` | Lightest sage. Backgrounds, dividers. |

### Neutrals

| Token | Hex | Use |
|---|---|---|
| `black` | `#0A0F0D` | Primary text. 19:1. |
| `gray` | `#868584` | Secondary text. ⚠️ **3.5:1 — fails WCAG AA.** See [Accessibility](#8-accessibility). |
| `white` | `#FEFEFE` | Card/surface fills. |
| `offWhite` | `#EEEEEE` | Subtle fills. |
| `border` | `#E0E0E0` | **The hairline.** Every border in the app. |

### Semantic

| Token | Hex |
|---|---|
| `success` | `#0F893E` |
| `warning` | `#E0AB38` |
| `error` | `#D11A17` |

### Rules

- **Never write `Color(0xFF...)` in a widget.** Every color above has a token. The codebase
  breaks this ~52 times for `#344E41` alone; don't add to it.
- **There is no dark theme.** Light only. `context.isDark` (`extensions.dart:11`) is dead code
  that can never return true. Don't branch on it.
- ⚠️ **`colorScheme.surface` is `#00000000` — fully transparent** (`color_scheme.dart:11`).
  This is a bug. It's why every `Scaffold` hardcodes `backgroundColor: Colors.white`. Until
  it's fixed, **do not use `colorScheme.surface`** — any M3 widget defaulting to it renders
  transparent.

---

## 3. Typography

**Source of truth:** `lib/utils/theme/custom_themes/text_theme.dart`
**Family:** Poppins (local, `pubspec.yaml:110-166`). Applied globally via `theme.dart:10`.
**Access:** `context.textTheme.<token>`

### The real scale

Four sizes, two weights. That's the whole system.

| Token | Size | Weight | Use |
|---|---|---|---|
| `titleLarge` / `titleLargeSemi` | 24 | 400 / 500 | Page + Featured section titles |
| `titleMedium` / `titleMediumSemi` | 18 | 400 / 500 | Section titles, Featured card name |
| `bodyLarge` / `bodyLargeMed` | 15 | 400 / 500 | Body, cafe card name |
| `bodySmall` / `bodySmallMed` | 12 | 400 / 500 | Captions, chips, rating pill |

### Rules

- **Use `context.textTheme.<token>.copyWith(color: ...)`.** This is the one convention the
  codebase already honours well — only 19 raw `TextStyle(` constructions exist in all of `lib/`.
- **Set `height` explicitly on tight text.** The theme sets no `height` or `letterSpacing`
  anywhere, so cards patch it inline (`height: 1.1` on names, `1.2` on Featured). Until the
  theme carries line-height, follow that convention rather than leaving it default.
- **Only weights 400 and 500 exist in practice.** All 9 Poppins weights are bundled; 15 of 18
  font files ship unused.

⚠️ **The `*Semi` names lie.** `titleLargeSemi`, `titleMediumSemi`, `bodyLargeSemi` are all
`FontWeight.w500` (Medium), not w600 (SemiBold). `bodyLargeSemi` is byte-identical to
`bodyLargeMed`. Read "Semi" as "Medium" until fixed — see [Known deviations](#known-deviations).

---

## 4. Spacing & layout

There is **no spacing constant class**. Everything below is de facto, measured across the repo.
Treat it as the scale anyway — it's consistent enough to be real.

### Scale — 4pt grid

`4 · 8 · 12 · 16 · 24 · 32` — about 75% of all spacing. **8 and 12 dominate.**
Off-grid values (6, 10, 14, 18, 22, 36) exist; don't add new ones except the two below.

### Named exceptions (both intentional, both off-grid)

| Value | Meaning |
|---|---|
| **22** | **The page gutter.** `EdgeInsets.symmetric(horizontal: 22)` — 32 uses, the most common padding in the app. Every home section aligns to it. |
| **36** | **Inter-section rhythm** on home. |

### Radius

| Value | Use |
|---|---|
| **12** | **The house radius** (~65% of all radii). Cards, images, chips, tags, rating pill. |
| 16 | Dialogs |
| 24 | Bottom sheets (top corners only) |
| Pill | Fully-round controls |

Use `SizedBox` for spacing. The `gap` package is a declared dependency but `Gap()` is never
used — don't reintroduce it without removing `SizedBox` usage first.

### Elevation

**Always `0`.** Depth = `Border.all(color: context.colorScheme.border)` at 1px. If you think
you need a shadow, you need a border.

### Breakpoints

**Height-based**, and scoped to home card images only — `lib/core/utils/responsive_card_sizes.dart`:

| Screen height | Featured image | Cafe card image |
|---|---|---|
| `< 640` (iPhone SE) | 160 | 130 |
| `640–779` (standard) | 185 | 150 |
| `780–899` (large) | 215 | 175 |
| `>= 900` (tablet) | 255 | 200 |

Nothing else in the app is responsive. No width breakpoints, no tablet layout.

---

## 5. Motion

**There are no motion tokens.** Every duration and curve is an inline literal.

| | De facto value |
|---|---|
| Standard UI transition | **300ms** |
| Toast auto-dismiss | 3s |
| Curves | No convention — 4 uses, 4 different curves |

**Route transitions are platform defaults** — every `GoRoute` uses `builder:`, never
`pageBuilder:`. Hero animations exist only on review photos (3 uses); **cafe card → cafe
details has no shared-element transition.**

When adding motion, use **300ms** and prefer `Curves.easeInOut` unless you have a reason.
Note `flutter_animate` is a declared dependency that is never imported — use it or drop it,
don't half-adopt it.

---

## 6. Components

### Foundational

| Widget | Path | Use for |
|---|---|---|
| `AdaptiveTap` | `core/widgets/adaptive_tap.dart` | **Every tappable surface.** Cupertino on iOS, `InkWell` elsewhere. |
| `AdaptiveElevatedButton` / `TextButton` / `OutlinedButton` / `FilledButton` | `core/presentation/widgets/adaptive_buttons.dart` | All buttons. Resolves Material `ButtonStyle` → Cupertino on iOS, incl. disabled states. The most polished component in the repo. |
| `CafeCardImage` | `core/presentation/widgets/cafe_card_image.dart` | **Every cafe image.** Cached, `BoxFit.cover`, coffee-icon error state, no placeholder spinner. |
| `PrototypeHeight` | `core/widgets/prototype_height.dart` | **Every horizontal `ListView` containing text.** Sizes from a real prototype card so it survives text scaling. |

### Cafe cards

| Widget | Shape | Where |
|---|---|---|
| `HomeCafeCard` | 280w vertical | Home: New / Trending / Top Rated |
| `FeaturedCard` | 410w vertical, bordered | Home: Featured |
| `ListCard` | 106h horizontal | Lists |

⚠️ **Six cafe card implementations exist.** Prefer these three; see
[Known deviations](#known-deviations).

### Chrome

| Widget | Path |
|---|---|
| `BottomNav` | `core/presentation/bottom_nav.dart` — 4 tabs, Phosphor icons, labels hidden |
| `HomeTopBar` | `features/home_page/presentation/widgets/home_top_bar.dart` |
| `SearchEntryButton` | `features/search/presentation/widgets/search_entry_button.dart` — 52h, pill |
| `AppBarCircleIconButton` | `core/presentation/widgets/app_bar_circle_icon_button.dart` — 40×40 white circle |
| `BookmarkIconButton` | `core/presentation/widgets/bookmark_icon_button.dart` — amber `#FFC107` when saved |

**There is no shared `AppBar` component.** 18 files re-declare
`backgroundColor: Colors.white, surfaceTintColor: Colors.white, elevation: 0` inline.

### States

A genuine, consistent family — use these rather than rolling your own:

| Widget | Path | Scale |
|---|---|---|
| `FullPageErrorWidget` | `core/widgets/error/full_page_error_widget.dart` | 64px icon; switches on `ErrorType` |
| `FullPageEmptyWidget` | `core/widgets/error/full_page_empty_widget.dart` | 64px icon |
| `SectionErrorWidget` | `core/widgets/error/section_error_widget.dart` | 36px icon |
| `SectionEmptyWidget` | `core/widgets/error/section_empty_widget.dart` | 36px icon |
| `LocationDeniedBanner` | `core/widgets/error/location_denied_banner.dart` | `primary60` dismissible banner |

### Loading

`Skeletonizer(enabled: true, effect: PulseEffect())` wrapping the real widget tree fed
prototype data. Cards take an `isSkeleton` bool; images use
`Skeleton.replace(replace: isSkeleton, ...)`. Used consistently across 11 files.

### Overlays

- **Bottom sheets:** `isScrollControlled: true`, `useSafeArea: true`, white,
  `BorderRadius.vertical(top: Radius.circular(24))`. Only 1 of 11 sets `showDragHandle`.
- **Dialogs:** white, radius 16, `EdgeInsets.all(24)`.
- **Toasts:** `showPrimaryToast` (pill, `primary80`) / `showSavedToListToast` — `core/utils/toast_helper.dart`.

---

## 7. Iconography & imagery

### Icons

**Three sets ship in parallel** — Material (60 files), Phosphor (17), Lucide (8).

**Rule going forward: Phosphor is the brand set.** It's the deliberate choice for the bottom
nav and the 23-entry tag map (`core/utils/tag_icon_resolver.dart`). Material is the fallback
for utility affordances. **Don't introduce Lucide into new work.**

⚠️ Four files mix two icon sets in one widget, and the same concept renders from different
sets across cards (star is Phosphor on home, Material in lists; map pin appears in three
different Lucide weights).

Icon sizes: **12** (in chips) · **14** (inline with text) · **16** (Featured) · **28** (bottom nav) · **32** (image error) · **36 / 64** (section / full-page states).

### Images

- Always `CafeCardImage` — never raw `Image.network`.
- Cache: `CustomCacheManager` — 7-day stale, 150-object cap (`core/cache/custom_cache_manager.dart`).
- Radius 12 (`ClipRRect`), or top-only for card-top images.
- **No `AspectRatio`** — height comes from `ResponsiveCardSizes`, width from the card.

⚠️ The fallback image is a **hardcoded Unsplash URL duplicated across 5+ files**. Production
empty states depend on a third-party CDN. Tokenize and self-host.

---

## 8. Accessibility

**Being direct: this is the weakest area of the app, and the gap is systematic rather than incidental.**

### The one strength — text scaling

Genuinely well handled, and worth protecting:
- `PrototypeHeight` measures a real card at runtime so horizontal lists work at any text scale.
- `CafeSummaryOverflowTagsRow` reads `MediaQuery.textScalerOf` into a `TextPainter` to compute
  chip overflow before layout.
- Scaling is never clamped — correct.

### The gaps

| Issue | Reality |
|---|---|
| **Contrast** | `gray` `#868584` on white ≈ **3.5:1 — fails WCAG AA.** It is the color of *every* cafe card's location, tag label, and distance — i.e. most secondary text in the app. Darkening it to ≈`#767574` reaches 4.5:1. **This is the single highest-value fix in this document.** |
| **Semantics** | One `Semantics` widget in all of `lib/`, and it only covers the iOS button branch. |
| **Labels** | Zero `semanticLabel`. `BookmarkIconButton`, `AppBarCircleIconButton`, and the banner dismiss X are unlabeled glyphs. |
| **Card structure** | No `MergeSemantics` — a screen reader hits 5 separate nodes per cafe card with no summary and no action label. |
| **Tap targets** | No 48×48 enforcement, and `MaterialTapTargetSize.shrinkWrap` **actively disables** Flutter's default expansion in 4 places. The circle buttons are 40×40; the banner dismiss X is ≈26×26. |

**Rules for new work:** give every icon-only control a `semanticLabel`; wrap cards in
`MergeSemantics`; don't use `shrinkWrap` on tap targets; don't use `gray` for text smaller
than 18pt until it's darkened.

---

## 9. The home page

**Files:** `features/home_page/presentation/pages/home_page.dart` + `widgets/`

```
SafeArea
└── RefreshIndicator (primary100 on white)
    └── SingleChildScrollView
        └── Column
            ├── HomeTopBar          logo 28h + SearchEntryButton
            ├── 12
            ├── LocationDeniedBanner?   (conditional)
            ├── 24
            ├── "Featured"          titleLargeSemi (24/500)   ← a level up
            ├── 12
            ├── H-ListView          FeaturedCard 410w · gutter 22 · sep 12
            ├── 36
            ├── "New"               titleMediumSemi (18/500)
            ├── H-ListView          HomeCafeCard 280w
            ├── 36
            ├── "Trending"          + H-ListView
            ├── 36
            ├── "Top Rated"         + H-ListView
            └── 36
```

Every section is a horizontal scroller: **gutter 22, separator 12, section gap 36.**

### `HomeCafeCard` anatomy (280w)

```
┌─ 280 ──────────────────────┐
│ ┌────────────────────────┐ │  radius 12 image, responsive height
│ │ ★ 4.8                  │ │  white pill @ top:10/left:10, radius 12
│ │                        │ │  PhosphorIconsFill.star 14 in primary60
│ │        [photo]         │ │  rating to 1dp, bodyExtraSmallMed, height 1.1
│ └────────────────────────┘ │
│                            │  6 vertical padding
│ Cafe Name                  │  bodyLargeSemi, 1 line, ellipsis
│                            │  2
│ 📍 Neighborhood            │  mapPin 14 + bodyMedium in gray
│                            │  6
│ ⟨ tag chip ⟩       1.2 km  │  chip: radius 12, primary60 1px border,
└────────────────────────────┘  icon 12, bodySmallMed gray · distance right
```

Whole card is one `AdaptiveTap` → `context.push('/cafe/${id}')`.
`FeaturedCard` differs: bordered container, top-only image radius, `titleMediumSemi` name,
star + rating + `(reviewCount)`, and multi-tag `CafeSummaryOverflowTagsRow`.

### Data

`HomeBloc` → `GetHomeFeedUseCase`. Fetches `top_rated`, `trending`, `newest` in parallel,
then `nearby` only if location resolves.

Two behaviours worth knowing before redesigning:
- **"Featured" is not a backend section.** It's derived client-side (`home_bloc.dart:56-67`)
  by concatenating newest + trending + topRated + nearby, filtering `.isFeatured`, and
  de-duping by id.
- **`nearby` is fetched but has no section** — it exists only to source Featured.
- `_safeFetch` swallows all exceptions and returns `[]`, so backend failure looks like an
  empty DB. `HomeLoadedState.allEmpty` exists to disambiguate "couldn't load" from "no cafes yet".

---

## Known deviations

The code does not currently match this document in these places. Listed so the doc stays
trustworthy — and roughly in priority order.

| # | Deviation | Impact |
|---|---|---|
| 1 | **`gray` fails WCAG AA (3.5:1)** and is the app's most-used secondary text color | Accessibility — highest-value fix here |
| 2 | **`colorScheme.surface` is transparent** (`#00000000`) | Bug. Forces `Colors.white` on every Scaffold; breaks any M3 default |
| 3 | **Colors ~65% untokenized** — 52 distinct hex literals across 53 files vs 18 tokens; `#344E41` inlined **52×** despite its token | Rebranding is a 53-file find-and-replace |
| 4 | **Three near-identical grays** — `#868584` (token), `#848586` (15×), `#848685` (19×) — transposition typos that propagated | Invisible drift |
| 5 | **`*Semi` styles are w500, not w600.** `bodyLargeSemi` ≡ `bodyLargeMed`; `bodyExtraSmall` is a no-op `copyWith`; 8 names → 4 real styles. `bodyLarge` ≡ `bodyMedium` | Names actively mislead; SemiBold ships unused |
| 6 | **No component themes** — no `appBarTheme`, `buttonTheme`, `chipTheme`, `cardTheme`, `bottomSheetTheme`, `dialogTheme`, `inputDecorationTheme` | Root cause of most duplication above |
| 7 | **No spacing/radius/motion constants** — no `AppSpacing`, `AppRadius`, `AppDurations` | The scale exists only as convention |
| 8 | **Six cafe card implementations.** `ListCard` (106h) and `RecommendedCard` (112h) are near-duplicates drifted 6px apart; both hardcode `'5.0 km'` as a placeholder string. `RecommendedCard` is **dead code** | |
| 9 | **Three icon sets**, mixed within single widgets | |
| 10 | **Mixed routing** — `go_router` plus imperative `Navigator.push` in 8+ places for the same destination | Two back-stack semantics for one screen |
| 11 | **`BottomNav` constructs a fresh `ThemeData`** to kill splash — discarding Poppins and the ColorScheme for that subtree | |
| 12 | **`useMaterial3` never declared** — M3 by SDK default, not by decision | |
| 13 | **Bottom sheet radius inconsistent** — 24 in most, 20 in `review_actions_sheet`. Pill radius expressed 3 ways (`999`, `100`, `BoxShape.circle`) | |
| 14 | **Dead UI deps:** `flutter_animate`, `gap`, `cupertino_icons`, `another_flushbar` (redundant with `toastification`) | |
| 15 | **No dark theme.** `context.isDark` is unreachable dead code | |

### Suggested order of attack

1. Darken `gray` to ≈`#767574` (one token, fixes the app's systematic contrast failure).
2. Fix `surface`; drop the compensating `Colors.white` from Scaffolds.
3. Fix the `*Semi` weights to w600 — the font is already bundled.
4. Add `AppSpacing` / `AppRadius` / `AppDurations` and codemod the literals.
5. Add component themes; delete the per-call-site re-declarations.
6. Codemod the 52 `#344E41` literals → `context.colorScheme.primary`, then the grays.
7. Delete `RecommendedCard`; merge `ListCard`'s twin.

---

## Quick reference

```dart
// Color — never Color(0xFF...)
context.colorScheme.primary      // #344E41  brand
context.colorScheme.primary60    // #588157  star, chip border — non-text only
context.colorScheme.black        // #0A0F0D  primary text
context.colorScheme.gray         // #868584  secondary text (fails AA — see above)
context.colorScheme.border       // #E0E0E0  the hairline

// Type — 4 sizes, 2 weights
context.textTheme.titleLargeSemi   // 24/500
context.textTheme.titleMediumSemi  // 18/500
context.textTheme.bodyLargeSemi    // 15/500  (actually Medium)
context.textTheme.bodyMedium       // 15/400
context.textTheme.bodySmallMed     // 12/500

// Spacing        4 · 8 · 12 · 16 · 24 · 32   (gutter 22 · section gap 36)
// Radius         12 (cards/images/chips) · 16 (dialogs) · 24 (sheets)
// Elevation      0 — always. Depth = 1px border in `border`.
// Motion         300ms

AdaptiveTap(borderRadius: BorderRadius.circular(12), onTap: ..., child: ...)
CafeCardImage(imageUrl: ..., height: ..., width: double.infinity)
PrototypeHeight(prototype: ..., listView: ...)   // any horizontal list with text
```
