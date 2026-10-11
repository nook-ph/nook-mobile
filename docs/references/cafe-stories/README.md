# Cafe details · Latest cups stories · references (ios)

Direction: project theme (`CafeDetailsTokens` in
`lib/features/cafe_details/presentation/widgets/cafe_details_common.dart`;
the gallery viewer's dark ground for the viewer). Guessed: the seen ring grey
(`#BDBDBD`), the segmented ring.
Researched 2026-10-11 with partwise. Screenshots are gitignored and stay on
the machine that made them.

## Stories tray
The newest community photos at this cafe as one ring per person, newest
first, right under the cafe's header and actions. Unseen and seen rings, an
"Add your cup" slot first for someone who has been, a "See all" link to the grid.
Built in `lib/features/cafe_details/presentation/widgets/cafe_community_photos_section.dart`.

**Primary: Instagram.** Borrow: Google Maps (Nearby photos). Rejected: Google Maps (Latest).

| | Product | Taken |
|---|---|---|
| ![](tray-instagram.png) | [Instagram](https://refero.design/screens/7893d4b6-ce6d-4c77-9fab-fc4b92e7f7f5) | One circular slot per person, a ring, and a one-line name under it. Your own slot comes first with a plus. The row runs off the right edge |
| ![](tray-gmaps-nearby.png) | [Google Maps](https://refero.design/screens/8d3aad69-db92-4dff-a41d-dc4701eb55bf) | Title on the left and an action on the right, above the row. Each photo shows its age |
| ![](tray-gmaps-latest.png) | [Google Maps](https://refero.design/screens/25c6cfe6-0d10-4d22-bc48-4c1d641e08f9) | Considered, not taken: category tiles and a masonry grid, which is not a per-person tray |

Not from a reference: the ring holds the person's newest cup rather than
their face, with their avatar as a badge (most Nook profiles have no photo,
and the cup is the point); the ring is split into one arc per cup.

## Story viewer
Full screen, one person at a time. Segment bars, then who posted and how long
ago with "…" and close, then the photo, then the drink with the review's stars
and words. Auto-advance with hold to pause, tap zones, swipe between people,
swipe down to close.
Built in `lib/features/gallery/presentation/stories/cafe_story_viewer_page.dart`.

**Primary: TikTok.** Borrow: Telegram, Feels. Rejected: Google Maps photo viewer, WhatsApp.

| | Product | Taken |
|---|---|---|
| ![](viewer-tiktok.png) | [TikTok](https://refero.design/screens/b9591f63-051a-46c7-b8f3-e8c03f65d554) | Segment bars above a header row with avatar, name, time and the trailing actions. The photo is inset, with its words under it |
| ![](viewer-feels.png) | [Feels](https://refero.design/screens/a2697d68-0ccd-45f7-9daf-c077cf613319) | Large text anchored bottom-left: here, the drink name, then stars and the note |
| ![](viewer-telegram.png) | [Telegram](https://refero.design/screens/a82787f8-2b62-4ead-83b7-5ef602bffb97) | Your own post replaces the name ("You"). A "…" button sits beside close |

No reference showed the failed-image, long-note or held states. Holding fades
the header and words out. A long note shows three lines and opens on a tap.
A photo that fails to load shows the gallery's broken-image placeholder and
still takes its turn.
