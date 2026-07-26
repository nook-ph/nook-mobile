# Homepage Design Prompt

A self-contained brief for redesigning the Nook mobile home screen. Paste the block below
into a design tool (Claude, v0, Figma Make, Lovable) or hand it to a designer — it carries
its own context and doesn't require reading the codebase.

**Retargeting:** the brief asks for a static HTML/CSS mock at 390×844. Change only the
**Deliverables** section for other targets:
- *Flutter code* → "Deliver a Flutter widget tree using the tokens above. Assume `context.colorScheme` / `context.textTheme` extensions exist."
- *Figma / image* → "Deliver a high-fidelity mock at 390×844, 2x."
- *Human designer* → drop Deliverables; keep everything else.

**Before using:** replace the placeholder in *Reference* with real screenshots of the current
home screen. A design tool that can see today's screen will substantially outperform one working
from description alone.

---

## The prompt

> You are designing the **home screen** of Nook, a mobile app for discovering independent
> coffee shops in the Philippines. Native app (Flutter), iOS + Android, phone only.
>
> ### Who it's for
>
> People deciding **where to get coffee, usually soon and usually nearby**. Two modes:
> browsing with intent ("somewhere to work for 3 hours") and browsing for pleasure
> (scrolling nice cafes). The home screen serves the second and hands off to search for the
> first. Users are young, urban, design-literate, and on mid-range Android as often as iPhone.
>
> ### What the home screen is for
>
> One job: **make someone want to open a cafe.** It is not a search interface and not a
> directory. Success is a tap into a cafe detail page. If someone lands here and taps
> nothing, the screen failed.
>
> ### The brand in one line
>
> Quiet, warm, and photographic. Hunter green and off-white, generous whitespace, flat
> surfaces with hairline borders — closer to a good print magazine than a food-delivery app.
> The photography carries the emotion; the chrome stays out of the way.
>
> ### Non-negotiable design tokens
>
> Use these exactly. Do not introduce new colors, sizes, or radii.
>
> **Color**
> ```
> #344E41  brand green   — active states, primary actions, emphasis
> #3A5A40  green 80      — pressed
> #588157  green 60      — rating star, chip borders  (NON-TEXT ONLY)
> #A3B18A  sage 40       — decorative
> #DAD7CD  sage 20       — backgrounds, dividers
> #0A0F0D  black         — primary text
> #767574  gray          — secondary text
> #FEFEFE  white         — surfaces
> #E0E0E0  border        — the hairline; 1px; the ONLY way depth is drawn
> ```
>
> **Type — Poppins. Four sizes, two weights. This is the entire scale.**
> ```
> 24 / 500   page + hero section titles
> 18 / 500   section titles
> 15 / 500   card names          15 / 400   body
> 12 / 500   captions, chips     12 / 400   fine print
> ```
> Set line-height ~1.1 on tight card text.
>
> **Space — 4pt grid:** `4 · 8 · 12 · 16 · 24 · 32`
> Two intentional exceptions: **22 = the page gutter** (every section aligns to it),
> **36 = the gap between sections**.
>
> **Radius:** `12` on everything (cards, images, chips, pills). `24` for bottom sheets.
>
> **Elevation:** `0`. Always. **There are no shadows in this app.** Depth is a 1px `#E0E0E0`
> border. If a design needs a shadow to read, the design is wrong.
>
> ### Hard constraints
>
> - **Light mode only.** No dark theme exists.
> - **Phone widths only** (360–430pt). Design at **390×844**.
> - **A photo is mandatory on every cafe card.** Photos are user/owner-supplied and
>   inconsistent in quality and aspect — the layout must survive an ugly one.
> - **Text must survive 200% scaling.** No fixed-height container may contain text. Show
>   how the layout reflows when type doubles.
> - **Tap targets ≥ 48×48.**
> - **`#767574` on white is the floor for secondary text** (4.5:1). Do not go lighter.
> Never put text on `#588157`.
>
> ### The data you actually have
>
> Every cafe card can show, and nothing else:
> ```
> name           string, can be long   ("Kuppa Roastery & Cafe Bonifacio Global City")
> photo          url, may be missing or low quality
> rating         0.0–5.0, one decimal  — may be 0 for a new cafe
> review_count   int, often 0
> neighborhood   string                ("Poblacion", "BGC")
> distance       meters — NULL unless the user granted location
> tags           string[]              ("Specialty Coffee", "Good for Work", "Pet Friendly")
> is_new         bool
> is_featured    bool
> ```
> **Design for the empty cases**: rating 0, review_count 0, no photo, and — critically —
> **no location permission**, which is common on first launch and makes every distance blank.
>
> ### What exists today (and what's wrong with it)
>
> Current structure, top to bottom:
> ```
> logo + a fake search field (tapping it navigates to real search)
> "Featured"    → horizontal scroller of wide 410pt bordered cards
> "New"         → horizontal scroller of 280pt cards
> "Trending"    → horizontal scroller of 280pt cards
> "Top Rated"   → horizontal scroller of 280pt cards
> ```
>
> Real problems to solve — these are the brief:
>
> 1. **It's four identical horizontal scrollers.** The page has one rhythm repeated four
>    times, so nothing feels more important than anything else and the eye slides off.
>    Give the page a shape.
> 2. **Nothing is above the fold but a logo and a search box.** The first cafe photo — the
>    entire reason to stay — is pushed down. Earn the first tap sooner.
> 3. **"Nearby" data is fetched and thrown away.** The app already resolves the user's
>    location and fetches nearby cafes, then uses them only as a source for "Featured"
>    — there is no Nearby section. For an app about coffee *right now*, proximity is
>    probably the most valuable rail and it's currently invisible. Consider leading with it.
> 4. **"Featured", "New", "Trending", "Top Rated" are four flavors of "cafes we like."**
>    They don't help a user choose. Would intent-based entry points ("Open now",
>    "Good for work", "Near me") serve the actual decision better?
> 5. **A cold start looks broken.** No location + no reviews yet = blank distances, 0.0
>    ratings, and a "Top Rated" rail with nothing to rank. Design that state deliberately.
>
> ### Deliverables
>
> 1. A **static HTML/CSS mock at 390×844**, self-contained in one file, no external
>    resources. Use `<div>`s with the tokens above; placeholder images may be solid
>    `#DAD7CD` blocks with a centered coffee glyph. Poppins via system fallback is fine.
> 2. The **same screen in three states**, side by side:
>    - populated, location granted
>    - **location denied** (no distances anywhere)
>    - **cold start** (few cafes, no ratings, no reviews)
> 3. The **cafe card** called out separately at 2x with its anatomy annotated.
> 4. **A short rationale** — 5 bullets max — explaining what you changed about the page's
>    structure and why, referencing the five problems above. Say what you deliberately
>    did *not* do.
>
> ### Rules
>
> - Work inside the tokens. If you believe a token is wrong, say so in the rationale — do
>   not silently invent a new value.
> - No shadows. No gradients except over a photo for text legibility. No new fonts.
> - Don't add data the backend doesn't have. No "open now" unless you flag that it requires
>   new data (it does — opening hours exist but aren't currently evaluated).
> - Prefer removing a section over adding one.
> - This replaces a working screen. Anything you change should be defensible as *better*,
>   not merely different.
>
> ### Reference
>
> [ATTACH SCREENSHOTS OF THE CURRENT HOME SCREEN HERE — populated and cold-start if possible]

---

## Notes for whoever runs this

**The tokens are deliberately not identical to the code.** The brief specifies `#767574` for
secondary text, but the app currently ships `#868584`, which fails WCAG AA at 3.5:1. The
brief carries the corrected value so a new design isn't born non-compliant. See
`design_system.md` → Known deviations #1.

**Problem 3 is the highest-leverage item.** `nearby` is already fetched (`GetHomeFeedUseCase`)
and discarded into the Featured filter. A Nearby rail is the one change that needs no new
backend work and plausibly moves taps most.

**Problem 4 has a cost.** "Open now" needs `operating_hours` evaluated against the current
time — the column exists but nothing computes it. Anything intent-based beyond the existing
tags likely means new query work. Scope before promising.

**Constraint worth defending in review:** "no fixed-height container may contain text." The
app already solves this properly via `PrototypeHeight`, and it's one of the few genuinely
good accessibility decisions in the codebase. A redesign that hardcodes card heights would
regress it silently.
