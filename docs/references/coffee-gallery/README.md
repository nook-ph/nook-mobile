# Coffee gallery · references (ios)

Direction: the app's profile and lists tokens (`ProfileTokens`,
`ListsTokens`, Poppins, brand #344E41), unchanged. Guessed: the viewer's dark
ground and text colours (`_ViewerTokens`, derived from the profile ink).
Researched 2026-10-05 with partwise. UX research behind it:
[docs/ux/coffee-gallery.md](../../ux/coffee-gallery.md).

The screenshots are other products' and stay out of git (`.gitignore` here).

## Gallery tab
Count line with Add, 3-column grid, up to 3 pinned first, hidden dimmed.
Built in `lib/features/gallery/presentation/widgets/profile_gallery_tab.dart`.

**Primary: TikTok.** Borrow: Tinder, ID by amo.

| | Product | Taken |
|---|---|---|
| ![](grid-tiktok.png) | [TikTok](https://refero.design/screens/9d54f8a6-732a-4ff7-925a-7057bc81229b) | Tight grid, the pinned tile first with a tag in its top-left corner |
| ![](grid-tinder.png) | [Tinder](https://refero.design/screens/649df736-92d4-4ed6-9106-b8b7055308db) | Empty state as dashed slots with a plus |
| ![](grid-id.png) | [ID by amo](https://refero.design/screens/bdd2db86-3ea2-44cf-941b-566cb6d48588) | A small count line above the grid |

## Photo viewer
Full screen, swipe, cafe chip, month, owner "…".
Built in `lib/features/gallery/presentation/pages/gallery_viewer_page.dart`.

**Primary: Luma.** Borrow: Canopi, Dropbox.

| | Product | Taken |
|---|---|---|
| ![](viewer-luma.png) | [Luma](https://refero.design/screens/939c126d-6c15-43dc-82ef-e298ba645435) | Caption panel under the photo: title, then a meta line with place and date |
| ![](viewer-canopi.png) | [Canopi](https://refero.design/screens/2e49b6a9-4f29-4669-8c58-79b3ddbb1714) | Round close and "…" in the top corners, position between them |
| ![](viewer-dropbox.png) | [Dropbox](https://refero.design/screens/093d8b6f-7eae-4a81-81e8-a261abc64bff) | Loading and failed photo as a centred glyph on the dark ground |

## Cafe picker
"Which cafe?": search, "Taken here?", Your Been cafes, Nearby.
Built in `lib/features/gallery/presentation/widgets/cafe_picker_sheet.dart`.

**Primary: Gowalla.** Borrow: Google Maps, Shazam.

| | Product | Taken |
|---|---|---|
| ![](picker-gowalla.png) | [Gowalla](https://refero.design/screens/b7815650-1c76-4e77-9e0f-b8c756ccb6fa) | Rows of thumbnail, name, area |
| ![](picker-googlemaps.png) | [Google Maps](https://refero.design/screens/367f09d0-4866-4480-b9a6-54dd526d3543) | A small label over each group of rows, under the search field (sentence case here) |
| ![](picker-shazam.png) | [Shazam](https://refero.design/screens/0f01544c-6dbc-41ea-967b-27e8b46d09aa) | Search field with a clear button; a location action as the way to turn on Nearby |

## Add sheet
Photos, optional drink, the cafe, Add.
Built in `lib/features/gallery/presentation/widgets/add_gallery_photos_sheet.dart`.

**Primary: Instagram.** Borrow: Buy Me a Coffee. Considered: Monday.

| | Product | Taken |
|---|---|---|
| ![](confirm-instagram.png) | [Instagram](https://refero.design/screens/5135e312-fdb6-4b44-b342-859dc448f3e5) | One thumbnail beside the text field, the place as a chevron row below |
| ![](confirm-buymeacoffee.png) | [Buy Me a Coffee](https://refero.design/screens/1665a53e-3637-42e5-a72d-4a99ec05a7f0) | Several thumbnails in a row with remove badges and a spinner each while uploading; "(optional)" in the field |
| ![](confirm-monday.png) | [Monday](https://refero.design/screens/2c4c8acb-fa95-4c21-b930-ffe48f2db6d4) | Considered, not taken: a list per file is too heavy for 1–10 photos |

## Ranking reveal photo prompt
"Add a photo of what you had", optional, under the score.
Built in `RankPhotoPrompt`,
`lib/features/cafe_details/presentation/widgets/cafe_ranking_flow.dart`.

**Primary: The Body Coach.** Borrow: Airbnb. Considered: CapWords.

| | Product | Taken |
|---|---|---|
| ![](photo-bodycoach.png) | [The Body Coach](https://refero.design/screens/167a5701-9cb9-4e7d-8a93-79ea6ef35ea6) | A camera tile with a short label, opening Take photo / Choose from library (shrunk to a row) |
| ![](photo-airbnb.png) | [Airbnb](https://refero.design/screens/e5c4b2df-bb0c-4adf-a00b-0a1de8268c28) | The added state: the same tile showing the photo with a check |
| ![](photo-capwords.png) | [CapWords](https://refero.design/screens/cfff4b0a-b7fc-4d35-a5a8-6d9f5507acbc) | Considered, not taken: no add affordance |
