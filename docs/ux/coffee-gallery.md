# Coffee gallery · UX research (2026-10-05)

A public coffee gallery on the profile: every photo belongs to a cafe.

Desk research and expert evaluation with partwise (`ux`): the profile walked on
an Android emulator (API 35, 1080×2400) signed in as the owner's own account,
the Been → rank flow and the upload code read in the source, and compared with
real flows from Refero. Nothing was submitted to production: no Been mark, no
ranking, no upload. Steps past the profile screen are from the code.

Not user research: nothing here says what users felt or did. **Analytics:**
the gallery is new, so there is no funnel. Ranking sends `rank_completed`
(`docs/ranking_analytics.md`), which is the denominator for the rank-flow
photo prompt once it ships.

Contact sheets are in [coffee-gallery/](coffee-gallery/). Sheets of other
products (`ref-*.png`) are gitignored and stay on the machine that made them.

## Question

**How should a person build a coffee gallery on their profile with almost no
extra work, and how should it show who they are to someone visiting?**

- **Product:** social cafe ranking and discovery app, like Beli, Untappd,
  Letterboxd; for the gallery itself, like Instagram's grid and Google Maps'
  Local Guide photos.
- **People:** signed-in regulars in Cebu, on their phone. *When I've had a
  good cup, I want to keep a photo of it with the cafe, so my profile shows
  what I drink and where.* And a visitor: *when I look at someone's profile, I
  want to see what they actually order, so I know whether to trust their
  taste.*
- **Journeys:**
  1. Add a photo at the end of Been → rank (cafe known).
  2. Browse the gallery: profile → Gallery tab → photo → cafe; owner pins,
     hides, deletes.
  3. Add past photos: + on the Gallery tab → pick photo(s) → pick the cafe →
     save.
  Review photos reaching the gallery is a data rule, not a journey; it is
  covered under journey 2.

## Journeys today

There is no gallery. What exists around it:

### 1 · Been → rank, ending (code: `cafe_ranking_flow.dart`)

| # | Step | Score |
|---|---|---|
| 1 | Mark Been → "How was <cafe>?" three buckets, Skip for now | 1 |
| 2 | "Which did you like more?" 1–4 comparisons | 1 |
| 3 | Reveal: score, "#3 of 5 · Been", **View my list** (filled), **Add a note** (outlined), Done | 1 |
| 4 | Skip at step 1 → toast "Added to Been · Add a note" | 1 |

No photo anywhere in it. The reveal already carries two calls to action and a
Done; it is the peak of the loop (`RANKING_DESIGN.md` §3.1).

### 2 · Profile (sheet: [coffee-gallery/profile-today.png](coffee-gallery/profile-today.png))

| # | Step | Score |
|---|---|---|
| 1 | Profile tab: @handle, avatar, "5 ranked · 0 reviews · 4 lists", Edit profile | 1 |
| 2 | Tabs **Ranked 5 · Reviews 0 · Lists 4**, Ranked first: Your #1, Liked it / It was fine bands, Re-rank per row | 1 |

Photos exist only inside reviews (`reviews.image_urls`, up to 3, public-read
on DigitalOcean Spaces). The profile shows none of them. There is no
other-person profile screen in the app yet.

### 3 · Uploading a photo (code: `write_review_sheet.dart`, `core/upload/`)

`image_picker` → `flutter_image_compress` (re-encodes, drops EXIF) → presign
from `review-images-presign` (`uploadType: review_image | avatar`) → PUT to
Spaces with `public-read`. Every uploaded object is public to anyone with the
URL.

## How others do it

### Journey 1 · photo after logging (sheets `ref-rankphoto-1..3.png`)

No Refero flow shows a "add a photo?" step after a log or rating; these are
the nearest.

- **Train Fitness** (flow 7163): the finished, already-saved workout shows an
  **Add Photo** button; action sheet Take Photo / Camera Roll; upload spinner
  in place; the photo becomes the post's hero.
- **komoot** (flow 8407): photos are one section of the activity's edit form,
  library only, multi-select, first one becomes the cover; saved with the
  form.
- **one year** (flow 10993): a small image icon in the composer; permission
  prompt; single-image picker; saved with the entry.

**Pattern:** the photo is optional, one tap away, attached to something
already saved, and never a gate. **Split:** after the save as its own button
(Train) versus inside the composer (komoot, one year).

### Journey 2 · browse and manage (sheets `ref-browse-1..3.png`, plus screens)

