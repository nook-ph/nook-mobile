# Cafe community photos · references (ios)

Direction: the cafe details tokens (`CafeDetailsTokens`, `CafeSectionTitle`,
`CafeSectionDivider`), Poppins, brand #344E41, and the gallery's viewer,
unchanged. Researched 2026-10-11 with partwise. UX research behind it:
[docs/ux/cafe-community-photos.md](../../ux/cafe-community-photos.md).

The screenshots are other products' and stay out of git (`.gitignore` here).

## Community photos section
Title with count and See all, a strip of portrait tiles, each credited
(avatar + @username) to its poster; skeleton, empty prompt for Been.
Built in `lib/features/cafe_details/presentation/widgets/cafe_community_photos_section.dart`.

**Primary: TikTok.** Borrow: Luma. Rejected: Instagram.

| | Product | Taken |
|---|---|---|
| ![](strip-tiktok.png) | [TikTok](https://refero.design/screens/981fe931-5244-4af8-8c92-2cb9ae2625e9) | Header row with the title on the left and a trailing item, then one row of equal portrait tiles with even gaps |
| ![](strip-luma.png) | [Luma](https://refero.design/screens/f89c4610-ad26-43ca-9fd6-518240b31be3) | A caption block under each portrait tile, the @username as its second line |
| ![](strip-instagram.png) | [Instagram](https://refero.design/screens/2a16c501-ed0c-401e-9c9d-4656f218bf89) | Considered, not taken: photos fused into one band with no per-photo credit |

Not in any reference, designed here: the avatar beside the @username, the
count beside the title, the See all tile ending the strip, the strip running
off the right edge, the skeleton and the empty prompt.

## All community photos
Pushed screen: "Community photos" over the cafe name, two-column grid with
the same credited tiles, paged as it scrolls.
Built in `lib/features/cafe_details/presentation/pages/cafe_photos_page.dart`.

**Primary: Luma.** Borrow: Givingli. Rejected: Cosmos.

| | Product | Taken |
|---|---|---|
| ![](grid-luma.png) | [Luma](https://refero.design/screens/f89c4610-ad26-43ca-9fd6-518240b31be3) | Two columns of tall tiles, a caption block under each, left-aligned to the tile, @username second |
| ![](grid-givingli.png) | [Givingli](https://refero.design/screens/570a6a95-7185-4693-9acb-fd6cea550f31) | Loading skeleton mirrors the grid: two columns of image blocks with short caption bars |
| ![](grid-cosmos.png) | [Cosmos](https://refero.design/screens/4d638654-8d31-4bb6-ac3f-b808fed34dc4) | Considered, not taken: masonry with no per-tile credit |

Not in any reference, designed here: the loading-more footer, the failed
page with Try again, and the end line. The title over the cafe name follows
the app's own Reviews page.

## Photo viewer
The gallery's viewer (`docs/references/coffee-gallery`), with the cafe chip
replaced by a credit chip (avatar + @username ›) on this surface.
Built in `lib/features/gallery/presentation/pages/gallery_viewer_page.dart`.
