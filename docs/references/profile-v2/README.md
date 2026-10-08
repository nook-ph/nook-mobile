# Profile v2 · references (iOS)

Direction: TikTok's centred header with Instagram's grid, chosen 2026-10-08
with partwise. Figma: file `Wwx7TRYrLwRJygL8xouBfg`, page "Redesign",
section "Profile — redesign v2 (TikTok header + Instagram grid)"; the
reference sheets and crops are in the section "Profile — fresh direction"
beside it.

Brand kept: Poppins, `#344E41`, Lucide, the app tab bar. New token:
`ProfileTokens.fill` (`#F1F0EC`) for the header buttons, derived from the
avatar fill.

## Whole page
**Primary: TikTok profile** (centred avatar and handle, three-number stat
row, button row) and **Instagram profile** (3-column grid, 4:5 tiles since
2025). Considered: Gowalla (list-led), not taken because it hides photos
behind rows.
- [TikTok](https://refero.design/screens/9d54f8a6-732a-4ff7-925a-7057bc81229b)
- [Instagram](https://refero.design/screens/3c7cc641-e401-479f-addc-49317d68bf9e)

A Top 3 strip was designed and then removed on request: it pushed the grid
off the first screen.

## Photo viewer and note
**Primary: Luma AI**, caption docked at the bottom. Borrow: Substack (close
and "…" as separate round buttons), Pinterest ("…" opens a plain action
sheet), HYPE (drink over a dimmer note), PayPal (n/limit counter inside the
field). No reference showed a two-line clamp with "more"; it follows
Instagram's convention.
- [Luma AI](https://refero.design/screens/939c126d-6c15-43dc-82ef-e298ba645435)
- [Substack](https://refero.design/screens/7fb66d42-6553-4a82-9bad-49f6a1e677b0)
- [Pinterest](https://refero.design/screens/2585f44d-c48a-4196-b969-92324501617a)
- [HYPE](https://refero.design/screens/32487331-0264-4b11-b292-d60c99a25df0)
- [PayPal](https://refero.design/screens/0cba43c5-c0dd-43fd-9b28-74f12c9a63bd)

## Pre-launch UI fixes (2026-10-08)
Researched in `launch-review/profile-ux.md` (Refero flows saved under
`launch-review/profile-shots/ref/`, not committed); built against Figma
"Profile — redesign v2" (1775:5261). No new scouting: each part reuses
those flows and the Figma frame that covers it.

- **Visitor ⋯ sheet and reports** (`public_profile_page.dart`,
  `review_actions_sheet.dart` `ReportReasonSheet`). Figma B2 plus Report.
  Spotify (flows/213): Share, Report and Block in one sheet. TikTok
  (flows/2760): a reason for the account itself. Instagram (flows/2846):
  reason first, nothing sent until Submit. Not taken: Instagram's
  sub-reasons and "Also block?" step.
- **Uploading tiles** (`profile_gallery_tab.dart` `GalleryUploadTile`).
  Figma E2. Savee (flows/5275): the picked photo waits in the grid as a tile
  instead of a modal.
- **Review photo in the viewer** (`gallery_viewer_page.dart`). Figma G5:
  review text in place of the note, View review beside the cafe chip.
- **Edit sheet** (`gallery_photo_options.dart`). Figma G6: Save off until
  something changes, public-note line. Change cafe reuses the add sheet's
  cafe row.
- **Own Share sheet** (`profile_pagev2.dart`). komoot (flows/8368): share
  says what the link opens; here as See what visitors see.