- **Google Maps Local Guide profile** (screen 34662492): a "Photos" block
  on the profile; each tile carries the **place name and "a month ago"** over
  a dark scrim; "See all photos". Its photo viewer (screen 3d38040c) puts
  **the place name and age in a sheet under the photo**, with nearby photos.
- **Pinterest** (flow 2503): grid with a per-card "…" menu; viewer shows
  author and time, not a place.
- **Tinder** (flow 3441): owner edits in a separate mode; slot order is
  prominence (first slot leads); Delete / Replace sheet, no confirm.
- **Apple Image Playground** (flow 12805): long-press a tile → menu, Delete
  last and red → confirm that says exactly what is lost.

Also from product knowledge, not Refero: Instagram caps pinned posts at
**three**, shows them first in the same grid with a pin glyph, and puts Pin /
Archive / Delete in the post's "…" menu; Archive is its "hide from profile,
keep for me".

**Pattern:** actions live on the photo (menu on the tile or in the viewer),
Delete last, the grid updates in place. **Split:** confirm before delete
(Apple yes, Tinder no); text on tiles (Google Maps yes, Instagram no).

### Journey 3 · add past photos and tag the place (sheets `ref-upload-1..3.png`)

- **Instagram** (flows 2866, 3625): + → picker with multi-select (numbered
  badges) → edit → composer with **suggested location chips** under "Add
  location"; the full picker is a search field over a GPS-distance list.
  **One location for the whole carousel.**
- **ABY Journal** (flow 7992): resolves the current place first and shows it;
  the person only acts if it is wrong ("Change location"); search as
  fallback; saved on selection.
- **Tripsy** (flow 2346): place-first: photos are added from the place's
  page, so there is no place step; a title prompt per photo.

**Pattern:** OS photo picker first, place as a separate step with search,
chosen place shown back as a removable row or chip. **Split:** where the
default comes from (GPS list, current location, or the page you are on).
None used recent places or photo EXIF, and none asked for a place per photo.

## Findings

Ranked by severity, then evidence.

**1 · Major · code · upload · Uploads are public-read, so original EXIF
would publish where people live.** The gallery reads EXIF for the date and a
cafe suggestion. If a file went up unprocessed, its GPS would be readable by
anyone with the URL, and gallery photos are often taken at home or work as
well as at cafes. Cost: a privacy leak nobody can see happening. Reference:
none of the three shows it, which is the point: it has to be invisible.
**Change:** read EXIF on the device, then always re-encode (the existing
compressor drops EXIF) before upload. Never send coordinates to the server;
only the matched cafe id.

**2 · Major · inferred · rank flow · A sixth step after the reveal costs the
peak.** The brief proposed a final step "Add a photo of what you had?" with
Camera / Gallery / Skip. The reveal is the reward moment; a further screen
asking for more work after it means every ranker meets one more decision to
dismiss (peak-end rule), and the reveal already has three exits. Reference:
Train, the closest flow, puts **Add Photo on the already-saved result**, not
after it. **Change:** no new step. Put an "Add a photo of what you had" tile
on the reveal itself, under the score; it opens Camera / Choose from library;
Done stays the skip. The photo is then confirmed on a small sheet with the
cafe already set. *This refines the brief.*

**3 · Major · code · profile tabs · Four tabs do not fit.** `ProfileTabs` is a
fixed `Row` with 24 pt gaps and a count pill on each tab. Ranked, Reviews,
Lists and Gallery with counts come to about 380 pt; a 360 pt phone has 320
after the gutters, and the 411 pt emulator about 371. The last tab would be
cut off or overflow. Cost: the new tab is the one people would not see.
**Change:** tighter gaps and let the row scroll sideways when it still does
not fit; check at 360 pt and at large text.

**4 · Major · code + spec · public profile · Ranked is first but must stay
private.** `RANKING_DESIGN.md` §1.1: rankings are private, "not a profile
anyone can look up". The profile puts Ranked first because "it says the most
about the person once profiles are public" (core-loops finding 3). When
profiles go public, Ranked cannot be the first thing a visitor sees; the
gallery is the public-safe showcase. **Change:** place Gallery second for the
owner now (beside their own ranking), and make it the first tab a visitor
sees when the public profile ships. Product decision for the user; flagged,
not decided here.

**5 · Moderate · inferred · grid · A photo with no cafe on it says little to
a visitor.** Google Maps labels every tile with the place and age; Instagram
labels nothing. At three columns on a 360 pt phone a tile is about 112 pt,
which fits one line of 11 pt text but turns the grid into a list of names.
**Change:** keep tiles clean (the showcase is the photos), say the totals in
a header line ("42 cups · 18 cafés"), and put the cafe on the viewer as a
chip that opens the cafe page. Test whether visitors want the names on tiles.

