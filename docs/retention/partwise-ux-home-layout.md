# Home layout and campaign banner · UX research (2026-10-16)

Job: partwise **ux**. This is desk research plus an expert walkthrough of branch
`retention/home-layout` at `7f07ef1`. It is not user research; nothing here reports what a user
said or did. The journey "as it is" comes from the review screenshots in
`review-shots-home-layout/` (Android emulator, guest with 3 on-phone saves, GPS Cebu, layout
fixture on and off). Companion docs: `partwise-review-home-layout.md` (the review) and
`nook-supabase/docs/HOME_LAYOUT.md` (the contract). Refero contact sheets are kept locally in
`/tmp/ux-home-layout/` and are not committed.

## Question

**When someone opens Home, do the admin-curated shelves and the campaign banner get them to a
cafe worth tapping, and does a banner tap land somewhere that keeps the banner's promise?**

- **Product:** local cafe discovery, like Airbnb Explore, Google Maps Explore, Beli, Uber Eats
  home. Used when going out, weekly to monthly, not daily.
- **People:** someone in Metro Cebu on an Android phone (iPhone second), often deciding where
  to go now or this weekend, sometimes with friends. Job: *When I open Nook without a
  particular cafe in mind, I want to see a few good options near me that fit right now, so I
  can pick one and go.* For the banner: *When Nook tells me something is happening, I want one
  tap to show me where and when, so I can decide if I'm in.*
- **Journeys:**
  1. Open Home → scan shelves (curated and built-in) → tap a cafe.
  2. See the campaign banner → tap → land on something useful, or dismiss it.
- **Evidence:** the review's screenshots and source; the HOME_LAYOUT contract; the retention
  teardowns brief (`nook-marketing/research/2026-10-retention/teardowns/README.md`); Refero
  flows. **No funnel exists.** `home_banner_shown/tapped/dismissed` and the layout `version`
  property are on this branch only and nothing is published, so there is no data for either
  journey. The only live context: week-1 retention under 7% on ~150 installs.

## Journeys today

Scores are single-rater, after NN/g PURE: 1 easy, 2 noticeable effort, 3 hard enough to give
up. Walkthrough questions: try / notice / connect / see it worked.

### J1. Open Home → scan shelves → tap a cafe

| # | Step (seen) | What they must know or decide | Confirms | Score | Walkthrough fails |
|---|---|---|---|---|---|
| 1 | Home opens: logo, search, banner (if published), then shelves in the admin's order (`fixture-banner.png`) | — | — | 1 | — |
| 2 | Scan shelf titles: "Fresh on Nook", "Editor's picks", "Rainy-day cafes", "Specialty, best rated", … "Near you" comes after five others (`fixture-appended-builtins.png`); "Your places" sits below the banner and two shelves (`fixture-your-places-custom.png`) | Which shelf fits *now* | — | 2 | **notice**: the shelves that answer "near me" and "mine" are below the fold |
| 3 | Scan cards: photo, name, area, distance (some shelves), open state, one tag | Which cafe | — | 2 | **connect**: at the time of the run every card read "Closed" in red; no shelf can be limited to open now |
| 4 | Go deeper: built-in shelves have "See all"; rule shelf "Specialty, best rated" has none (review finding 4) | — | — | 2 | **try**: a rule shelf ends at its last card |
| 5 | Tap a card → Cafe Details | — | Cafe page | 1 | — |

Single-rater total: **8** (5 steps). Built-in Home (no layout): Your places, Near you, House
picks lead (`builtin-top.png`), so steps 2 and 4 score 1 and the total is **6**.

### J2. Banner → tap → land, or dismiss

