# Cafe community photos · UX research (2026-10-11)

Gallery photos other people added for a cafe, shown on its details page and
credited to who added them.

Desk research and expert evaluation with partwise (`ux`): the details page
walked on an Android emulator (Pixel 7, API 35, 1080×2400) signed in, on
Hom Cafe (3 gallery photos) and Three Two Brew (Been, no photos), compared
with real flows from Refero. Nothing was written to production: the add
flow was opened and closed without picking a photo.

Not user research: nothing here says what users felt or did. **Analytics:**
no funnel exists for this journey because the surface did not exist. The
events added with it (`cafe_photos_viewed`, `cafe_photo_opened`,
`cafe_photo_author_tapped`, `cafe_photos_see_all_tapped`,
`cafe_photo_add_tapped`) are the funnel from now on.

Sheets are in [cafe-community-photos/](cafe-community-photos/). Sheets of
other products (`ref-*.png`) are gitignored and stay on the machine that
made them.

## Question

**How should someone deciding on a cafe see the photos other Nook users took
there, and get from a photo to the person who took it?**

- **Product:** cafe discovery and ranking app; for this journey, like Google
  Maps and Yelp place photos, Instagram and TikTok place pages, Apple Maps
  place cards.
- **People:** a coffee drinker in Cebu, on their phone, choosing where to go
  (signed in or a guest). *When I'm looking at a cafe, I want to see what
  people actually got there, so I can tell whether it's for me, and whose
  taste to trust.*
- **Journey:** cafe details → community photos → a photo full screen (or
  "See all") → the poster's profile.
- **Evidence:** the app on the emulator; `user_photos` and its RLS policies
  (read only); Refero flows. At the time, 19 photos across 9 cafes by 5
  people: most cafes have none.

## Journey today

Sheet: [cafe-community-photos/today.png](cafe-community-photos/today.png).

| # | Step | Score |
|---|---|---|
| 1 | Cafe details: hero photos are the cafe's own listing photos (Hom Cafe: 1) | 1 |
| 2 | Scroll past Hours & location to Reviews; a review author's name has a chevron | 2 |
| 3 | Tap the author → their profile → Gallery tab: every cafe they shot, not this one | 3 |
| 4 | Find this cafe's photos among theirs, by recognising them | 3 |

Single-rater total: **9**. Only works when the photographer also wrote a
review here. Hom Cafe has 3 gallery photos that appear nowhere on its page.

Cognitive walkthrough: step 2 fails "will they try to do the right thing"
(nothing says photos exist); step 4 fails "will they see that it worked"
(no filter by cafe).

States: loading, empty and error do not apply; there is no surface.

## How others do it

Refero has no captured flow for Google Maps, Yelp, Beli or Swarm photo
galleries; these three are the nearest.

- **Instagram, Locations** (flow 2862): the place sheet holds a photo strip
  with a Top / Recent toggle and a post count; each photo opens as a post
  with its author on top.
- **TikTok, place page** (flow 2784): the place page *is* a grid of posts
  under a "N posts" count; no strip, no See all step.
- **Apple Maps place card** (flow 11981): a horizontal photo carousel near
  the top, each photo badged with its source (Foursquare); credit is to a
  provider, so the trail to a person ends in a hand-off to another site.

**Pattern:** photos sit on the place screen itself, with a count, and the
thumbnail is the way in. **Split:** a strip with See all (Instagram, Apple)
versus the whole page as a grid (TikTok); credit to a person (Instagram,
TikTok) versus a source (Apple).

## Findings

Ranked by severity, then evidence.

**1 · Major · seen · step 1 · Community photos exist but are invisible on
the cafe.** Hom Cafe has 3 photos; its page shows none. Cost: the most
decision-useful content (what people ordered, what it looks like inside) is
missing exactly where the decision is made. Reference: all three put photos
on the place screen. **Change:** a "Community photos" section on details: a
strip, count in the title, See all.

**2 · Major · seen · steps 2–4 · The only path to a poster runs through a
review, and lands on all their photos.** Cost: three screens and a search
by eye; impossible when they did not review. Reference: Instagram and
TikTok put the author on the photo. **Change:** credit every tile (avatar +
@username) and the full-screen photo; the credit opens their profile.

**3 · Moderate · inferred · empty state · Most cafes have no photos; an
empty box on every page reads as a dead feature.** Hiding it everywhere
leaves no way to seed it. **Change:** hide the section when empty, except
for someone who has marked the cafe Been: they have something to add, and
get "No photos yet · Be the first to add one from your visit · Add a photo",
which opens the existing add flow (camera or library → add sheet, cafe
fixed). Guests and non-Been see nothing.

**4 · Moderate · inferred · strip vs grid · The strip should not try to be
the whole gallery.** Loading everything for a strip costs data on every
details view. **Change:** strip loads 8 (count from the same query); See all
(header, and a final tile when there are more than 8) opens a two-column
grid that pages 24 at a time.

**5 · Minor · inferred · viewer · The gallery viewer's cafe chip would
reopen the page you are on.** **Change:** on this surface the chip is the
credit instead; signed-in visitors keep "…" → Report (UGC rule), not on
their own photo.

**6 · Minor · code · own photos.** Your own visible photos are part of the
cafe's photos; credited "You" and not a link (as your own review is).

Trust and safety, from the RLS read (`code`): hidden and moderated photos,
private galleries, photos of hidden reviews and blocked people (either way)
never reach the client, for guests too. Suspended authors are filtered on
the client (see "To test").

## Recommended flow

| # | Step | Score |
|---|---|---|
| 1 | Cafe details, below Reviews: "Community photos 3 · See all ›", a strip of photos, each with what/when and avatar + @username | 1 |
| 2 | Tap a photo → full screen, swipe in strip order, credit chip under it | 1 |
| 3 | Tap the credit (on the tile or the chip) → their profile | 1 |
| 3b | Or See all → two-column grid, paging as it scrolls → same as 2–3 | 1 |

Single-rater total: **3** (from 9). Changed: steps 1–3 are new; the review
detour is gone. Placement below Reviews keeps the photos with the other
things people said, and leaves the top of the page to the cafe's own facts.

## To test with real people

| Question | Method | Task or prompt | Success |
|---|---|---|---|
| Do people find the photos without being told? | 5-person task test | "You're deciding whether to go to Hom Cafe. Show me what people have ordered there." | 4 of 5 reach the strip without help |
| Is the credit read as a link? | First-click test | On the strip: "Who took the latte photo? Look at their other cafes." | First click on the caption or credit chip |
| Below Reviews, or higher? | 5-person task test, two builds | Same task, section above vs below Reviews | Time to first photo tap; no one scrolls past it |
| Does the Been-only empty prompt get photos? | Analytics (HEART: adoption) | — | `cafe_photo_add_tapped` / `view_details` on Been cafes with no photos; `gallery_photos_added` with source `gallery` after it |
| Is the strip used? | Analytics (HEART: engagement) | — | `cafe_photo_opened` and `cafe_photo_author_tapped` per `cafe_photos_viewed` |
