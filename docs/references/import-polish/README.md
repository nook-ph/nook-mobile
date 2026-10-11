# Imported cafes: no-photo tile and unverified note · references (ios + web)

Direction: project theme (`CafeDetailsTokens`, the sage/latte palette; webapp
`app/globals.css`). Researched 2026-10-11 with partwise.

**Refero was not available** (its MCP needed a sign-in this session couldn't
complete), so there are no crops here. The scout read public help pages and
product pages instead; anything marked *unverified* is from memory of the
products, not a source. Screenshots, if added later, stay out of git
(`.gitignore` here ignores `*.png`).

## No-photo tile
A cafe with no photo, on every card and thumbnail, and as the details hero.
Built in `lib/core/presentation/widgets/cafe_photo_placeholder.dart` (tile, via
`CafeCardImage`) and `hero_image_slider.dart` (`_NoPhotosHero`). Webapp:
`app/components/cafe/CafePhotoPlaceholder.tsx`, `CafeNoPhotosHero.tsx`.

**Primary: Tripadvisor.** Borrow: Yelp, Google Maps. Rejected: Airbnb.

| Product | Source | Taken |
|---|---|---|
| Tripadvisor | [listing with no photos](https://www.tripadvisor.com/--d27396585.html) | The empty photo area says so in words ("No photos … yet") with an add-photos link beside it, not a stock image |
| Yelp | *unverified* | List thumbnail is a neutral category glyph on a flat tile, same size as a photo, no text |
| Google Maps | [forum thread](https://localsearchforum.com/threads/photos-not-showing-in-knowledge-panel.58423/latest) | The add-photo prompt lives on the place page, not on result cards |
| Airbnb | *unverified* | Considered, not taken: photos are required to publish, so there is no empty state to learn from |

Decisions: same box as a photo so cards don't reflow; a cup on a tint picked
from the cafe's name (five tints) so a shelf of photo-less cafes doesn't read
as one repeated block; "No photo yet" only where there's room (cards), cup
alone on thumbnails; no name or initial in the tile, because every card already
prints the name under it. The details hero is the full band with "No photos
yet" and, for an unclaimed cafe, "Own this café? Add photos" to the claim page.

## Unverified-listing note
Imported cafe nobody has claimed or checked (`get_cafe_listing_status`).
Built in `lib/features/cafe_details/presentation/widgets/cafe_unverified_note.dart`.
Webapp: `app/components/cafe/UnverifiedListingNote.tsx` + `ClaimCafeSection.tsx`.

**Primary: Yelp.** Borrow: Tripadvisor, Google Maps. Rejected: card markers.

| Product | Source | Taken |
|---|---|---|
| Yelp | [Network Solutions help](https://www.networksolutions.com/help/article/how-do-i-claim-my-yelp-page), [BrightLocal](https://www.brightlocal.com/learn/how-to-add-or-claim-a-yelp-business-listing/) | "Unclaimed" sits right by the business name and explains itself on interaction, leading to the claim flow |
| Tripadvisor | [listing](https://www.tripadvisor.com/--d27396585.html) | Two parts: the status ("This business is unclaimed") and an owner-addressed ask ("Own or manage this property? Claim…") |
| Google Maps | *unverified* | A quiet "Own this business?" link low on the page, kept as the existing claim footer |
| (all) | — | Considered, not taken: a marker on cards. None of the products put claim status on result cards; with most imports unverified it would sit on nearly every row |

Decisions: a hairline pill under the name/status line, "Unverified listing ·
Info from public sources"; tap opens a sheet that explains it and offers "Own
this café? Claim it" (mobile), or jumps to the claim section (web). Nothing on
cards. Hidden while loading, when the RPC isn't deployed, and for claimed or
verified cafes.
