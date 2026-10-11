# Share a cup to Instagram Story · references (ios)

Direction: the app's own tokens, unchanged: `ReviewTokens` / `ReviewSheetShell`
for the sheet; brand #344E41, sage #A3B18A, Poppins, Lucide icons on the card.
Spec: `docs/features/share_cup_story.md` (the brief; it wins where they differ).
Researched 2026-10-11 with partwise.

The screenshots are other products' and stay out of git (`.gitignore` here).

## Cup story card
The 1080 × 1920 image: the overlay laid straight over the cup's photo, like
the crawl recap (`CrawlShareOverlay`), and a note layout for a cup with no
photo. Built in `lib/features/cups/presentation/share/cup_story_overlay.dart`.

**Primary: the app's crawl recap overlay.** Borrow: Airbuds, Fable. Rejected: Genie, then Binge.

| | Product | Taken |
|---|---|---|
| ![](story-card-binge.png) | [Binge](https://refero.design/screens/d693e31e-c58c-4763-b714-09b0d5eb3a48) | Considered, then replaced by the crawl's full-bleed overlay: the framed photo over its blurred copy |
| ![](story-card-airbuds.png) | [Airbuds](https://refero.design/screens/ac0fa41e-c3d6-4aa0-be87-6a494d097417) | Footer split: wordmark left, URL right |
| ![](story-card-fable.png) | [Fable](https://refero.design/screens/ac3aa703-568f-4337-9217-2fd688e47a0c) | Stars centered above the quoted note (note layout) |

Not in any reference, designed here: Instagram's safe zones (84 / 113 logical),
the stars-only card, the two-line cafe clamp.

## Share sheet
"Share your cup": preview, Instagram Story (or Share image), More…, Copy link,
the cafe's @handle.
Built in `lib/features/cups/presentation/share/cup_share_sheet.dart`.

**Primary: the app's crawl share page** (preview, photo pills, Share, overlay
only). Borrow: Binge, Spoil me. Rejected: Medium.

| | Product | Taken |
|---|---|---|
| ![](share-binge.png) | [Binge](https://refero.design/screens/b689ab5e-da1b-40ef-8309-644ba31fcc1c) | Title and close, the story preview, a full-width Instagram button, secondary actions in a row under it |
| ![](share-spoil.png) | [Spoil me](https://refero.design/screens/54ae7e5e-9cc1-4ad2-8805-c8f3eb226d69) | Pager dots right under the preview; a "value + copy" row (the @handle row, the link banner) |
| ![](share-medium.png) | [Medium](https://refero.design/screens/00fe2ebb-cd4d-4928-8b48-250acfeb7bbb) | Considered, not taken: icon circles with no primary action |

Not in any reference, designed here: Preparing… and photo-failed + Retry on
the preview, the cup-photo pager. No direct Instagram button (no Meta App
ID): the system sheet lists Instagram Stories. Save image is left out: the
system sheet has a save target.