| # | Step (seen) | What they must know or decide | Confirms | Score | Walkthrough fails |
|---|---|---|---|---|---|
| 1 | Banner at the top: "Cebu Coffee Week is on", "Five days of cupping sessions and latte art throwdowns.", pill "See crowd favorites", photo, close disc (`fixture-banner.png`) | Is this for me? | — | 1 | — |
| 2 | Tap the card or pill → `nook://search?sort=trending` | — | Navigation | 1 | — |
| 3 | Lands on search: "Search cafes or people", "Near Current location", chip "Crowd favorites", skeleton list (`banner-tap-search.png`) | Is this Coffee Week? Which cafes take part, when? | Nothing names the campaign | 3 | **connect** and **see it worked**: the page answers "popular cafes", not the banner's "where is Coffee Week" |
| 4 | Back → Home, banner still there | — | — | 1 | — |
| 5 | Dismiss: tap the 24px disc (44pt target); banner disappears instantly, shelves jump ~300px, gone for this version with no undo (`banner-dismissed.png`) | Sure? | The banner is gone | 2 | **see it worked**: yes, but no way back if it was a mis-tap |

Single-rater total: **8** (5 steps).

States: banner loading (cache first, background refresh, code); no banner (built-in Home,
seen); image fails to load (coffee-icon fallback, code only); offline with no cache (built-in
Home, code); broken `nook://` link ("This link doesn't open anything", code); banner at text
scale 2.0 (CTA "See crowd fav…" truncated, seen `font2-banner.png`); undo after dismiss
(missing).

**What a banner can link to today (code, `home_link.dart` + `app_router.dart`):**
`nook://cafe/<id>`, `nook://search?q=…&sort=…` (no tag filter), `https://www.nookph.app/u/…`
and `/c/<share code>` (a shared crawl), or any other `https` URL in the browser. There is no
route for a shelf, a set of hand-picked cafes, or `nook://crawls/<id>` — the contract's own
example lands on the "doesn't open anything" page.

## How others do it

Contact sheet: `/tmp/ux-home-layout/sheet-a.png` (not committed).

**J1, curated home rails**