**6 · Moderate · inferred · cafe picker · Six sources would be overload.**
The brief lists Been cafes, nearby, EXIF match, and search is needed too.
Shown as equal lists, that is four sections of up to dozens of rows (Hick's
law). Reference: Instagram leads with a few suggestion chips and keeps the
long list behind search; ABY leads with one resolved answer. **Change:** one
sheet: search field on top; then **one** "Taken here?" suggestion when EXIF
location matches a cafe within about 150 m; then "Your Been cafes" (most
recent first, max 6); then "Nearby" (max 6, only with location permission);
search covers the rest. One cafe applies to the whole batch, as on
Instagram.

**7 · Moderate · inferred · review photos · Deleting a review photo from the
gallery would silently edit a public review.** **Change:** review photos are
in the gallery automatically, can be pinned or hidden there, but not
deleted; their menu says "Part of your review" and opens it instead. Deleting
the review (or the photo in the review) removes it from the gallery.

**8 · Moderate · inferred · hide vs delete · Two near-identical actions need
words.** **Change:** "Hide from profile — only you can see it" and "Delete
photo" (last, red, with a confirm that says it cannot be undone). Hidden
photos stay in the owner's grid, dimmed with an eye-off mark, so they are not
lost (Instagram's Archive solves the same need with a separate place, which
is one more screen to find).

**9 · Moderate · inferred · empty state · An empty grid on a public profile
reads as "nothing here".** **Change:** for the owner, a message with the
reason ("Your coffee, cup by cup") and one action, **Add photos**, plus the
hint that review photos and the rank flow add to it automatically. For a
visitor (later), no call to action, just "No cups yet".

**10 · Minor · inferred · drink name · Asking for it on every photo slows
the batch.** **Change:** an optional field "What did you have?" on the
confirm sheet, marked optional; editable later from the viewer. In a batch,
one field applies to all, left blank by default.

**11 · Minor · inferred · date · "Uploaded today" is wrong for past photos.**
**Change:** use EXIF DateTimeOriginal when present, else the upload time; the
viewer shows the month and year ("March 2026"), which is honest for both.

**12 · Minor · inferred · Android photo picker · EXIF GPS is often missing.**
Android's photo picker redacts location unless the app holds
`ACCESS_MEDIA_LOCATION`, and iOS's limited library may too. **Change:** treat
the EXIF match as a bonus, never a requirement; the picker must work well
without it.

## Recommended flow

### 1 · Been → rank → photo

| # | Step | Before | After |
|---|---|---|---|
| 1–2 | Bucket, compare (unchanged) | 2 | 2 |
| 3 | Reveal: score, **"Add a photo of what you had" tile (new)**, View my list, Add a note, Done | 1 | 1 |
| 4 | Tile → Take photo / Choose from library (system sheet) | — | 1 |
| 5 | Confirm sheet: the photo, cafe already set (not editable), "What did you have? (optional)", Save · toast "Added to your gallery" with View | — | 1 |

The photo is optional at every step; skipping costs nothing (Done as today).
Single-rater: 3 → 5 for the longer path, 3 unchanged for anyone who skips.

### 2 · Browse and manage

| # | Step | Score |
|---|---|---|
| 1 | Profile → **Gallery** tab (second), header "42 cups · 18 cafés", + button | 1 |
| 2 | 3-column grid, pinned (up to 3) first with a pin mark, then newest first; hidden ones dimmed for the owner | 1 |
| 3 | Tap → full-screen viewer, swipe between photos; cafe chip, drink, month; "…" for the owner | 1 |
| 4 | Cafe chip → cafe page | 1 |
| 5 | "…" (or long-press a tile): Pin to top / Unpin · Hide from profile / Show on profile · Delete photo (red, confirm). Review photos: Open review instead of Delete | 1 |

### 3 · Add past photos

| # | Step | Score |
|---|---|---|
| 1 | + on the Gallery tab (or Add photos on the empty state) | 1 |
| 2 | System picker, multi-select up to 10 | 1 |
| 3 | "Which café?" sheet: search, "Taken here?" (EXIF), Your Been cafes, Nearby | 2 |
| 4 | Confirm sheet: thumbnails, the cafe as a removable row, "What did you have? (optional)", Save | 1 |
| 5 | Grid updates in place; toast "3 photos added" | 1 |

## Data needs (for the build)

