# Public profile · UX research (2026-10-05)

A person's profile as other people see it: avatar, name, @username, counts,
bio, their **Top 3** cafes (rank order, no scores), then Gallery and Reviews.
In the app (`PublicProfilePage`) and on the web (`www.nookph.app/u/<username>`).

Desk research and expert evaluation with partwise (`ux`), run right after the
`build`. The built flows were walked on an Android emulator (API 35,
1080×2400) with the debug fakes (`--dart-define=PUBLIC_PROFILE_DEMO=true
--dart-define=GALLERY_DEMO=photos`) and on the web dev server with
`NOOK_FAKE_PUBLIC_PROFILE=1`, at 390 and 1440 wide. `get_public_profile` is not
in production yet, so every visitor profile on screen was fake data; nothing
was written to production. Steps not walked on screen are marked as read from
the code.

Not user research: nothing here says what users felt or did. **Analytics:**
the feature is new, so there is no funnel. Events to add are at the end.

Screens are in [public-profile/](public-profile/). Sheets of other products
(`ref-*.png`) are gitignored and stay on the machine that made them.

## Question

**How does someone get to another person's profile and back to a cafe, and
how does an owner know and control what that profile shows?**

- **Product:** social cafe ranking app, like Beli, Letterboxd, Untappd; the
  web page like Letterboxd's and Untappd's public profiles.
- **People:** Cebu regulars on their phone. *When a review makes me curious
  about who wrote it, I want to see where they really go, so I can find my
  next cafe.* The owner: *when I share my profile, I want to know exactly
  what people see, so my ranking stays mine.* A link recipient without the
  app: *when a friend sends me their profile, I want to see their picks
  without installing anything.*
- **Journeys:**
  1. **Visit:** cafe page → review author → profile → a Top 3 cafe (also from
     a crawl crew member, or "@name" in search).
  2. **Own:** profile → see what is private → Preview → Settings switch →
     Share.
  3. **Link (web):** shared `/u/<username>` → picks, photos, reviews → a cafe
     or the app.

## Journeys as built

### 1 · Visit (seen: [built-review-author](public-profile/built-review-author.png), [built-from-review](public-profile/built-from-review.png), [built-search-people](public-profile/built-search-people.png), [built-visitor](public-profile/built-visitor.png))

| # | Step | Score |
|---|---|---|
| 1 | Cafe page → Reviews: the author's avatar and name are one tap target (44pt) | 2 |
| 2 | Profile: header, Top cafes (1/2/3 on the photo), Gallery 9 · Reviews 3 | 1 |
| 3 | Tap a Top 3 card → cafe page | 1 |
| 4 | Back → profile, back → the review | 1 |
| — | Other doors: a crawl crew member row; "@bea" in search lists People | 2 |

Step 1 scores 2: nothing marks the name as a link (Instagram and the Train
flow look the same way, so it is the convention, but it is learned). Score
**5** single-rater (was 7 before the fixes below).

### 2 · Own (seen: [built-owner](public-profile/built-owner.png), [built-settings-off](public-profile/built-settings-off.png), [built-preview-private](public-profile/built-preview-private.png))

| # | Step | Score |
|---|---|---|
| 1 | Profile → Ranked tab opens with "Only you see your ranking. Visitors see your top 3." and **Preview** | 1 |
| 2 | Preview → the visitor view, titled Preview, "What visitors see on your profile" | 1 |
| 3 | Settings → Privacy → "Show my top cafes and gallery on my profile", saves on flip | 1 |
| 4 | Back on the profile the hint now says the top cafes are hidden | 1 |
| 5 | Share (square button beside Edit profile) → system sheet with the web link | 1 |

Score **5**.

### 3 · Link on the web (seen: [built-web-390](public-profile/built-web-390.jpg), [built-web-1440](public-profile/built-web-1440.jpg))

| # | Step | Score |
|---|---|---|
| 1 | Link preview: "Bea's top cafes on Nook", the #1 cafe's photo | 1 |
| 2 | Page: header, Top cafes, Gallery · Reviews jump links (pinned under the bar) | 1 |
| 3 | A card, photo or review cafe → the cafe page | 1 |
| 4 | Get the app: store badges in a band after the reviews | 2 |

Score **5**. States checked: unknown username → real HTTP 404 with
profile-specific copy; switch off → header, a lock line and reviews only;
one ranked cafe → one card at the left; none → no strip.

## How others do it

Refero has no Beli, Letterboxd, Untappd or Strava flows; the closest real
flows were used, and that gap is noted under each.

- **Visit** — Train Fitness: a commenter's name is a link to a plain feed
  profile; Report and Block sit in the profile's ⋯ with a toast. Instagram:
  identity, counts, bio, one wide primary button, then content tabs.
  District: a saved-places list where every card carries enough to choose
  without opening it. **Pattern:** identity first, content below, actions
  confirm in place. **Split:** where moderation lives (⋯ on the profile vs
  nowhere).
