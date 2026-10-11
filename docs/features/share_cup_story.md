# Share a cup to Instagram Story

> Status: **spec, nothing built** (2026-10-11).
> **Target: nook-mobile 1.1.5, next release candidate.** `v1.1.5-rc1` is tagged without this
> feature (on `4389e37`, the merge of PR #130). This ships in **`v1.1.5-rc2`**, or in whichever
> `-rcN` is next once it's built. The version name stays `1.1.5`. The feature also needs a new
> cup page on nook-webapp, which must be **live on www.nookph.app before that RC is tagged**,
> and one additive read RPC in the shared Supabase project. See §9.
> Written for a developer new to the codebase: every file, function and table named here
> was read on 2026-10-11 (paths are relative to each repo's root unless absolute).
> Platform facts about Instagram are cited in §5.1; anything that could not be verified
> is marked **unverified**.

## TL;DR

- After posting a cup (and from your own cup's "…" menu and your own story), Nook renders
  a **1080 × 1920 story image** of the cup (photo, what you had, café, area, stars, Nook
  wordmark) and opens **Instagram's story composer** with it. No Instagram installed, or
  the person picks "More": the **system share sheet** gets the same PNG plus the link.
- Instagram does **not** let an app pre-fill a link sticker or an @mention. So the story
  image carries the café name and `www.nookph.app` in pixels, and Nook copies the cup's
  link (or the café's `@handle`) to the clipboard with a one-line hint ("Link copied:
  paste it in a Link sticker"). Honest, two taps for the person, no fake promises.
  iOS catch: Instagram's payload rides on the system clipboard, so on iOS the link has to
  travel on the same pasteboard item, or be copied after returning. This is a half-day
  spike to do first (§5.1).
- The link is a new public **cup page**, `https://www.nookph.app/cups/<cupId>`, with an OG
  image (photo + café + stars) and "Get Nook" store badges. It reads through a new
  additive RPC `get_cup_public(p_cup_id)`.
- Own cups only in 1.1.5. Someone else's photo is never put in your story by Nook.
- Needs a **Meta App ID** (a free developers.facebook.com app): the user creates it (§9.3).
- Estimate: **about 8 developer days**: mobile ~4.5 including the iOS clipboard spike, web
  ~1.5, DB ~0.5, app link route ~0.5, QA ~1. About 6.5 days without the optional app cup page
  and Save image.

---

## 1. Goal and success metrics

### Why

Nook grows by word of mouth in Metro Cebu. The one shareable artifact that exists today, the
crawl recap card, was shared **11 times by the one person who reached it**
(COFFEE_COMMUNITY.md §0: `crawl_recap_shared`, 1 person, 11 shares). Cups are the new
thing people make in 1.1.5; a cup is exactly the kind of post people already put on their
IG Story ("had this at X"). Every such story is a free, credible ad shown to that person's
friends, and it names a café, which gives cafés a reason to repost and to care about Nook
(the claim/outreach loop).

Keep expectations grounded (memory: DB stats aren't traction): production has **0 cups**
and ~5 people who post anything; Instagram reaches ~24% of Filipinos against Facebook's
~90% (COFFEE_COMMUNITY.md §1, rule 4). So this feature must also make the **system share
sheet** path good (Messenger, FB Stories, Viber all take the PNG), and success is measured
as a rate, not a volume.

### Events (PostHog, through `logAppEvent`)

All new names go in a new `abstract final class CupShareEvents` in
`lib/core/analytics/profile_events.dart`, next to `CupEvents`. Analytics only leave the
device in release builds (`kAnalyticsEnabled`, `lib/core/analytics/analytics_config.dart`);
verify locally with `flutter run --dart-define=NOOK_FORCE_ANALYTICS=true`.

| Event | When | Properties |
|---|---|---|
| `cup_share_opened` | the share sheet (§3.2) opens | `cafe_id`, `cup_id`, `entry` (`posted_toast`, `cup_menu`, `story_viewer`, `profile`), `has_photo`, `photo_count`, `layout` (`photo` / `note`), `ig_available` (bool) |
| `cup_shared` | a target was handed the image/link | `cafe_id`, `cup_id`, `entry`, `target` (`ig_story`, `fb_story` if built, `system`, `copy_link`, `save_image`), `result` (`opened` for IG, else share_plus `ShareResultStatus.name`: `success` / `dismissed` / `unavailable`), `layout`, `photo_index`, `has_handle` |
| `cup_share_failed` | rendering or launching failed | `stage` (`render`, `write_file`, `launch_ig`), `target`, `error` (exception type only, no message text) |
| `cafe_handle_copied` | the café's @handle was copied (§7) | `cafe_id`, `entry` (`share_sheet`, `after_ig`) |

Notes:
- `ig_story` can only report that Instagram **opened** with the image; IG gives no callback
  for "posted" (§5.1). Don't call it a post count.
- On iOS, share_plus returns `success` with the activity type; on Android `success` means
  "a target was picked", not "sent" (share_plus docs). Same caveat as `profile_shared`.
- Funnel to build in PostHog: `cup_posted` → `cup_share_opened` → `cup_shared`.

### Web attribution: `?ref=`

Every link the share flow emits is
`https://www.nookph.app/cups/<cupId>?ref=cup_story` (IG path) or `?ref=cup_share`
(system sheet / copy link). The web has **no analytics today** (no PostHog, no Vercel
Analytics in `nook-webapp/package.json`), so §6.5 adds a tiny landing beacon
(`cup_page_viewed` with `ref`) and store-badge clicks (`cup_page_store_tapped`), and tags
the store links (Play `referrer=utm_source=nook_web&utm_campaign=cup_story`; App Store
`ct=cup_story` campaign link, needs the provider token, §9.3).

### Targets to watch (first 30 days after the RC reaches production)

These are watch thresholds for a tiny base, not promises:

| Metric | Watch for | Why |
|---|---|---|
| share rate = people with `cup_shared` / people with `cup_posted` (created) | ≥ 20% | below ~10% means the entry points are missed or the card isn't worth posting |
| `target = ig_story` share of `cup_shared` | informational | tells whether the IG-first design fits a FB-heavy audience; if `system` dominates, prioritise FB Stories (§2) |
| `cup_share_failed` / `cup_share_opened` | < 2% | render or launch bugs on some device |
| `cup_page_viewed` with `ref=cup_story` per IG share | > 0.3 | people actually type/tap the link from the sticker |
| cafés reposting | ≥ 1 | manual: count IG reposts / tags seen by the Nook IG account and owners' messages |
| store taps from cup pages | any | the growth loop closing |

---

## 2. Scope

### In 1.1.5 (this spec)

1. **Story card renderer** (Flutter widget → PNG), photo layout and note layout (§4).
2. **Share sheet** for a cup: preview, "Instagram Story", "More…" (system sheet),
   "Copy link", "Save image"; café @handle copy (§3, §7).
3. **Instagram Stories** direct share on iOS and Android with the Meta App ID (§5).
4. **Fallback**: system share sheet with the PNG and the link text (§5.4).
5. **Entry points**: posted toast, own cup "…" menu (cafe page, cups page, profile sheet),
   own story in the story viewer (§3.1).
6. **Web cup page** `/cups/[id]` with OG/Twitter image, store badges, moderation-aware
   404/noindex, and app-link handling (§6).
7. **`get_cup_public`** RPC, additive and legacy-safe (§6.3).
8. **Tracking**: the events above, `?ref=` links, web landing beacon (§1).

### Later (not 1.1.5)

| Item | Why later |
|---|---|
| **Facebook Stories** target (`facebook-stories://share`, `com.facebook.stories.ADD_TO_STORY`) | Same Meta App ID, roughly half a day per platform once IG works (§5.5). Ship IG first, add FB in 1.1.6 if `system` shares dominate. |
| **Owner "Featured on Nook" kit** in nook-business: a downloadable story/post frame for cafés ("Find us on Nook"), a page listing public cups at their café with a "Repost" button that builds the same card | Needs owner consent rules and the cup card renderer on the web (Satori) at story size. Builds on §6's OG route. |
| **Monthly recap** card ("{n} cafés. {m} cups. One very caffeinated {month}." — COFFEE_VOICE.md row 30, *proposal*) | Needs a recap read RPC and enough cups per person to be worth it. |
| Sharing **someone else's** cup as a link (no image) | See §3.4 for the privacy reasoning; revisit with author consent (a "let others share my cups" setting). |
| Short links (`nookph.app/s/<code>`) | Needs a code column and resolver; the full UUID link works and is only ever pasted, never typed (§4.4). |
| Video / Live Photo stories, multi-photo carousels | Out of scope; one image per share. |

---

## 3. User flows

### 3.1 Entry points

| # | Where | Who sees it | Change |
|---|---|---|---|
| A | **Posted toast** after the composer closes with `CupComposerAction.posted` (`openCupComposer`, `lib/features/cups/presentation/widgets/cup_composer_sheet.dart`) | the poster | toast gets a **Share** action next to **Rank it** |
| B | **Own cup "…" menu** (`showCupOptions` → `ReviewOptionsSheet.forOwnCup`, `lib/features/cups/presentation/cup_actions.dart` and `lib/features/cafe_details/presentation/widgets/review_actions_sheet.dart`). Reached from the cafe page (`cafe_details_page.dart:334`), the cups page (`cafe_cups_page.dart:483`) and the profile's per-café sheet (`profile_cafe_cups_sheet.dart:62`) | the author | new first row **Share cup** above Edit / Delete |
| C | **Story viewer** (`lib/features/gallery/presentation/stories/cafe_story_viewer_page.dart`), on **your own** story | the author | a share icon in `_Header` (left of "…"/close) when `credit.isSelf` |
| — | Someone else's cup / story | — | no share in 1.1.5 (§3.4) |

Updates (`CupComposerAction.updated`) and deletes never offer Share in the toast; the "…"
menu covers edited cups.

### 3.2 Flow A: right after posting

Today the posted toast is `showPrimaryToastWithAction(message, actionLabel: 'Rank it · ~20 sec')`
when `offersRankIt(...)` is true, else a plain `showPrimaryToast`. `_showToastBar`
(`lib/core/utils/toast_helper.dart`) supports **one** action. Change:

- Add an optional second action to `_showToastBar` / `showPrimaryToastWithAction`
  (`secondaryActionLabel`, `onSecondaryAction`), both sage (`_toastAction`).
- When the posted cup can be shared (§3.5) **and** Rank it is offered:
  message `Cup posted`, actions **Share** · **Rank it** (drop "· ~20 sec" and the
  "· Marked as Been" suffix so it fits 320-dp-wide screens; the Been state is still visible on
  the page). Duration 6 s.
- When only Share applies: message as today (`Cup posted · Marked as Been` / `Cup posted`),
  action **Share**. Duration 5 s.
- When only Rank it applies (cup can't be shared, e.g. legacy backend returned no cup):
  unchanged.

```
 ┌──────────────────────────────────────────────┐
 │ Cup posted              Share     Rank it    │   dark toast bar, sage actions
 └──────────────────────────────────────────────┘
```

Tapping **Share** dismisses the toast and opens the **cup share sheet**
(`ReviewSheetShell.show`, same shell as every cup sheet):

```
 ┌────────────────────────────────────────┐
 │  ▁▁▁                                    │ grabber
 │  Share your cup                    ✕    │
 │                                          │
 │        ┌──────────────┐                  │
 │        │  [photo]     │  ← 9:16 preview  │
 │        │              │    (208 × 370)   │
 │        │ Spanish latte│                  │
 │        │ Café Name    │                  │
 │        │ ★★★★☆  nook  │                  │
 │        └──────────────┘                  │
 │        ● ○ ○   (photo 1 of 3, swipe)     │ only with 2+ photos
 │                                          │
 │  ┌────────────────────────────────────┐  │
 │  │  [IG glyph]  Instagram Story       │  │ primary, brand green, hidden if IG missing
 │  └────────────────────────────────────┘  │
 │  ┌──────────┐ ┌──────────┐ ┌──────────┐  │
 │  │ More…    │ │ Copy link│ │ Save     │  │ outlined pills
 │  └──────────┘ └──────────┘ └──────────┘  │
 │                                          │
 │  Tag the café: @voltespecialtycafe  Copy │ only when the café has an IG handle (§7)
 │  Paste it in a Mention sticker.          │ muted 12 pt
 └────────────────────────────────────────┘
```

**Instagram Story** → render the PNG(s) (§4.6) → put the cup link where the person can paste
it → launch Instagram (§5.2/§5.3).
- **Android:** `Clipboard.setData` before launching.
- **iOS:** the link rides on the Instagram pasteboard item, or, if the spike in §5.1 shows
  that fails, gets copied when the person comes back.

The hint is printed in the sheet under the button, because a toast would be covered by
Instagram straight away. When the café has a handle, copying the handle instead is offered by the
row at the bottom; the clipboard holds one thing, so the person picks.

Sub-label under the IG button (muted 12 pt): `Opens Instagram with your cup. We copy the link
for a Link sticker.`

**More…** → system share sheet with the PNG and text (§5.4).
**Copy link** → clipboard + toast `Link copied`.
**Save image** → out of scope for 1.1.5 unless trivial: there is no gallery-save package in
pubspec (`image_gallery_saver`/`gal` absent) and iOS would need
`NSPhotoLibraryAddUsageDescription`, which exists (for crawl images). If the developer
adds `gal` (maintained, iOS+Android), keep it; otherwise drop the button — the system sheet
has "Save Image" on iOS and most Android sheets have a save/download target.

### 3.3 Flows B and C

- **B (own cup menu):** `ReviewOptionsSheet.forOwnCup` gains a first option
  `ReviewOption.share` — label `Share cup`, detail `To your Instagram Story or anywhere`.
  `showCupOptions` handles it by opening the same share sheet with `entry: cup_menu`
  (or `profile` when called from `profile_cafe_cups_sheet.dart`; pass `entry` in).
  Add `share` to `enum ReviewOption` (`review_actions_sheet.dart:17`) and make sure every
  `switch` on it still compiles.
- **C (story viewer):** `CafeStoryViewerPage` shows one person's photos; each
  `CommunityPhoto` carries `visit` (the cup id) and `credit.isSelf`. Add an optional
  `onShare: Future<void> Function(CommunityPhoto photo)?` next to `onReport`, show a share
  icon (`LucideIcons.send` or `share`) in `_Header` only when `credit.isSelf && onShare != null`,
  and pause playback while the sheet is open (wrap in `_paused(...)` like `_report`). The
  caller (cafe page / community photos section) resolves `photo.visit` to the `CupCard`
  (from `CafeCupsCubit.state` `myCups`) and opens the sheet with `entry: story_viewer`,
  preselecting that photo.

### 3.4 Whose cups can be shared (decision: own only)

- A cup's photos and words belong to its author. Putting **someone else's** photo on your
  Instagram Story republishes their content outside Nook, to an audience they didn't
  choose, without their knowledge — and Nook's moderation (hide/remove, blocks) can't follow
  it there. The App Store UGC review checklist the team keeps
  (nook-mobile `docs/appstore_ugc_qa_checklist.md`) is built around authors controlling
  their content; an "export anyone's photo" button works against that.
- The public cup page (§6) is fine for others to **view** (the cup is already public on
  the café's Cups list), but 1.1.5 gives others no share button; to point friends at a café
  they already have **Share cafe** (`ShareService.shareCafe`).
- Later: an author setting "Let others share my cups" would unlock a link-only share.

### 3.5 Which cups can be shared

- `card.isMine` and `card.cupId != null` (a real or virtual cup; `get_cup_public` resolves
  virtual ids, §6.3). A legacy photo group without a cup id (`isLegacyPhotos`) is not
  shareable.
- Moderation: only `moderation_status = 'visible'` cups. `my_cups[]` includes your own
  hidden ones (CUPS_APPLY "my_cups: … incl. hidden") and carries `moderation_status`
  ("own only") — the client `CupCard` does not keep it today; add a
  `String? moderationStatus` to `CupCard` and map it in `CupsJson`, then hide Share when it
  isn't `visible`. The web page 404s anyway (§6.2), so this is about not producing a dead link.
- **Photo cup** → photo layout. **No photo but a note** → note layout. **Neither** (only
  stars and text items) → note layout using the item names; if there are no items either
  (stars only), still allowed: the card reads "{stars} at {café}".
- Photos from the posted result: `CupPostResult.cup` can be null (legacy backend). Then no
  Share in the toast; the menu path still works once the list reloads.

### 3.6 After Instagram

The person returns to Nook on the screen they left (the sheet closes when IG opens; the
caller stays). No "Did you post it?" prompt: we can't know, and asking adds friction.

### 3.7 Instagram not installed

`ig_available` is computed once when the sheet opens (§5.2/§5.3 `canOpen` checks). When
false, the primary button becomes **Share image** (system sheet, §5.4) and "More…" is
hidden; the hint lines about stickers are hidden too.

---

## 4. Story card design

### 4.1 Canvas and safe zones

- **1080 × 1920 px** PNG (9:16), drawn as a **360 × 640 logical** widget exported at
  `pixelRatio: 3` — the same approach and size as the crawl recap
  (`CrawlShareOverlay.size = Size(360, 640)`, `_exportPixelRatio = 3.0` in
  `lib/features/crawls/presentation/pages/crawl_share_page.dart`).
- Instagram overlays its own UI: the progress bar, avatar row and close button at the top,
  and the reply bar / "Send message" at the bottom. Keep text and the wordmark out of the
  **top 250 px and bottom 340 px** (at 1080 × 1920; 84 / 113 logical). Meta publishes no
  safe-zone numbers for shared stories. These follow the common creator guidance (about 14%
  top and 18–20% bottom), rounded up. Confirm on a device in QA.
- 64 px side margins (≈ 21 logical).

### 4.2 Photo layout (cup has ≥ 1 public photo)

```
  1080 ─────────────────────────────────┐
  │ (top safe 250 px: photo only)       │
  │                                     │
  │   ┌─────────────────────────────┐   │
  │   │                             │   │  the photo, cover-cropped into a
  │   │          PHOTO              │   │  rounded 4:5 frame (936 × 1170 px,
  │   │        (4:5, r=40px)        │   │  radius 40), on a blurred, darkened
  │   │                             │   │  copy of the same photo filling the
  │   │                             │   │  canvas (no letterbox bars)
  │   └─────────────────────────────┘   │
  │   ☕ Spanish latte · Coffee          │  item: Poppins 600, 22 lg / 66 px, white
  │   Volte Specialty Café              │  café: Poppins 600, 28 lg / 84 px, white, ≤ 2 lines
  │   Lahug, Cebu City                  │  area: Poppins 400, 15 lg, white 80%
  │   ★★★★☆                            │  stars only when rated, sage #A3B18A
  │                                     │
  │   [nook logo]   www.nookph.app      │  wordmark (assets/logos/logoT.png, white) + URL
  │ (bottom safe 340 px: blurred photo) │
  └─────────────────────────────────────┘ 1920
```

- **Which photo:** the one the person is looking at in the preview pager (default: the
  first photo item in cup order, `CupCard.photos.first`, which is item position order from
  `cup_items_json`). From the story viewer, the photo that was on screen. Log `photo_index`.
- **No note on the photo layout.** Notes run to 1,000 characters (`maxCupNote`), are often
  personal, and fight the photo. The note layout uses it instead.
- **Item line:** the first named item (`CupItem.label`) with its kind label
  (`CupItemKind.label`: Coffee / Drink / Food / Space); "+2 more" when the cup has more named
  items. Legacy photos have `kind == null` → show just the name, or skip the line when there
  is no name either. Kind icon: reuse the app's kind icons if exported, else none.
- **Café line:** `PickedCafe.name`; **area:** `PickedCafe.area` ("Lahug, Cebu City").
- **Stars:** `CupCard.rating` (1–5) as 5 star glyphs; omitted when null (stars are optional).
- The darkening scrim under the text: linear gradient from transparent to `#0A0F0D` at
  70% over the lower 45% of the canvas, so white text passes contrast on any photo (bright
  latte art on white tables is the common worst case).

### 4.3 Note layout (no photo)

```
  ┌─────────────────────────────────────┐
  │ (top safe)                          │  ground: brand #344E41
  │                                     │
  │   "                                 │  big sage quote mark
  │   The Spanish latte is the move.    │  note: Poppins 500, 24 lg, #FEFEFE,
  │   Quiet upstairs before 10."        │  ≤ 7 lines, clipped at a word with "…"
  │                                     │  (≈ 180 characters)
  │   ─────                             │
  │   Spanish latte · Banana bread      │  text items, Poppins 400, 15 lg, sage
  │   Volte Specialty Café              │
  │   Lahug, Cebu City   ★★★★☆         │
  │                                     │
  │   [nook logo]   www.nookph.app      │
  │ (bottom safe)                       │
  └─────────────────────────────────────┘
```

Colours from the app theme (`ListsTokens`, `lib/features/lists/presentation/widgets/list_tokens.dart`):
brand `0xFF344E41`, brand hover `0xFF2F4833`, accent `0xFF588157`, sage `0xFFDAD7CD`,
toast/action sage `0xFFA3B18A`, ink `0xFF0A0F0D`, surface `0xFFFEFEFE`. Font: **Poppins**
(bundled in `assets/fonts/`, family `Poppins`). Instagram background colours for the
sticker path (§4.6): top `#344E41`, bottom `#2F4833`.

### 4.4 Text rules

- **Copy voice** (COFFEE_VOICE.md): labels say what they do; one bit of warmth at most;
  never claim what isn't shipped. The card has no tagline beyond the wordmark and URL. If
  a line is wanted, use `Found on Nook` — not "best", not "top".
- **Long names:** café ≤ 2 lines then ellipsis (`maxLines: 2`, `TextOverflow.ellipsis`);
  item ≤ 1 line; area ≤ 1 line. Use `FittedBox(fit: BoxFit.scaleDown)` only for the café
  line, with a 20-logical floor, then ellipsis. Test with
  "The Coffee Bean & Tea Leaf - SM Seaside City Cebu (Upper Ground Floor)".
- **System text scale:** the card must **ignore** the device text scale — it's an image of a
  fixed size. Wrap the card in `MediaQuery(data: …copyWith(textScaler: TextScaler.noScaling))`.
  The sheet around it still honours large text.
- **Emoji / non-Latin** in notes and names: Poppins has no emoji; Flutter falls back to the
  system emoji font when rendering offscreen too. Check one note with emoji on both
  platforms (§8).
- **The printed URL** is `www.nookph.app` (not the apex: `https://nookph.app` currently
  answers `200` with an empty body — checked 2026-10-11 — so a typed apex link would land
  nowhere; see Open questions). The full cup link is never printed: a UUID can't be typed
  from a story, and it goes in the Link sticker via the clipboard instead.

### 4.5 Privacy on the card

- Own cups only (§3.4). No username/avatar on the card: it's on the person's own story, so
  their IG identity is already there, and a Nook handle would be noise. (Revisit if a
  "Find me on Nook" variant is wanted.)
- Never include hidden photos (`CupItem.isHidden`) or photos whose moderation isn't
  visible. Only items where `hasPhoto && !isHidden` are candidates.
- No location beyond the café's public area; no visit date (it reveals routine).

### 4.6 Render approach and what we send to Instagram

**Recommendation:** an offscreen Flutter widget captured with `RepaintBoundary.toImage`,
exactly like the crawl share page. Reasons: reuses Poppins, the theme, `Text` layout with
ellipsis and fallback fonts; no manual `dart:ui` text measuring; the crawl page proves it
works on both platforms in production builds.

Photos must be **decoded before capture**: `toImage` captures whatever is painted, so a
`CachedNetworkImage` still loading paints nothing. Precache with
`precacheImage(CachedNetworkImageProvider(url), context)` (or resolve the image stream and
await the first frame) before calling `toImage`, with a 10 s timeout → error state
"Couldn't load your photo. Check your connection." and a Retry.

Two images are produced:

1. `story_full.png` — the whole card (background + text + wordmark), 1080 × 1920. Used for
   the **system share sheet** and as the IG background on the simple path.
2. Optional **sticker path** (decide in implementation, default **off** for 1.1.5):
   background = blurred/scrim photo only; sticker = the photo frame + text block as a
   transparent PNG (≈ 960 px wide) so the person can move/resize it in IG. More native-feeling,
   but two captures and more QA. Ship the simple path first; the platform code below
   supports both because it's the same call with one more extra.

Code sketch (Dart; new file `lib/features/cups/presentation/share/cup_story_card.dart` for
the widget, `cup_story_renderer.dart` for the capture):

```dart
/// Renders [card] offscreen at 1080 × 1920 and writes a PNG to the temp dir.
class CupStoryRenderer {
  static const logicalSize = Size(360, 640);
  static const pixelRatio = 3.0; // 360 × 3 = 1080

  /// The widget must already be laid out inside a RepaintBoundary with
  /// [boundaryKey] (the sheet keeps it on screen, scaled down by a FittedBox,
  /// exactly like CrawlSharePage). Photos must be precached first.
  Future<File> renderToFile(GlobalKey boundaryKey, {required String cupId}) async {
    final boundary =
        boundaryKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    // A frame may still be pending right after a state change.
    if (boundary.debugNeedsPaint) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    final image = await boundary.toImage(pixelRatio: pixelRatio);
    try {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      if (bytes == null) throw StateError('PNG encoding returned no data');
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/nook-cup-$cupId-${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(bytes.buffer.asUint8List(), flush: true);
      return file;
    } finally {
      image.dispose();
    }
  }
}
```

Keep the preview widget **on screen** (inside the sheet, scaled with
`FittedBox` like `CrawlSharePage`) and capture that boundary; a truly offscreen
`Overlay`/`Offstage` boundary sometimes isn't painted (`debugNeedsPaint`) and yields a blank
image. The FittedBox doesn't affect the output size: `toImage` uses the boundary's own
360 × 640 layout size × `pixelRatio`.

File size: a 1080 × 1920 PNG of a photo is typically 2–4 MB. Fine for both platforms
(§5.1); if a device struggles, encode JPEG for the **background** only via
`flutter_image_compress` (already a dependency) at quality 90 — PNG stays for stickers
(transparency).

Temp files: delete files older than 1 hour in `getTemporaryDirectory()` matching
`nook-cup-*.png` when the sheet opens (IG reads the file asynchronously on Android, so
never delete right after launching).

---

## 5. Platform implementation

### 5.1 What Instagram allows (verified)

Checked on 2026-10-11 against Meta's official docs [1][2][3] and the 2022 announcement [4].
Each point says how it was verified.

| Question | Answer | Source |
|---|---|---|
| Is a Meta (Facebook) App ID needed? | **Yes.** It has been required since January 2023 (the deadline moved from 2022-11-30 to 2023-01-30). Without one, Instagram shows "The app you shared from doesn't currently support sharing to Stories." Any registered app with Basic settings works; no SDK is needed. | [1][4] |
| App Review? | Not mentioned anywhere in the Stories docs, and no permission is requested, so we don't expect one (our inference). | [1][4] |
| Must the bundle id / package be registered, or the app be Live? | **Unverified.** No source says either way. Register both platforms and switch the app to Live anyway (§9.3): it's cheap and removes the doubt. | [1][5] |
| iOS launch | `instagram-stories://share?source_application=<APP_ID>`. Check `canOpenURL` first, then fill `UIPasteboard`, then call `open`. | [1] |
| iOS pasteboard keys | `com.instagram.sharedSticker.backgroundImage` (PNG/JPG data), `.stickerImage`, `.backgroundVideo`, `.backgroundTopColor`, `.backgroundBottomColor` (hex strings). The item must include a background, a sticker or both. | [1] |
| iOS pasteboard expiry | Meta's sample sets `UIPasteboard.OptionsKey.expirationDate` to now + 5 minutes. | [1] |
| iOS `Info.plist` | Add `instagram-stories` under `LSApplicationQueriesSchemes` (and `facebook-stories` if FB is added). | [1][3] |
| Android launch | `Intent("com.instagram.share.ADD_TO_STORY")` with the extra `source_application` = App ID. For the background: `setDataAndType(uri, "image/*")` plus `FLAG_GRANT_READ_URI_PERMISSION`. For a sticker: the extra `interactive_asset_uri` plus `grantUriPermission("com.instagram.android", uri, READ)`. Colours go in `top_background_color` / `bottom_background_color`. Launch only if `resolveActivity(intent, 0) != null`. | [1] |
| Android URIs | Must be `content://` URIs to local files, so the app needs a `FileProvider`. | [1] |
| Android 11+ package visibility | Meta's page doesn't mention it. Without a `<queries>` entry for `com.instagram.android`, `resolveActivity` returns null on API 30+. | [6] |
| Asset sizes | Background at least 720 × 1280, ratio 9:16 or 9:18 (we use 1080 × 1920). Recommended sticker size 640 × 480. Video up to 1080p and 20 s. Meta gives no hard maximum for image size. | [1] |
| **Pre-filled link sticker / `contentURL` / attribution link** | **Not possible.** It isn't in the current docs. It was a closed-beta partner feature that was later removed. The appinio package closed its issue as "instagram api does not support a url anymore" (2024), and another report was still open in 2025. People can still add a **Link sticker** by hand: every account has had one since 2021. | [1][7][8][9][10] |
| **Pre-filled @mention, hashtag or caption** | **Not possible.** The docs have no parameter for them. | [1][11] |
| "via Nook" source label on the story | At launch, attribution was for approved partners only (Spotify, GoPro…). Expect **no** Nook label. Unverified for the 2026 UI. | [12] |
| Known glitch | Stories shared from third-party apps sometimes show a stray link. It also happens with Spotify and is on Instagram's side. | [13] |

**iOS clipboard catch (matters for the design).** The IG payload travels on
`UIPasteboard.general`, so the share **replaces whatever was on the clipboard**. Copying the
link "before opening Instagram" therefore does **not** work on iOS as-is. The plan:

1. Put the link on the **same pasteboard item** as an extra `public.utf8-plain-text` entry
   (`"public.utf8-plain-text": link`). Whether Instagram accepts an item that has an extra
   type, and whether its Link sticker pastes it, is **unverified**. Test this first, as a
   half-day spike, before building the UI.
2. If the spike shows Instagram rejects the item or drops the text, iOS falls back to:
   - keep the share sheet open behind Instagram;
   - when the app resumes (`AppLifecycleState.resumed`), show a banner in the sheet,
     `Adding a link? Copy it here, then paste it in a Link sticker.`, with a **Copy link**
     button;
   - word the hint under the Instagram button the same way.
   Copying the link *before* opening Instagram can't work on iOS, because the share
   overwrites the clipboard.
3. Android is unaffected: the intent carries the image, and the clipboard keeps the link
   copied just before.

### 5.2 iOS

**Info.plist** (`ios/Runner/Info.plist`). The file has **no** `LSApplicationQueriesSchemes`
today. Add it:

```xml
<key>LSApplicationQueriesSchemes</key>
<array>
  <string>instagram-stories</string>
  <!-- <string>facebook-stories</string>  when FB Stories ships -->
</array>
```

Check that this doesn't break `url_launcher`/`map_launcher` `canLaunch` calls. Those
packages read their own schemes, and adding the key only adds entries. If `map_launcher`
needs `comgooglemaps` etc. and they were never declared, that's an existing behaviour, so
leave it alone.

**Method channel** `app.nookph/story_share`, registered in `AppDelegate`. The app uses
`FlutterImplicitEngineDelegate`, so register in `didInitializeImplicitFlutterEngine` through
`engineBridge.pluginRegistry.registrar(forPlugin: "NookStoryShare")` and use its
`messenger()`. Sketch:

```swift
// ios/Runner/StoryShare.swift
import Flutter
import UIKit

enum StoryShare {
  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "app.nookph/story_share",
                                       binaryMessenger: registrar.messenger())
    channel.setMethodCallHandler { call, result in
      guard let args = call.arguments as? [String: Any] else {
        return result(FlutterError(code: "bad_args", message: nil, details: nil))
      }
      switch call.method {
      case "canShare":
        let target = args["target"] as? String ?? "ig"
        let scheme = target == "fb" ? "facebook-stories://share" : "instagram-stories://share"
        result(UIApplication.shared.canOpenURL(URL(string: scheme)!))
      case "share":
        result(share(args))
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  /// Returns "opened", "not_installed" or "error".
  private static func share(_ a: [String: Any]) -> String {
    guard let appId = a["appId"] as? String, !appId.isEmpty else { return "error" }
    let isFb = (a["target"] as? String) == "fb"
    let prefix = isFb ? "com.facebook.sharedSticker" : "com.instagram.sharedSticker"
    let urlString = isFb
      ? "facebook-stories://share"
      : "instagram-stories://share?source_application=\(appId)"
    guard let url = URL(string: urlString), UIApplication.shared.canOpenURL(url)
    else { return "not_installed" }

    var item: [String: Any] = [:]
    if let p = a["backgroundPath"] as? String, let d = FileManager.default.contents(atPath: p) {
      item["\(prefix).backgroundImage"] = d
    }
    if let p = a["stickerPath"] as? String, let d = FileManager.default.contents(atPath: p) {
      item["\(prefix).stickerImage"] = d
    }
    guard !item.isEmpty else { return "error" }
    item["\(prefix).backgroundTopColor"] = a["topColor"] as? String ?? "#344E41"
    item["\(prefix).backgroundBottomColor"] = a["bottomColor"] as? String ?? "#2F4833"
    if isFb { item["com.facebook.sharedSticker.appID"] = appId }
    if let link = a["link"] as? String { item["public.utf8-plain-text"] = link } // spike, §5.1

    UIPasteboard.general.setItems(
      [item], options: [.expirationDate: Date().addingTimeInterval(5 * 60)])
    UIApplication.shared.open(url, options: [:], completionHandler: nil)
    return "opened"
  }
}
```

```swift
// AppDelegate.didInitializeImplicitFlutterEngine, after GeneratedPluginRegistrant:
if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "NookStoryShare") {
  StoryShare.register(with: registrar)
}
```

Add `StoryShare.swift` to the Runner target in Xcode (or the project.pbxproj). Files that
aren't in the target compile in nobody's build except CI's, and CI will fail. The
`ios-build.yml` PR check catches this.

**App ID config:** nothing native. The id comes from Dart (`.env` → channel argument).
Apple team `WD8496XKN8` and bundle `app.nookph` only matter for the Meta platform
registration (§9.3).

### 5.3 Android

**Manifest** (`android/app/src/main/AndroidManifest.xml`):

```xml
<queries>
    <!-- existing entries stay -->
    <package android:name="com.instagram.android" />
    <!-- <package android:name="com.facebook.katana" />  when FB Stories ships -->
</queries>

<application …>
    …
    <provider
        android:name="app.nookph.NookShareFileProvider"
        android:authorities="${applicationId}.nook_share"
        android:exported="false"
        android:grantUriPermissions="true">
        <meta-data
            android:name="android.support.FILE_PROVIDER_PATHS"
            android:resource="@xml/nook_share_paths" />
    </provider>
</application>
```

`android/app/src/main/res/xml/nook_share_paths.xml` (the `res/xml` folder doesn't exist
yet):

```xml
<?xml version="1.0" encoding="utf-8"?>
<paths>
    <!-- Flutter's getTemporaryDirectory() is the app cache dir on Android. -->
    <cache-path name="nook_share" path="." />
</paths>
```

Why a subclass and its own authority: share_plus already declares a FileProvider (its own
`ShareFileProvider` subclass, authority `${applicationId}.flutter.share_provider`). The
manifest merger keys `<provider>` by `android:name`, so reusing a plain
`androidx.core.content.FileProvider` entry risks clashing with another plugin's. The
subclass is one line, `class NookShareFileProvider : androidx.core.content.FileProvider()`.
If `androidx.core` doesn't resolve in the app module, add
`implementation("androidx.core:core-ktx:1.13.1")` (any recent version) to
`android/app/build.gradle(.kts)` dependencies.

**Channel in `MainActivity`** (today it's an empty `class MainActivity : FlutterActivity()`):

```kotlin
package app.nookph

import android.content.Intent
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "app.nookph/story_share")
            .setMethodCallHandler { call, result ->
                val target = call.argument<String>("target") ?: "ig"
                when (call.method) {
                    "canShare" -> result.success(buildIntent(target, null) != null)
                    "share" -> result.success(share(call.arguments as Map<*, *>, target))
                    else -> result.notImplemented()
                }
            }
    }

    private fun pkg(target: String) =
        if (target == "fb") "com.facebook.katana" else "com.instagram.android"

    private fun buildIntent(target: String, appId: String?): Intent? {
        val action = if (target == "fb") "com.facebook.stories.ADD_TO_STORY"
                     else "com.instagram.share.ADD_TO_STORY"
        val intent = Intent(action)
        if (appId != null) {
            if (target == "fb") intent.putExtra("com.facebook.platform.extra.APPLICATION_ID", appId)
            else intent.putExtra("source_application", appId)
        }
        intent.setType("image/*")
        return if (packageManager.resolveActivity(intent, 0) != null) intent else null
    }

    /** "opened", "not_installed" or "error". */
    private fun share(a: Map<*, *>, target: String): String = try {
        val appId = a["appId"] as? String ?: return "error"
        val intent = buildIntent(target, appId) ?: return "not_installed"
        val authority = "$packageName.nook_share"
        (a["backgroundPath"] as? String)?.let {
            val uri = FileProvider.getUriForFile(this, authority, File(it))
            intent.setDataAndType(uri, "image/png")
            intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        (a["stickerPath"] as? String)?.let {
            val uri = FileProvider.getUriForFile(this, authority, File(it))
            intent.putExtra("interactive_asset_uri", uri)
            grantUriPermission(pkg(target), uri, Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        intent.putExtra("top_background_color", a["topColor"] as? String ?: "#344E41")
        intent.putExtra("bottom_background_color", a["bottomColor"] as? String ?: "#2F4833")
        // Meta's sample uses startActivityForResult; there is no useful result.
        startActivityForResult(intent, 0)
        "opened"
    } catch (e: Exception) {
        "error"
    }
}
```

Notes:
- With `setDataAndType` for the background, `buildIntent`'s `setType("image/*")` is replaced
  by the data's type. That's fine.
- On Android, put the link on the clipboard from Dart (`Clipboard.setData`) **before**
  `share`. The intent doesn't touch the clipboard. Android 13+ shows its own "Copied"
  confirmation, so skip Nook's toast there (`Build.VERSION.SDK_INT >= 33`). Otherwise
  two confirmations stack.
- Temp files must outlive the launch: Instagram reads the URI after our activity pauses
  (§4.6 cleanup rule).

**Dart wrapper** (`lib/core/services/story_share_service.dart`), registered in
`injection_container.dart` as a lazy singleton next to `ShareService`:

```dart
enum StoryTarget { instagram, facebook }
enum StoryShareResult { opened, notInstalled, error }

class StoryShareService {
  StoryShareService({String? appId})
      : _appId = appId ?? (dotenv.env['META_APP_ID']?.trim() ?? '');

  static const _channel = MethodChannel('app.nookph/story_share');
  final String _appId;

  bool get configured => _appId.isNotEmpty;

  Future<bool> canShare(StoryTarget t) async {
    if (!configured) return false;
    try {
      return await _channel.invokeMethod<bool>('canShare', {'target': _wire(t)}) ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false; // web, desktop, widget tests
    }
  }

  Future<StoryShareResult> share(
    StoryTarget t, {
    String? backgroundPath,
    String? stickerPath,
    String? link,
    String topColor = '#344E41',
    String bottomColor = '#2F4833',
  }) async {
    if (!configured) return StoryShareResult.error;
    try {
      final r = await _channel.invokeMethod<String>('share', {
        'target': _wire(t), 'appId': _appId,
        'backgroundPath': ?backgroundPath, 'stickerPath': ?stickerPath, 'link': ?link,
        'topColor': topColor, 'bottomColor': bottomColor,
      });
      return switch (r) {
        'opened' => StoryShareResult.opened,
        'not_installed' => StoryShareResult.notInstalled,
        _ => StoryShareResult.error,
      };
    } catch (_) {
      return StoryShareResult.error;
    }
  }

  static String _wire(StoryTarget t) => t == StoryTarget.facebook ? 'fb' : 'ig';
}
```

(`'key': ?value` is Dart 3.8+ null-aware map elements. The SDK constraint is
`^3.10.8`, and the codebase already uses `?i.kind` in set literals.)

Links: add `static String cupLink(String cupId, {required String ref})` →
`'https://www.nookph.app/cups/$cupId?ref=$ref'` to `ShareService`, next to `profileLink`
and `crawlLink`.

### 5.4 Fallback: system share sheet

`share_plus` (already `^12.0.2`), same call shape as the crawl page:

```dart
await SharePlus.instance.share(ShareParams(
  files: [XFile(file.path, mimeType: 'image/png')],
  text: '${cafe.name} on Nook\n\n$link',   // link = …/cups/<id>?ref=cup_share
  subject: '${cafe.name} on Nook',
  sharePositionOrigin: origin,            // required on iPad
));
```

Copy: `My cup at {café} on Nook` reads better than a bare name; final wording per
COFFEE_VOICE (rows 22–24 are the existing share strings; add this as a new row). Note that
many targets drop `text` when a file is attached (Instagram, some Android sheets); that's
why the URL is also printed on the image.

### 5.5 Facebook Stories (later, cheap)

Same App ID, same images, no SDK. Roughly 20 more lines per platform, already shaped into
the channel above (`target: "fb"`) [2][3]:

- iOS: open `facebook-stories://share`, add `facebook-stories` to
  `LSApplicationQueriesSchemes`, and use the pasteboard keys with the
  `com.facebook.sharedSticker.` prefix. **`com.facebook.sharedSticker.appID` is required.**
- Android: action `com.facebook.stories.ADD_TO_STORY` with the extra
  `com.facebook.platform.extra.APPLICATION_ID`. Grant the URI to `com.facebook.katana`.
  Add `<package android:name="com.facebook.katana"/>` to `<queries>`.

Facebook reaches far more of Nook's audience than Instagram does (§1). If the
first-week numbers show `system` shares going to Facebook, turn this on in the next RC. The
UI cost is one more button in the sheet ("Facebook Story").

### 5.6 Package choice

Checked on pub.dev and GitHub on 2026-10-11 [14]:

| Package | Latest (date) | Stories? | Verdict |
|---|---|---|---|
| `share_plus` | 13.3.1 (2026-10-01); Nook pins `^12.0.2` | No: system sheet only | Keep it as the **fallback**. Don't bump the major version in this feature. |
| `appinio_social_share` | 0.3.3 (2026-08-12; the previous release was 2024-08) | IG + FB stories | **No.** It pulls in the full Facebook SDK (FBSDKCoreKit/ShareKit 17 on iOS, `facebook-share` 17 on Android), needs the client token and SDK init wiring, compiles against SDK 31, and has 83 open issues, including stories broken on iOS 18 (#315, #319) and attributionURL (#332). |
| `social_share` | 2.3.1 (2022-11) | IG stories | **No.** Unmaintained, no SwiftPM. |
| `social_sharing_plus` | 1.2.3 (2024-09) | No IG stories | No |
| `social_share_kit` | 0.2.0 (2026-08-07, 0 likes, repo created that day) | IG + FB stories, no vendor SDK | Promising but too new to bet a release on. |

**Decision: a small in-app MethodChannel** (§5.2, §5.3: about 60 lines of Swift and 60 of
Kotlin). The official surface is tiny and has been stable since 2018/2023. It adds no
dependency, no Facebook SDK and no client token, and we control the clipboard behaviour
that §5.1 depends on.

### 5.7 Configuration: the Meta App ID

The App ID is **not a secret** (it ships inside every app that uses it and appears in the
launch URL), but keep it out of source so dev and prod can differ and so the team follows
one pattern:

- Add `META_APP_ID=<id>` to `.env` (the runtime config loaded by `flutter_dotenv`,
  documented in nook-mobile `CLAUDE.md`). Read it once:
  `final metaAppId = dotenv.env['META_APP_ID']?.trim() ?? '';`
- CI: both release workflows write `.env` from secrets
  (`.github/workflows/ios-release.yml` step "Write .env", `android-release.yml` likewise).
  Add `META_APP_ID: ${{ secrets.META_APP_ID }}` to each step's `env:` and
  `echo "META_APP_ID=$META_APP_ID"` to the block. **Do not** add it to the `:?missing secret`
  guard: an empty value must degrade, not fail the build.
- Add the secret: repo → Settings → Secrets and variables → Actions → `META_APP_ID`.
  Update the secrets table in nook-mobile `docs/release_ci.md`.
- Behaviour when empty: the IG/FB buttons are hidden and only the system sheet is offered;
  log nothing extra. This keeps forks, PR builds and local runs working.
- Pass the id to native code as a method-channel argument (no Info.plist/manifest entry is
  needed for IG Stories; §5.2/§5.3).
- **Worktrees:** copy the real `.env` into a new worktree before `flutter run`
  (memory note "Mobile worktree .env").

### 5.8 Error handling

| Failure | What the person sees | Logged |
|---|---|---|
| photo didn't load in 10 s | inline error in the sheet + Retry | `cup_share_failed{stage: render}` |
| `toImage` / PNG encode throws | toast `Couldn't create the image.` (same string as crawls) | `stage: render` |
| file write fails (disk full) | same toast | `stage: write_file` |
| IG launch returns false / throws | fall through to the system sheet automatically, toast `Instagram didn't open, so here's the share sheet.` | `stage: launch_ig` |
| `META_APP_ID` empty | IG button hidden | — |
| No network | rendering works offline once photos are cached; the link still copies | — |

Double taps: guard with a `_busy` flag like `CrawlSharePage._share`.

---

## 6. Web: the cup page

### 6.1 Route

`app/cups/[id]/page.tsx` on nook-webapp → `https://www.nookph.app/cups/<cupId>`.

- Why not `/c/…`: taken by crawls and crew invites (`app/c/[code]`, mobile
  `WebLinks.crawl`, AASA `/c/*`).
- Why not `/cafes/[id]/cups/[cupId]`: the cup id alone identifies the café (the RPC returns
  it), a flat path is shorter in a pasted sticker, and a cup that moves café (it can't today)
  wouldn't break links. The page links to `/cafes/<cafeId>` and `/cafes/<cafeId>/cups`.
- `/cups/00000000-…` currently returns 404 on production (checked 2026-10-11), so the path is free.

Build it on top of the webapp's `feat/cups` branch (worktree
`/home/lfamily/nook/.worktrees/cups-web`; it has `lib/data/cups.ts`, `cups-mappers.ts`,
`app/components/cafe/CupCard.tsx`, `CupKindIcon.tsx`, `RatingStars.tsx`), and reuse
`StoreBadges` (`app/components/StoreBadges.tsx`) and `lib/app-links.ts`
(`APP_STORE_URL`, `PLAY_STORE_URL`). If `feat/cups` has merged to `main` by then, branch
from `main`.

### 6.2 Page

```
 ┌──────────────────────────────────────────────┐
 │ Navbar                                        │
 │                                               │
 │ ┌───────────────┐  Spanish latte · Coffee     │ (desktop: two columns;
 │ │               │  at Volte Specialty Café →  │  mobile: photo on top)
 │ │   PHOTO(S)    │  Lahug, Cebu City           │
 │ │   4:5, swipe  │  ★★★★☆  · Oct 11            │
 │ │               │  "The Spanish latte is the  │
 │ └───────────────┘   move…"  (full note)       │
 │                    @sai on Nook               │ author label links /u/<username>
 │                                               │
 │ ┌───────────────────────────────────────────┐ │
 │ │ Get Nook to find your next café            │ │ CTA band
 │ │ [App Store badge] [Google Play badge]      │ │
 │ │ Open in the app                            │ │ only on mobile UA
 │ └───────────────────────────────────────────┘ │
 │ More cups at Volte →   (/cafes/<id>/cups)     │
 │ Footer                                         │
 └──────────────────────────────────────────────┘
```

- Data: `getCupPublic(id)` in `lib/data/cups.ts`, using the session-less anon client like
  `getCafeCups`, wrapped in `cache()` and the same `cacheLife` profile the cafe pages use
  (a short one: moderation must take effect within minutes, e.g. `revalidate: 300`).
- Invalid UUID (`isCafeId`-style check) → `notFound()` without calling the RPC.
- RPC returns `null` (hidden, removed, deleted, blocked author, suspended author, inactive
  café, unknown id) → `notFound()`, and `generateMetadata` returns
  `robots: { index: false }` with a generic title, as `app/cafes/[id]/cups/page.tsx` does
  for a missing café (`notFound()` fires after the shell flushes under cacheComponents).
- **All cup pages are `noindex`** (`robots: { index: false, follow: true }`) even when
  visible: they're share landings for one person's post, not search content; the café's
  `/cafes/<id>/cups` page is the indexable one (and canonical for the content). Don't add
  `/cups/*` to `app/sitemap.ts`.
- Canonical: `${SITE_URL}/cups/<id>` without `?ref`.
- "Open in the app": a plain link to the same URL won't open the app from the same page
  (universal links don't trigger on same-domain navigation in Safari). Use the custom scheme
  only if the app adds a cup route for it; for 1.1.5 omit the button and rely on the link
  itself opening the app when tapped from IG/Messenger (§6.6).
- Copy for the CTA (COFFEE_VOICE tone): `Find your next café on Nook` /
  `Free on the App Store and Google Play.` (matches `/download-app`).
- Alt text: `{item} at {café}, photo by @{username}`.

### 6.3 New RPC: `get_cup_public(p_cup_id uuid)`

**Needed:** yes. Existing reads are per café (`get_cafe_cups` pages through a café;
finding one cup would mean paging up to 100 at a time and still miss filtered ones) or per
profile (`get_profile_cups` returns only the newest 10 per café and is gated by
`show_profile_highlights`). Neither answers "this one cup, if public".

Contract (returns `jsonb` or `null`):

```json
{
  "cup": { /* the standard cup object from CUPS_APPLY "cup object",
             public items only, moderation_status null */ },
  "cafe": { "id": "…", "name": "…", "neighborhood": "…", "city": "…",
            "featured_image_url": "…|null", "instagram": "<raw social_links.instagram>|null" }
}
```

Visibility rules (mirror `get_cafe_cups`, stricter on authors):

1. Resolve the id with `cup_resolve(p_cup_id)` (accepts a cup id, a legacy review id, a
   virtual photo-day id, or an old id whose visit was later copied —
   `cup_canonical_id`). No row → `null`.
2. Café must be **active** (`cafes.status = 'active'`). Deliberately *not*
   `cup_cafe_readable`, which also lets owners/super admins see inactive cafés: a public
   share page should look the same to everyone.
3. The visit must be in `cup_public_visits(cafe_id, user_id, viewer)` — that already
   requires `moderation_status = 'visible'` (merged with the legacy review's status),
   at least some public content, and no block either way when there is a viewer
   (`viewer = auth.uid()`, null for the web's anon client).
4. Author profile must exist with a username, `is_suspended = false` and
   `account_status = 'active'` (the same gate `get_profile_cups` applies).
5. Items via `cup_visit_json(id, user_id, cafe_id, false)` → `cup_items_json(..., p_own=false)`,
   which keeps only public photos (`cup_photo_is_public`: not hidden, visible, and for a review
   photo, its review visible).

Migration file (nook-supabase, after `20261011150000_cups_5_untyped_legacy_photos.sql`;
pick the next free timestamp on the day it's written, e.g. `20261012100000_get_cup_public.sql`):

```sql
-- get_cup_public: one public cup for the web's /cups/<id> share page.
-- Additive: one new function; no existing table, column, policy, trigger or
-- function changes. Mirrors get_cafe_cups' visibility (cup_public_visits),
-- plus an active-cafe and active-author gate.
create or replace function public.get_cup_public(p_cup_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path to 'public'
as $$
declare
  v_viewer uuid := (select auth.uid());
  v_id     uuid := cup_canonical_id(p_cup_id);
  v_res    record;
  v_cafe   cafes%rowtype;
  v_cup    jsonb;
begin
  if p_cup_id is null then
    return null;
  end if;

  select * into v_res from cup_resolve(p_cup_id);
  if not found then
    return null;
  end if;

  select * into v_cafe from cafes where id = v_res.cafe_id and status = 'active';
  if not found then
    return null;
  end if;

  if not exists (
    select 1 from profiles p
    where p.id = v_res.user_id
      and p.username is not null
      and not coalesce(p.is_suspended, false)
      and p.account_status = 'active'
  ) then
    return null;
  end if;

  if not exists (
    select 1 from cup_public_visits(v_res.cafe_id, v_res.user_id, v_viewer) v
    where v.id = v_id
  ) then
    return null;
  end if;

  v_cup := cup_visit_json(v_id, v_res.user_id, v_res.cafe_id, false);
  if v_cup is null then
    return null;
  end if;

  return jsonb_build_object(
    'cup', v_cup,
    'cafe', jsonb_build_object(
      'id', v_cafe.id,
      'name', v_cafe.name,
      'neighborhood', v_cafe.neighborhood,
      'city', v_cafe.city,
      'featured_image_url', v_cafe.featured_image_url,
      'instagram', nullif(btrim(v_cafe.social_links ->> 'instagram'), '')
    )
  );
end;
$$;

revoke all on function public.get_cup_public(uuid) from public;
grant execute on function public.get_cup_public(uuid) to anon, authenticated, service_role;
```

Implementation notes for whoever writes it:
- `cup_public_visits` returns `v.id` = the cups row id for real cups, the review id for an
  un-copied review, the virtual id for a photo day — the same value `cup_canonical_id`
  returns for each, so `v.id = v_id` matches all three. Confirm with the e2e script.
- `cup_resolve` is `revoke`d from anon; calling it inside a `security definer` function owned
  by `postgres` is fine (that's how `get_cafe_cups` calls its helpers).
- Check `profiles.account_status`/`is_suspended` column names against production before
  applying (they're used by `get_profile_cups` in `cups_2_read_rpcs.sql`, so they exist).
- Rollback file `supabase/rollbacks/<ts>_get_cup_public.down.sql`:
  `drop function if exists public.get_cup_public(uuid);`

**Legacy-safe validation** (mandatory; memory note "legacy-safe migrations" and
CUPS_APPLY.md "How this was validated"):

1. Before: `npx -y supabase@2.109.1 db query --linked -f supabase/verify/cups_legacy_fingerprint.sql`
   and save the 5 hashes. Also save an md5 of every existing `cup%` function definition:
   ```sql
   select md5(string_agg(p.proname||'('||pg_get_function_identity_arguments(p.oid)||')='||md5(pg_get_functiondef(p.oid)), E'\n' order by 1))
   from pg_proc p where p.pronamespace = 'public'::regnamespace
     and (p.proname like 'cup\_%' or p.proname like '%cups%' or p.proname like '%\_cup\_%');
   ```
2. On a throwaway Postgres 17.6 container built from the production catalog (CUPS_APPLY.md
   "How this was validated"), apply the migration **twice** (idempotent), then run the
   fingerprint again: all five legacy hashes identical (the fingerprint excludes names
   containing `_cup_`, so the new function doesn't move it). The second query must change
   by exactly one entry (the new function); diff the `string_agg` output, not just the md5.
3. Assertions to add to `supabase/verify/cups_local_e2e.sql` (or a new
   `get_cup_public.verify.sql`):
   - visible posted cup → object with the cup and café; `cup.moderation_status` is null;
   - hidden cup (`moderation_status='hidden'`) → null; removed → null;
   - cup whose only photo is `is_hidden` and no note/rating/text → null (no public content);
   - legacy review visit (virtual id = review id) → object; after editing it (copied to a
     cups row) the **old** id still returns the object (canonical id);
   - photo-day virtual id → object;
   - café `status <> 'active'` → null, even as the café owner or a superadmin JWT;
   - author suspended / `account_status <> 'active'` → null;
   - as an authenticated viewer who blocked the author (or is blocked by them) → null;
     as anon → object;
   - random UUID → null; `null` → null;
   - anon can execute; `cup_resolve` etc. remain non-executable by anon.
4. Apply to production with the documented path (memory "Supabase apply path"):
   `npx -y supabase@2.109.1 db query --linked -f supabase/migrations/<ts>_get_cup_public.sql`,
   record it in `supabase_migrations.schema_migrations`, re-run the fingerprint, compare.
   The user runs production steps.

No app build depends on it except the web page; no legacy client calls it. It can ship any
time **before** the web page deploys.

Note: the Cups migrations live on the nook-supabase branch **`feat/cups`**, which is local
and 6 commits ahead of `origin/main` as of 2026-10-11 (all five steps are on production).
Put this migration on top of `feat/cups` (or on `main` after it merges) so the verify
scripts it relies on are present.

### 6.4 OG / Twitter image

`app/cups/[id]/opengraph-image.tsx` (file convention, like `app/u/[username]/opengraph-image.tsx`
and `app/c/[code]/opengraph-image.tsx`), 1200 × 630, `ImageResponse` from `next/og`:

```
 ┌──────────────────────────────────────────────────────────────┐
 │ ┌──────────────────┐   Spanish latte · Coffee                 │
 │ │                  │   Volte Specialty Café                   │ Poppins 600 (lib/og/fonts)
 │ │   PHOTO (cover)  │   Lahug, Cebu City                       │ Poppins 400, MUTED
 │ │   504 × 630      │   ★★★★☆                                 │
 │ │                  │                                          │
 │ └──────────────────┘   [nook logo]                            │ public/logo.svg
 └──────────────────────────────────────────────────────────────┘  PAPER #F7F6F2 ground
```

- Reuse the profile OG helpers: `inline(url)` (fetches the photo with a 4 s timeout, JPEG/PNG
  only — all 19 production `user_photos` are `.jpg` on
  `lucerocris.sgp1.cdn.digitaloceanspaces.com`, an allowed host in `next.config.ts`), `clip()`,
  the INK/MUTED/PAPER constants and Poppins font loading.
- No photo (note cup): brand-green left panel with the clipped note in quotes instead.
- Missing/hidden cup: the wordmark alone (same as the profile image's "not found" branch) —
  never leak a moderated photo through a cached OG image.
- `Cache-Control: public, max-age=300, s-maxage=300` so a cup hidden by moderation stops
  unfurling within minutes. (Messenger/Facebook cache OG scrapes on their side; that's
  outside our control — document it in Open questions.)
- `generateMetadata` sets `openGraph` with `BASE_OPEN_GRAPH`, `url: /cups/<id>`,
  `title: "{item} at {café}"` (or `"A cup at {café}"`), description `"{stars}/5 · {area} · on Nook"`,
  and `twitter.card = "summary_large_image"`. Don't use `cafeShareMetadata` here: it would set
  the café's featured photo as the image and override the file-convention image.

### 6.5 Web attribution beacon

There is no web analytics package. Minimal, dependency-free approach:

- A small client component on the cup page fires once on mount when `ref` is present:
  `fetch("https://us.i.posthog.com/i/v0/e/", { method: "POST", keepalive: true, body: JSON.stringify({ api_key: NEXT_PUBLIC_POSTHOG_KEY, event: "cup_page_viewed", distinct_id: <random per-tab uuid>, properties: { ref, cup_id, cafe_id, $current_url: location.href } }) })`.
  The project token is public (it's in nook-mobile's Info.plist and manifest). Add
  `NEXT_PUBLIC_POSTHOG_KEY` to the Vercel project env for nook-webapp.
- Store badges get an `onClick` that sends `cup_page_store_tapped` (`store`: `ios`/`android`)
  the same way, and their hrefs gain campaign tags: Play
  `&referrer=utm_source%3Dnook_web%26utm_medium%3Dcup_page%26utm_campaign%3D<ref>`;
  App Store `?ct=<ref>&pt=<provider token>` (§9.3).
- Use `$process_person_profile: false` in properties so these anonymous hits don't create
  person profiles. The PostHog project also holds an unrelated app's events
  (COFFEE_COMMUNITY.md §0) — prefix nothing, but filter by these event names.
- No cookies, no consent banner needed for this anonymous count (no identifier persists
  beyond the tab). Confirm with the privacy page owner (privacy.nookph.app) if unsure.

### 6.6 Opening the app from the link

What's configured today (checked 2026-10-11):

| Piece | State |
|---|---|
| iOS entitlement | `applinks:www.nookph.app` (`ios/Runner/Runner.entitlements`) |
| AASA | live at `https://www.nookph.app/.well-known/apple-app-site-association`, appID `WD8496XKN8.app.nookph`, components `/u/*` and `/c/*` only |
| Android intent filter | `autoVerify` for `https://www.nookph.app` path prefixes `/u/` and `/c/` (`AndroidManifest.xml`) |
| `assetlinks.json` | **404 on production.** A draft with three SHA-256 fingerprints exists uncommitted in the webapp worktree `/home/lfamily/nook/.worktrees/webapp-assetlinks` (branch `feat/assetlinks`). Until it's deployed, Android opens these links in the browser. |
| App router | `GoRoute` children of `/` for `u/:username` and `c/:code` (`lib/core/router/app_router.dart` ~line 147), parsing in `lib/core/router/web_links.dart` |

To add:

1. **Web:** add `{ "/": "/cups/*", "comment": "Shared cups" }` to
   `public/.well-known/apple-app-site-association`. Ship `assetlinks.json` (finish
   `feat/assetlinks`: confirm the Play app-signing SHA-256 in Play Console → Setup → App
   signing, memory note "nook-mobile signing & SHA-1").
2. **Android:** add `<data android:scheme="https" android:host="www.nookph.app" android:pathPrefix="/cups/" />`
   to the existing autoVerify intent filter.
3. **App router:** a `GoRoute(path: 'cups/:id', …)` next to `u/:username`, validating the id
   with a new `WebLinks.cupId(raw)` (UUID regex) and opening a small `CupLinkPage` that
   calls `get_cup_public` and shows the cup card with a "See the café" button to
   `/cafe/<cafeId>`; `LinkNotFoundPage` on null. (Simplest acceptable 1.1.5 version: resolve
   the cup's café and `context.go('/cafe/<cafeId>')`, opening its Cups section; a dedicated
   page can come later.)
4. Universal-link caveat: iOS fetches AASA at install/update; the new `/cups/*` path only
   opens the app for people who install or update **after** the AASA change. That's why the
   web deploy goes first (§9.2).
5. Instagram's in-app browser generally does **not** hand universal links to other apps
   (people land on the web page). The page must stand on its own; that's the main path.

---

## 7. Tagging the café

Instagram can't pre-fill an @mention (§5.1). What Nook can do:

- **Source of the handle:** `cafes.social_links ->> 'instagram'`. In production it's a full
  URL, not a handle — e.g. `https://www.instagram.com/lorenzo.s.cafe/?hl=en`,
  `https://www.instagram.com/pulso.cafe_cebu/reels/?__d=1%2B` — and **11 of 54 active cafés**
  have one (2026-10-11). Parse with the existing extractor
  `CafeHoursLocationSection.socialHandle(raw)` (`lib/features/cafe_details/presentation/widgets/cafe_info.dart:176`,
  `@visibleForTesting static`, wraps `_extractHandle`, which already skips `/p/`, `/reel/`
  etc.). Move it into `lib/core/utils/social_handle.dart` as `instagramHandle(String raw)` and
  have both call sites use it; keep its tests.
- **Where the sheet gets it:** the cafe page already has `CafeDetailsEntity.socialLinks`. The
  composer only gets a `PickedCafe` (id, name, area, image), so the share sheet takes an
  optional `String? instagramRaw` and, when null, reads it once:
  `supabase.from('cafes').select('social_links').eq('id', cafeId).maybeSingle()` (anon can
  read active cafés; this is the same table the details datasource reads). The web gets it
  from `get_cup_public.cafe.instagram`.
- **UI:** the row in the share sheet `Tag the café: @handle   Copy` → clipboard + toast
  `@handle copied. Paste it in a Mention sticker.`; event `cafe_handle_copied`.
- **Owners' repost loop:** when a story mentions the café's account, the café gets a
  notification and can "Add to their story" (an Instagram feature for mentions). That only
  works if the person actually adds the mention — so the handle copy matters. The web cup
  page also shows `@handle` linking to `https://www.instagram.com/<handle>` for the same
  reason.
- Owner outreach (not code): add a line to the claim/outreach material — "When guests share
  a cup from Nook, tap the mention and add it to your story." The "Featured on Nook" kit
  (§2 Later) builds on this.

---

## 8. Edge cases and QA checklist

Run on the RC build from TestFlight (iOS) and the Play internal track (Android) — both are
**release** builds, so analytics are live (`kAnalyticsEnabled`); use PostHog's live events
view filtered to your person to verify.

### Device matrix

| | IG installed | IG not installed |
|---|---|---|
| iPhone, iOS 17 or 18 | ✔ | ✔ |
| iPhone, latest iOS (26) | ✔ | — |
| iPad (share sheet anchor) | ✔ | ✔ |
| Android 14–16 Pixel/Samsung | ✔ | ✔ |
| Android 10 (pre-package-visibility) | ✔ | — |

### Checklist

- [ ] Post a cup with 1 photo → toast shows **Share · Rank it** (café not ranked) or **Share**
      (already ranked) → Share opens the sheet with the right photo.
- [ ] Post a cup with 3 photos → pager in the preview; the exported image uses the selected one; `photo_index` logged.
- [ ] Note-only cup → note layout; long note (1,000 chars) clips with "…" at a word.
- [ ] Stars-only cup → card reads correctly; unrated cup → no stars row.
- [ ] Long café name (≥ 60 chars) → 2 lines + ellipsis, nothing under IG's top/bottom UI.
- [ ] Legacy photo with `kind == null` → no "· Coffee" suffix.
- [ ] Emoji in a note renders on both platforms.
- [ ] Device text size at maximum → the sheet scales, the **image** doesn't.
- [ ] Dark/very bright photo → text readable (scrim).
- [ ] IG installed: tapping Instagram Story opens the IG story composer with the image as
      background;
      on Android the clipboard holds the link; on iOS the spike's chosen path (link on the
      pasteboard item, or Copy link on return) works; a Link sticker pastes it. No "via
      Nook" label is expected (§5.1).
- [ ] IG not installed → primary button is "Share image"; system sheet has the PNG and text.
- [ ] `META_APP_ID` empty (debug build without it) → IG button hidden, no crash.
- [ ] IG launch failure (simulate by a wrong App ID) → falls back to the system sheet with a toast.
- [ ] Own cup "…" menu → Share cup first; other people's menus unchanged (Report/Block).
- [ ] Story viewer on your own story → share icon; others' stories → no icon; playback pauses
      while the sheet is open and resumes after.
- [ ] Hidden own cup (moderated) → no Share option.
- [ ] Slow network (Network Link Conditioner / Android emulator throttling) → "Preparing…"
      state; 10 s photo timeout shows the error + Retry.
- [ ] Airplane mode with cached photo → image still renders; link copies.
- [ ] Rapid double tap on Instagram Story → one launch.
- [ ] Android: IG reads the file (no "couldn't load media"); after 1 hour temp files are cleaned.
- [ ] iPad: system share sheet anchors to the button (no crash).
- [ ] Copy handle → clipboard holds `@handle` without URL junk (`?hl=en`, `/reels/`).

Web:
- [ ] `/cups/<visible id>` renders, OG image correct in the Facebook Sharing Debugger and
      `opengraph.xyz`; Messenger unfurl shows photo + café + stars.
- [ ] `?ref=cup_story` → `cup_page_viewed` arrives in PostHog with `ref`.
- [ ] Hidden / removed / deleted cup → 404 page, `noindex`, OG image is the bare wordmark.
- [ ] Inactive café → 404. Suspended author → 404.
- [ ] Invalid UUID → 404 without a DB call.
- [ ] Legacy review id link → page works; still works after the author edits that visit.
- [ ] Page is `noindex` even when visible; canonical has no `?ref`.
- [ ] Store badges carry the campaign tags; tap logs `cup_page_store_tapped`.
- [ ] AASA includes `/cups/*`; on an iPhone with the new build, tapping the link in Notes /
      Messages opens the app on the café; from IG's in-app browser it opens the web page.
- [ ] Android with `assetlinks.json` live: `adb shell pm get-app-links app.nookph` shows
      `www.nookph.app: verified`; the link opens the app.

Analytics verification: in PostHog, filter events `cup_share_opened`, `cup_shared`,
`cup_share_failed`, `cafe_handle_copied`, `cup_page_viewed`; check every property in §1 is
present and typed (bools as bools).

---

## 9. Rollout

### 9.1 Branching (nook-mobile)

State on 2026-10-11:
- PR #130 (`release/1.1.5` → `main`, nook-ph/nook-mobile) is **merged** (`4389e37`).
- `v1.1.5-rc1` is tagged on that commit **without** this feature.

Per `docs/release_ci.md` ("QA loop and release candidates"), every RC is a tag on `main`
and both stores rebuild from the same commit. So:

1. Branch **`feat/share-cup-story` from `main`** (at or after `4389e37`).
2. Build and test:
   - Run `flutter analyze`, `dart format .` and `flutter test`.
   - Add widget tests for the card. No goldens: assert the texts, the ellipsis and the
     layout choice.
   - Add unit tests for `instagramHandle` and the `cupLink` builder.
   - Re-test any rc1 QA fixes that land on `main` meanwhile. Expect small conflicts in
     `cup_composer_sheet.dart`, `cup_actions.dart`, `toast_helper.dart`,
     `review_actions_sheet.dart`, the story viewer, `AndroidManifest.xml` and `Info.plist`.
3. Open a **PR into `main`**. The `android-build.yml` and `ios-build.yml` checks must pass.
4. Before tagging:
   - The **web cup page is live on www.nookph.app**, with AASA `/cups/*` (§9.2).
   - `get_cup_public` is on production.
   - The `META_APP_ID` secret is set.
5. Merge, then **tag the next RC from `main`**: `v1.1.5-rc2`, or whichever `-rcN` is next
   if rc2 goes out first for other fixes. One tag builds both:
   - Android → Play **internal** track ("Cris QA" testers)
   - iOS → **TestFlight**

   `pubspec.yaml` stays `1.1.5`; CI sets the build number (100 + run number). Post the
   printed build numbers in the QA thread.
6. QA per §8 on those builds. If there are bugs: `fix/<name>` from `main` → PR → next
   `-rcN`. Never patch one store only.
7. When approved, promote per release_ci.md (Android promote workflow, iOS submit for
   review).
8. If this RC becomes the release, update `ios/metadata/en-US/release_notes.txt`
   (≤ 500 chars, Play's limit), e.g. "Share your cup to your Instagram Story."
9. After the Dart changes, run `graphify update nook-mobile` from the workspace root.

### 9.2 Order of deploys

1. **DB:** `get_cup_public` migration on production (user runs it; §6.3). Harmless alone.
2. **Web:** cup page + OG image + AASA `/cups/*` + `assetlinks.json` + beacon, merged to
   `main` of `lucerocris/nook-webapp` (deploys on push). Verify the live deployment id
   changed with `npx vercel inspect https://www.nookph.app` (workspace CLAUDE.md), and
   `curl` a visible `/cups/<id>` and the AASA. This must be **live on www before the RC is
   tagged**, or QA's shared stories point at 404s and the AASA misses `/cups/*`.
3. **Mobile:** merge the PR into `main`, then tag the next `v1.1.5-rcN`. The
   `META_APP_ID` secret must be set **before** the tag, or the RC ships without the
   Instagram button.
4. Meta app (§9.3) can be done any time before step 3; a dev build can test with the same id.

### 9.3 What the user must do: Meta App ID

The user (Cris) does this once. It takes about 15 minutes. Steps follow Meta's current
"Create an app" flow [5][15]:

1. Go to <https://developers.facebook.com/apps/creation/> and sign in with the Facebook
   account that should own the app. If it isn't a developer yet, accept the developer
   terms.
2. **App details:** name `Nook`, contact email `noreply@nookph.app` or your own → **Next**.
3. **Use cases:** pick **Other** at the bottom. There's no "Share to Stories" use case.
   Click **Next**.
4. **App type:** **Consumer** → **Next**.
5. **Business portfolio:** choose to connect later / skip. Business verification isn't
   needed for Stories sharing (our inference: it only gates data and permission products).
6. **Review → Go to dashboard.** The **App ID** is at the top of the dashboard and under
   **App settings → Basic**. Copy it.
7. **App settings → Basic:**
   - Privacy Policy URL `https://privacy.nookph.app/`
   - Category: *Food & drink* or *Lifestyle*
   - App icon: the 1024 px Nook icon
   - User data deletion: set an instructions URL or the privacy page section if the form
     asks for one
   - **Save changes**
8. Still on Basic, click **+ Add platform**:
   - **iOS:** Bundle ID `app.nookph`, iPhone Store ID `6782604940` (from
     `nook-webapp/lib/app-links.ts`). Save.
   - **Android:** Package name `app.nookph`, Class name `app.nookph.MainActivity`. Key
     hashes are only needed for Facebook Login or SDK; leave them empty unless the console
     insists. If it does, use the Play app signing key's SHA-1 in base64 (Play Console →
     Setup → App signing). Save.
   - Whether these registrations are required for Stories is unverified (§5.1); we add them
     to be safe.
9. Switch **App Mode** (top bar) from *Development* to **Live**. If it's blocked, the page
   lists what's missing, usually the privacy URL or category from step 7. Whether
   Development mode works for Stories is unverified; Live removes the doubt.
10. Hand the App ID over:
    - GitHub `nook-ph/nook-mobile` → Settings → Secrets and variables → Actions → **New
      repository secret** `META_APP_ID`.
    - Add `META_APP_ID=<id>` to your local `.env` and to any worktree `.env`.
11. Smoke test before the RC: on a phone signed in to an Instagram account that has **no**
    role on the Meta app, share a cup from a local release build
    (`flutter run --release`). The story composer must open with the image, not the
    "doesn't currently support sharing to Stories" error.

App Store campaign links (optional, for `ct=`): App Store Connect → Apps → Nook → (App
Analytics) → Acquisition → **Generate a campaign link**; copy the `pt=` provider token into
the web's store-badge hrefs.

### 9.4 Estimate

| Part | Size | Days |
|---|---|---|
| Story card widget (2 layouts) + renderer + preview pager | M | 1.5 |
| Share sheet, entry points (toast 2-action, own menu, story viewer), handle copy | M | 1.0 |
| iOS clipboard spike (§5.1: link on the IG pasteboard item?) | S | 0.5 |
| Native IG Stories (iOS + Android MethodChannel), FileProvider, `.env`/CI config, fallbacks | M | 1.0 |
| Analytics + link builder + tests | S | 0.5 |
| `get_cup_public` migration + validation on a prod-copy container | S | 0.5 |
| Web cup page + OG image + beacon + AASA/assetlinks + store tags | M | 1.5 |
| App route for `/cups/:id` | S | 0.5 |
| QA across the matrix + fixes in the RC loop | — | 1.0 |
| **Total** | | **≈ 8 days** (≈ 6.5 without the dedicated app cup page and Save image) |

FB Stories later: +0.5–1 day.

---

## 10. Open questions

1. **Apex domain.** `https://nookph.app` answers 200 with an empty body (2026-10-11). Should
   it redirect to `www`? Until it does, the card prints `www.nookph.app`.
2. **Sticker vs. background.** Ship the single full-card background (simplest) or the
   movable-sticker variant (§4.6)? Default: background only in 1.1.5.
3. **Others' cups.** Keep own-only (§3.4), or add an author opt-in ("Let others share my
   cups") in a later release?
4. **Save image button.** Add `gal` for a direct save, or rely on the system sheet's save?
5. **FB Stories.** Facebook reaches far more Filipinos than Instagram; should FB Stories be
   pulled into 1.1.5 (+~1 day) rather than later?
6. **OG caches.** A cup hidden after being shared may keep unfurling in Messenger/Facebook from
   their own cache until re-scraped. Acceptable, or should moderation call the Graph API
   re-scrape (needs an app token)?
7. **Web beacon consent.** Is an anonymous, cookie-less PostHog hit on the cup page fine under
   the current privacy policy (privacy.nookph.app)?
8. **Nook's own IG account.** Is there one to tag on the card or in the hint ("tag @nook…")?
   None is referenced in the repos; not printed until confirmed.
9. **`CupCard.moderationStatus`.** Adding it touches `CupsJson` and tests; alternatively hide
   Share for all of `my_cups` items that aren't in `cards[]`. Pick one.

## Sources

All accessed 2026-10-11.

1. Meta: Instagram Platform, *Sharing to Stories*. <https://developers.facebook.com/docs/instagram-platform/sharing-to-stories> (markdown: <https://developers.facebook.com/documentation/instagram-platform/sharing-to-stories.md>)
2. Meta: *Sharing to Stories, Android developers* (Facebook). <https://developers.facebook.com/docs/sharing/sharing-to-stories/android-developers>
3. Meta: *Sharing to Stories, iOS developers* (Facebook). <https://developers.facebook.com/docs/sharing/sharing-to-stories/ios-developers>
4. Meta for Developers blog, 2022-10-10, *Introducing an important update to Instagram Sharing to Stories*. <https://developers.facebook.com/blog/post/2022/10/10/introducing-important-update-to-Instagram-sharing-to-stories/>
5. Meta: *Create an app*. <https://developers.facebook.com/docs/development/create-an-app> and *Other app types*. <https://developers.facebook.com/docs/development/create-an-app/other-app-types>
6. Android Developers: *Package visibility, declaring needs*. <https://developer.android.com/training/package-visibility/declaring>
7. react-native-share #1265 (content URL a closed beta, removed from the docs). <https://github.com/react-native-share/react-native-share/issues/1265>
8. appinio_social_share #286 ("instagram api does not support a url anymore"). <https://github.com/appinioGmbH/flutter_packages/issues/286>
9. appinio_social_share #332 (attributionURL not working, 2025). <https://github.com/appinioGmbH/flutter_packages/issues/332>
10. TechCrunch, 2021-08-23, Instagram replaces swipe-up with link stickers. <https://techcrunch.com/2021/08/23/instagram-is-ditching-swipe-up-links-in-favor-of-stickers/>
11. social_share_kit README ("Neither composer accepts pre-filled text"). <https://github.com/wiseminds/social_share_kit>
12. TechCrunch, 2018-05-01, Stories platform: attribution for approved partners. <https://techcrunch.com/2018/05/01/stories-platform/>
13. appinio_social_share #318 (stray link on shared stories). <https://github.com/appinioGmbH/flutter_packages/issues/318>
14. pub.dev: share_plus, appinio_social_share, social_share, social_sharing_plus, social_share_kit (versions and dates from the pub.dev API).
15. Meta blog, 2019-09-23, *Live mode for production use*. <https://developers.facebook.com/blog/post/2019/09/23/live-mode-for-production-use/>
16. Medium, Dec 2024, D. Crompton, *Share content to an Instagram story from an iOS app* (iOS platform registration example). <https://medium.com/@danielcrompton5/share-content-to-an-instagram-story-from-an-ios-app-d55b1e10e68a>

Repo facts (file paths, production counts, live URLs) were read directly on 2026-10-11:
nook-mobile at `4389e37` (the merge of PR #130, tagged `v1.1.5-rc1`), nook-webapp `feat/cups`
(`bf2bdcf`) and `feat/import-polish` (`ee4f161`), nook-supabase `feat/cups` (local), and the
production database (read-only queries).