- One table of gallery photos, each with a required cafe, so a future "From
  the community" on cafe pages is a query, not a migration.
- Review photos materialised into it (source `review`, linked to the review)
  so pin and hide work on them like any other photo.
- Visibility: anyone can read a photo that is not hidden, its review (if
  any) is visible, and its author has not blocked or been blocked by the
  viewer, as with reviews today. The owner reads all of theirs.

## To test with real people

| Question | Method | Task or prompt | Success |
|---|---|---|---|
| Do people add a photo on the reveal, or ignore the tile? | Analytics | goal: gallery grows from ranking · signal: photo saved after `rank_completed` · events `gallery_photo_prompt_tapped`, `gallery_photo_added {source}` | ≥15% of rank completions add a photo in the first month |
| Do visitors want cafe names on grid tiles? | 5-person task test | "Find which cafe this person goes to most for iced drinks." | 4 of 5 answer without opening more than 3 photos |
| Is "Hide from profile" understood as different from delete? | First-click + interview | "You don't want strangers to see this photo, but want to keep it." | 4 of 5 pick Hide, and say it stays for them |
| Can people find the right cafe for an old photo? | 5-person task test | Give a photo from a known cafe without location data: "Add this to your gallery." | 5 of 5 finish; median under 20 s |
| Does a gallery make a profile more trustworthy? | Five-second test | Show a profile with a gallery and one without | Visitors describe the person's taste from the gallery one |

---

# Second pass · the built flow (2026-10-05)

The same three journeys, walked again on what was built on
`feat/coffee-gallery`. Evidence:

- **Seen on the emulator** (API 35, 1080×2400, about 411 pt wide), signed in
  as the owner, in a debug build with `--dart-define=GALLERY_DEMO=photos`
  and then `=empty`. The demo swaps in an in-memory repository: real cafes
  are read (Been list, nearby, search), nothing is written, nothing is
  uploaded. Two generated test images were pushed to the emulator's own
  library to pick from. Sheets:
  [built-gallery.png](coffee-gallery/built-gallery.png) (empty, grid,
  viewer, options) and [built-add.png](coffee-gallery/built-add.png)
  (system picker, "Which cafe?", add sheet, saving, result).
- **Rendered off-device**: the ranking reveal cannot be reached on the
  emulator without writing a real ranking to production, so it was pumped
  in a throwaway widget test with the app's Poppins loaded and saved as
  images ([built-reveal.png](coffee-gallery/built-reveal.png)). Icons draw
  as boxes there because the icon font is not loaded in tests; the layout
  and text are real.
- **Not seen**: the reveal on a device; the cafe page opened from the
  viewer chip (tested, not looked at); a visitor's view (no other-person
  profile exists yet); iOS; 360 pt phones; large text.

Partway through the walk the app on the emulator was reinstalled by
another process (12:03:12, `installPackageLI`), and a ranking for "The
Spring" appeared on the same account at 12:00:31 while this pass was on the
gallery's add sheet. Neither came from this work. The walk stopped there
rather than reinstall over someone else's build, so the viewer caption fix
below was not looked at on the device.

## Journeys as built, scored (single-rater)

| Journey | Steps | Before (pass 1, as recommended) | Built |
|---|---|---|---|
| 1 · Rank → photo | Reveal tile → Take / Choose → add sheet (cafe fixed, drink optional) → Add photo → tile turns into "Added to your gallery" | 5 | 5 (1+1+1+1+1); 3 for anyone who skips, as before |
| 2 · Browse and manage | Gallery tab → grid → viewer → chip → cafe; long-press or "…" for Pin / Drink / Hide / Delete | 5 | 5 |
| 3 · Add past photos | Add → system picker → "Which cafe?" → add sheet → toast, grid updates | 6 | 6 (the cafe step stays a 2: 12 rows plus search) |

## Pass-1 findings, now