- **Own** — komoot: a share icon on the profile opens QR, Copy link and the
  system sheet. Bump: one privacy switch with one line of help, saves on
  flip. Phantom: privacy levels, each with its consequence spelled out, and
  the parent row shows the current value. **Pattern:** one level down,
  native controls, instant save. **Gap:** none of the three offers a "view
  as visitor"; Nook's Preview has no Refero reference.
- **Link** — Trip.com and GoFundMe: identity and proof on top, picks as
  cards that lead to the thing itself, tabs for photos and reviews.
  Revolut: get-the-app as QR or text-me-a-link on desktop. **Gap:** no
  logged-out phone flow with "Open in app" was found.

## Findings

Fixed in this pass unless marked **open**.

1. **Major · code · Visit 2.** A profile is a new place someone can be
   seen, and there was no way to block them from it (Block existed only on a
   review's ⋯). Someone being looked up by a person they want to avoid had
   to find one of that person's reviews first. Train Fitness puts Block in
   the profile's ⋯. **Changed:** ⋯ → "Block @name" for signed-in visitors,
   with the same confirm sheet wording as reviews; on success a toast and the
   profile closes. The server already hides the profile from both sides of a
   block.
2. **Major · seen · Own 1.** The hint promised "Visitors see your top 3"
   to an owner whose Top 3 is empty: the strip is drawn from **Liked it**
   only (RANKING_DESIGN §1.1, positive top-N), and someone with only "It was
   fine" cafes shows no strip. A promise the Preview then breaks costs trust
   in the one place that is about trust. **Changed:** the hint counts Liked it
   cafes: "Visitors see your top 2" with two; with none, "Cafes you mark
   Liked it become the top 3 visitors see."
3. **Moderate · seen · Visit 2 / Link 3.** Reviews on a visitor profile led
   nowhere: a coffee-cup placeholder and a cafe name that did not open the
   cafe, the opposite of District's "every card lets you choose". **Changed:**
   the review's cafe photo (from the RPC) and a tap on photo or name opens
   the cafe, in the app and on the web.
4. **Moderate · seen · Visit 2.** Cafe names in the Top 3 cut to one line
   ("Three Two Br…") at phone width; the name is what the strip is for.
   **Changed:** two lines, app and web.
5. **Moderate · seen · Visit 2.** The visitor's loading skeleton drew an
   Edit profile button that never arrives, so the layout jumped up on load.
   **Changed:** no action row in the visitor skeleton.
6. **Moderate · seen · Link 1.** The web 404 for a profile said "the cafe may
   no longer be listed". **Changed:** "This profile isn't available. The
   link may be wrong, or the account is no longer on Nook."
7. **Moderate · code · Link 4 · open.** There is no "Open in Nook": the app
   registers only `ph.nook.app://login-callback` and no Android App Links or
   iOS Universal Links, so a `/u/` link always opens the browser. The page
   offers store badges instead. Needs `assetlinks.json` and
   `apple-app-site-association` on www.nookph.app plus the intent filter and
   associated-domains entitlement; the app's `/u/:username` route is already
   in place for it.
8. **Minor · inferred · Visit (search) · open.** People search only answers
   "@" plus a handle and the field says "Search cafes", so few will find it.
   Fine while profiles are reached from reviews; revisit if people search
   matters.
9. **Minor · seen · Link 4 · open.** The web's only app prompt is after the
   reviews; on a long profile a phone visitor may never reach it.
10. **Minor · code · Visit 1.** The review author link is invisible until
    tapped (no underline in the app). Left as is: it matches the platform
    convention (Instagram, Train), and the whole row is a 44pt target.

## Recommended flow

1. **Visit:** review author (or crew member, or "@name") → profile → Top 3
   card or a review's cafe → cafe. Block from ⋯ when needed. *(1 and 3
   changed.)* 7 → 5.
2. **Own:** Ranked tab hint, accurate to what visitors get → Preview →
   Settings switch → Share. *(Hint changed.)* 6 → 5.
3. **Link:** preview card → profile → cafe; on phones, later, "Open in
   Nook" once app links exist (finding 7). 6 → 5.

## To test with real people

| Question | Method | Task / prompt | Success |
|---|---|---|---|
| Do people try the reviewer's name to learn more about them? | 5-person task test | "You liked this review. Find out where else this person goes." | 4 of 5 tap the name without help |
| Is "Top 3" read as a ranking, a list of favourites, or ratings? | Five-second test on the profile | "What is this person telling you?" | No one mentions scores or ratings |
| Do owners believe the ranking is private? | 5-person task test on their own profile | "Who can see your ranked list?" | 5 of 5 say only them, before opening Preview |
| Is the Settings wording clear about what stays public? | First-click + follow-up | "Hide your favourite cafes from other people." | Lands on the switch; can say reviews still show |
| Does anyone use @ search? | Analytics (HEART: adoption) | — | Event `people_search` with result count |

Events to add: `profile_view` (source: review, crew, search, link;
is_self), `profile_top_cafe_open` (rank), `profile_share`,
`profile_preview_open`, `profile_highlights_toggled` (on/off),
`profile_block`.