- **Airbnb, Explore** ([6388](https://refero.design/flows/6388)), 2 steps: location- and
  time-scoped rails ("Popular homes in Cleveland >", "Available in Cincinnati this weekend >")
  → save from the card with a toast "Saved to Wanderlust · Change". Notable: every rail title
  is itself a link to the full set, and the scope (place, when) is in the title.
- **Netflix, Home** ([10589](https://refero.design/flows/10589)), 3 steps: personal rows mixed
  with curated ones ("My List · See All" sits among "Emotional TV Dramas") → a Categories pill
  opens curated collections. Notable: the personal row stays high and always has "See All".
- **HBO Max, Home** ([10284](https://refero.design/flows/10284)), 3 steps: Top 10, New
  Episodes, Trending rails → overflow on a poster opens a quick sheet (synopsis, Add to My
  List, Share, More Info) → toast "Added to My List". Notable: you can act on a card without
  leaving Home.

Pattern: rails are titled by what they mean for *you now* (near, this weekend, mine), and every
rail leads to its full set. Split: Netflix and HBO let you act from Home (sheet, list row);
Airbnb only saves from the card and opens the listing for everything else.

**J2, campaign or promo card → landing**

- **Netflix, curated collection** ([10589](https://refero.design/flows/10589)), 3 steps: pick
  "2026 Netflix Oscars" → Home becomes a landing with hero art, "Oscars® Spotlight" headline,
  a one-line description, then "2026 Nominees" and "Oscar®-Winning Movies" rows; an X on the
  pill returns to normal Home. Notable: the landing repeats the campaign's name and is made of
  only the campaign's items.
- **Drinkit, promo feed** ([11009](https://refero.design/flows/11009)), 3 steps: "$1 Welcome
  Drink" card with an inline Apply → detail sheet with the terms and a menu of what it applies
  to → toast "Offer applied", card shows "Applied". Notable: the card's state changes once
  you've acted on it.
- **Blackbird, Wallet home tile** ([9027](https://refero.design/flows/9027)), 8 steps:
  "Challenge · Spend $30, earn $10" tile → hub → detail → Accept → "In progress $0/$30" →
  back on home the tile shows "16 days left" and progress. Notable: the home tile is the
  campaign's status, not a one-way ad.
- Dismiss, for comparison: **Pinterest** ([2474](https://refero.design/flows/2474)) replaces a
  hidden item with an inline "Got it! We'll try to show you fewer Pins like this · Undo · Tune
  feed".

Pattern: the tap lands on a page *about the campaign*, titled with its name, holding only its
items, with the next action on it. Split: Netflix and Drinkit end on content; Blackbird turns
the banner itself into a progress tile. None of them make a hide permanent without an undo.

Teardowns brief (supporting): it ranks "fresh Cebu content" and the "Your places" rail as the
return hooks (§2), and warns that pushes and nudges only work when the content behind them is
real (§6). A banner that lands on a generic search is the in-app version of a push that
points nowhere.

## Findings

Ranked by severity, then evidence (`seen` > `code` > `inferred`).

1. **Major · code + seen · J2 step 3 — the banner cannot land on its campaign.** The banner
   promises Coffee Week; the tap opens a generic "Crowd favorites" search with no mention of
   Coffee Week (`banner-tap-search.png`). The link vocabulary has no target for "these cafes"
   (a shelf or a hand-picked set), no tag filter on search, and the contract's example
   `nook://crawls/<id>` hits the dead-link page. *Cost:* the one moment Nook has a reason to be
   opened today, the person lands somewhere that doesn't answer "where, when", and the banner
   reads as an ad (information scent breaks). *Reference:* Netflix's Oscars landing (hero,
   name, only its items); Drinkit's promo detail. *Change:* add a shelf landing route,
   `nook://shelf/<section id>` (e.g. `custom:<id>` or `featured`), that opens a full-screen
   list titled with the banner title and body, showing that shelf's cafes with "open now"
   and distance, Back to Home. Let `/search` take `tag=` too. In nook-admin, validate the link
   before publish (it must resolve to a cafe, a shelf in the same document, a search, or an
   https URL) and offer "link to a shelf" as the default. Update HOME_LAYOUT.md's example.
2. **Major · seen · J1 step 2 — an admin order can bury "Near you" and "Your places".** With
   the fixture, Near you is sixth and Your places is below the banner and two shelves
   (`fixture-appended-builtins.png`, `fixture-your-places-custom.png`). The built-in Home leads
   with both on purpose. *Cost:* for a "where now" app, Near you is the shelf most likely to
   produce a tap, and Your places is the reason a returning user came back (retention plan R2);
   pushing them down trades the return hook for editorial shelves. *Reference:* Airbnb leads
   with place- and time-scoped rails; Netflix keeps "My List" in the first screens. *Change:*
   in the app, keep `your_places` and `nearby` in the first three slots when they have content
   and a position is known, unless the document sets an explicit `pin_order: true`; in the
   admin, write `nearby` and `your_places` into every document at their default positions and
   warn when either is dragged below slot 3 (review finding 3 goes further than a doc note).
3. **Moderate · seen · J2 step 5 — dismiss is permanent, instant, and has no undo.** One tap
   on a small disc hides the banner for that version; the page jumps ~300px
   (`banner-dismissed.png`). *Cost:* a mis-tap while scrolling loses the campaign until the
   admin edits the title; the jump costs the person their place. *Reference:* Pinterest's
   inline "Got it · Undo"; Pinterest's comment hide restores on Undo. *Change:* as the review
   says: SnackBar "Announcement hidden · Undo", `AnimatedSize` collapse, write the dismissal
   only when the SnackBar closes without Undo.
4. **Moderate · seen · J2 step 1 — the banner CTA and body truncate at large text.** At 2.0
   the pill reads "See crowd fav…" and the body is cut (`font2-banner.png`). *Cost:* people
   who use large text can't tell where the tap goes. *Reference:* Drinkit's promo card keeps
   one short line and puts the rest on the detail. *Change:* review finding 1 (wrap the CTA,
   stack the image above the copy past 1.5x); in the admin, cap the CTA at ~20 characters and
   preview at 2.0.
5. **Moderate · code · J1 step 4 — rule shelves end in a dead end.** "Specialty, best rated"
   has no "See all" while every built-in sorted shelf has one. *Cost:* the shelf that the admin
   built as "a search" can't be opened as one, so a person who likes the shelf has nowhere to
   go after 10 cards. *Reference:* Airbnb's rail titles with ">"; Netflix "My List · See All".
   *Change:* review finding 4; with finding 1's shelf route, "See all" on any custom shelf (rule
   or picked) can open the same landing page, so one page serves both the banner and the shelf.
6. **Moderate · inferred · J1 step 3 — no shelf can mean "open now".** Rule sorts are
   `top_rated|trending|newest|nearby`; schedules hide whole shelves by time, but a shelf's cafes
   aren't filtered by their hours. In the run, every card read "Closed". *Cost:* a curated shelf
   of closed cafes is a list for later, not a choice for now. *Reference:* Airbnb's "Available
   … this weekend" rail is scoped by availability. *Change:* add `rule.open_now: true`
   (additive, schema 1 readers ignore it), or sort open cafes first inside every shelf. Check
   with data first (see questions).
7. **Minor · seen · J1 step 2 — two near-duplicate shelves can show together.** "Specialty,
   best rated" and "Specialty coffee near you" both appear (`fixture-end-with-location.png`).
   *Cost:* more shelves, same answer (Hick's law: more options to scan for no new choice).
   *Change:* the admin preview flags a custom rule shelf whose tag matches a visible built-in.
8. **Minor · code · J2 — the banner is a one-way announcement.** After a tap it looks the same
   as before; the banner keeps its full height on every return. *Reference:* Drinkit's card
   shows "Applied"; Blackbird's tile turns into a status. *Change:* after a tap, collapse the
   banner to a one-line strip ("Cebu Coffee Week · Open") for the rest of that version; keep
   dismiss for the full removal.

## Recommended flow

**J1 (layout published):**

1. Home opens: search, banner (if any), then **Your places and Near you in the first three
   slots** when they have content *(changed: finding 2)*.
2. Curated shelves follow in the admin's order; duplicates flagged at publish *(changed:
   finding 7)*.
3. Cards show open state; shelves that opt in to `open_now` hold only open cafes *(changed:
   finding 6, after the data check)*.
4. **Every shelf has "See all"**, opening the shelf landing page *(changed: finding 5)*.
5. Tap a card → Cafe Details.

Single-rater: before **8**, after **5**.

**J2:**

1. Banner at the top; CTA fits at large text *(changed: finding 4)*.
2. Tap → **shelf landing**: banner title and body as the header, only the campaign's cafes,
   open state and distance, Back to Home *(changed: finding 1)*.
3. Tap a cafe → Cafe Details.
4. Back on Home, the banner is a **one-line strip** *(changed: finding 8)*.
5. Dismiss → collapses smoothly, SnackBar with **Undo** *(changed: finding 3)*.

Single-rater: before **8**, after **5**.

## To test with real people

| Question | Method | Exact task or prompt | Success |
|---|---|---|---|
| Does the banner read as news or as an ad? | Five-second test, 5 people, `fixture-banner.png` | "What was the top card about? What would happen if you tapped it?" | 4 of 5 name the event and expect to see its cafes |
| Does the current landing keep the promise? | 5-person task test, think aloud | "Nook says Coffee Week is on. Find a cafe taking part that you could go to." | Today: count who give up or say "this is just popular cafes". After finding 1: 4 of 5 pick a participating cafe in under 60 s |
| Where do people look first for "a cafe now"? | First-click test on Home with the fixture order vs built-in order | "You want coffee in the next hour. Tap where you'd start." | First click lands on Near you or search, not a curated shelf; compare orders |
| Do curated shelves earn taps over Near you? | Analytics (HEART: Engagement) | Goal: Home produces a cafe visit. Signal: rail taps by rail id and slot. Events: existing `home_rail_impression` and `home_rail_card_tapped` with `version`; add the slot index | Custom shelves' tap rate per impression is at least Near you's; if not, demote them |
| Does the banner lead to a cafe? | Analytics (HEART: Task success) | `home_banner_tapped` → `view_details` within the same session, with `source=banner` (add) | Over 30% of taps reach a cafe page; dismiss rate under 20% of shown |
| Are closed cafes the problem at the hours people open Home? | Analytics check before finding 6 | Share of rail impressions where the cafe is closed, by hour | If over half of evening impressions are closed cafes, build `open_now` |

Next job suggested: `overhaul` of the banner landing (a new shelf page), after the link change
is agreed in HOME_LAYOUT.md.