| # | Finding | Status | Evidence |
|---|---|---|---|
| 1 | EXIF GPS would go public | **Addressed.** EXIF is read on the phone, then the photo is re-encoded (EXIF dropped) before the presign upload; only the cafe id leaves the phone. Still to check once deployed: download an uploaded object and confirm it has no GPS. | code |
| 2 | An extra step after the reveal | **Improved.** No new step: a quiet row under the score, "Add a photo of what you had · Optional · it goes on your profile", below it the unchanged View my list / Add a note / Done. After adding, the same row says "Added to your gallery". | rendered, tests |
| 3 | Four tabs do not fit | **Improved.** All four fit at 411 pt with counts (Ranked 5 · Gallery 11 · Reviews 0 · Lists 4); gaps went from 24 to 20 and the row scrolls sideways when it does not fit. At 360 pt or large text, Lists will sit partly off-screen behind a scroll with no cue. | seen at 411; code for 360 |
| 4 | Ranked first but private | **Open, needs a decision.** Gallery is the second tab. When public profiles ship, visitors must not get Ranked, and Gallery should lead for them. | spec |
| 5 | Cafe names on tiles | **As recommended:** clean tiles, cafe on the viewer chip, totals in the header ("11 cups · 11 cafes · 1 hidden"). Still to test with visitors. | seen |
| 6 | Picker overload | **Improved.** One sheet: search, then "Taken here?" (only when matched), "Your Been cafes" (max 6) and "Nearby" (max 6, not repeating Been). On the device: 6 Been rows plus Nearby, readable but long. "Use my location" when location is off (tested). | seen, tests |
| 7 | Review photos and delete | **Addressed.** Their menu has no Delete; "Part of your review" opens Your reviews. It opens the list, not that review: minor. | tests |
| 8 | Hide vs delete | **Addressed.** "Hide from profile: Only you will see it. You can show it again any time." Hidden tiles are dimmed with an eye-off mark; Delete is last, red, with a confirm. Hiding unpins. | seen, tests |
| 9 | Empty state | **Addressed.** Three dashed slots (the first a +), "Your coffee, cup by cup", what fills it, Add photos. | seen |
| 10 | Drink name | **Addressed, with a fix after this pass**: beside the single-photo thumbnail the label "What did you have? (optional)" was cut to "What did you have? (optio…" at 390 pt. Now "Drink (optional)"; the edit sheet keeps "What did you have?" as its title. | rendered |
| 11 | Date | **Addressed.** EXIF capture time when present, else now; the viewer shows the month ("August 2026"). | seen |
| 12 | EXIF location often missing | **Worse than assumed on Android.** The manifest has no `ACCESS_MEDIA_LOCATION`, so Android redacts GPS from every picked photo and "Taken here?" will not appear on Android at all. Adding the permission is not enough with the system photo picker, which strips location regardless. On iOS it depends on the picker returning full metadata (not verified). The picker stays usable without it, which was the design. | code |

## New findings

**N1 · Moderate · seen · viewer · The caption was centred.** The drink,
cafe chip and month sat centred under the photo instead of on the left
edge. Fixed in the build (the column now stretches); covered by tests, not
looked at again on the device (see above).

**N2 · Moderate · inferred · + flow · New photos can land out of sight.**
Photos are placed by when they were taken. Adding an old photo puts it
deep in the grid, so after "3 photos added" the person may see nothing
change at the top. On the device the test images had no EXIF, so they
landed at the top. **Change:** after adding, scroll to and briefly mark the
first new photo, or open it in the viewer.

**N3 · Moderate · code · iOS · No photo-library usage string.**
`Info.plist` has `NSCameraUsageDescription` but no
`NSPhotoLibraryUsageDescription`. The review sheet already picks from the
library with the same `image_picker` defaults (full metadata on), so it is
probably fine with the system picker, and the gallery needs that metadata
to read EXIF. Check on an iOS device before release; if it prompts, add the string ("Nook adds the photos you choose to
your coffee gallery").

**N4 · Minor · seen · profile header · The counts line leaves out cups.**
"5 ranked · 0 reviews · 4 lists" sits above a tab that says 11. Either add
"11 cups" to the line or leave the line as the private stats and let the
tab speak. A decision for when the public profile is designed.

**N5 · Minor · seen · demo content.** The demo seeds the grid with cafe
interior photos from the cafes table, so this pass never saw a grid of
actual cups. The signature (a grid of what someone drinks) is untested with
real content. Look again with real uploads after the migration is applied.

## Still to test with real people

Unchanged from pass 1, plus one row:

| Question | Method | Task or prompt | Success |
|---|---|---|---|
| After adding old photos, do people find them? | 5-person task test | "Add these three photos from last month to your gallery, then show me one of them." | 5 of 5 point to a new photo within 5 s |

## What to do next

1. Decide finding 4 (what a visitor sees first, and that Ranked stays
   private) before any public profile work.
2. Apply the migration and deploy the presign change (nook-supabase
   `feat/coffee-gallery`), then repeat this walk without the demo, with
   real uploads, on Android and iOS: check finding 1 on a real object, N3,
   and N5.
3. N2 (scroll to new photos) is the one build change worth doing before
   release.
