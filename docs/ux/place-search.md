# Place search and saved places · UX research (2026-10-05)

Desk research and expert evaluation with partwise (`ux`): the new "Search
near" flow walked on an Android emulator (API 35, location near V Rama, Cebu
City) in a debug build run with `--dart-define=PLACE_SEARCH_DIRECT=true`
(Photon called from the phone, saved places kept on the device, because the
`place-search` function and `saved_places` table are not deployed yet), and
read in the code, compared with real flows from Refero. Not user research:
nothing here says what users felt or did. Questions that need real people are
at the end.

## Question

**Can someone set Home once and then find cafes near it, and can they search
near a landmark by name, without knowing Nook's own neighbourhood list?**

- **Product:** cafe discovery app, like Google Maps, Yelp, Foursquare, Airbnb
  (for the "where" picker).
- **People:** students and remote workers in Cebu, on a phone. *When I plan
  where to work or meet later, I want cafes near home, school or a mall I name,
  so I can pick one before I leave.*
- **Journeys:** (1) set my home, then find cafes near home; (2) search near SM
  Seaside. Both start on the search screen's "Near …" row; the map tab opens
  the same sheet.
- **Evidence:** the app on the emulator; its code
  (`lib/features/search/presentation/widgets/search_origin_sheet.dart`,
  `saved_places_section.dart`, `pages/saved_place_editor_page.dart`,
  `cubit/place_search_cubit.dart`) and the `place-search` function in
  nook-supabase. **Analytics:** no events exist for the "Search near" sheet,
  so there are no funnel numbers.

## Journeys today

### 1 · Set Home, then cafes near Home (sheet: [place-search/set-home-today.png](place-search/set-home-today.png))

| # | Step | Score |
|---|---|---|
| 1 | Search screen → tap "Near Current location ⌄" | 2 |
| 2 | Sheet: Current location, Pick on the map, **Saved places** (Home and School or work, each "Set it once, search near it anytime", Add a place), Recent places. Tap Home | 1 |
| 3 | "Set Home": Where it is (Search for a place), Use current location, Pick on the map, a privacy line, "Save as Home". Tap the field | 1 |
| 4 | "Find a place" sheet: type "Ayala Center Cebu"; real places appear after a pause (two rows named "Ayala Center Cebu" before the fix) | 2 |
| 5 | Back on the editor with the address and a map preview; tap Save as Home | 1 |
| 6 | Search screen says "Near Home" with a toast "Home saved. Searching near it."; no cafes show until a query or chip is chosen. Specialty Coffee → "20 cafes near Home · distances from Home", nearest 401 m | 2 |

**Total 9.** Next time: Near → Home is two taps.

### 2 · Search near SM Seaside (sheet: [place-search/search-near-landmark-today.png](place-search/search-near-landmark-today.png))

| # | Step | Score |
|---|---|---|
| 1 | Search screen → "Near Home ⌄" | 1 |
| 2 | Type "SM Seaside" in "Place, landmark or street". Results: SM Seaside City Cebu (twice, before the fix), the mall building, an access road, the arena, a BRT stop. With the keyboard up the sheet's title ran under the status bar (before the fix) | 2 |
| 3 | Tap SM Seaside City Cebu → "20 cafes near SM Seaside City Cebu · distances from SM Seaside City Cebu"; the Near row truncates to "SM Sea…" | 1 |

**Total 4.** Before this work the same search found nothing ("No places
match"): only neighbourhoods with Nook cafes could be typed.

Pick on the map now names the spot from the map ("SM Seaside City Cebu,
Mambaling, Cebu City") instead of "Pinned location".

**States:** loading ("Looking for places…") shown; no match shown; map search
down ("Map search isn't answering…", Nook areas still listed) covered by a
widget test, not reachable on the emulator; save failure, cap reached (10)
and delete confirm covered by tests; undo after delete missing (a confirm
sheet instead).

## How others do it

Sheets in `place-search/ref-*.png` (gitignored).

- **Set Home, then use it.** *komoot*: Home sits inside the start-point
  chooser ("Start from home / Add your home address"), so saving and using
  are one surface; type an address, confirm on a map pin, "Only you can see
  this information" under the map. *Fresha*: Home and Work are fixed slots in
  profile settings; "Use my location" is the first row of the address search;
  drag the map to fine-tune; no link to where the address is used. *Tripsy*:
  no saved home; the area ("Nearby Bangkok") is shown above results and
  changed in one tap, rows show distance. **Pattern:** type, pick a
  suggestion, confirm on a map. **Split:** where Home lives (in the chooser
  vs. in settings).
- **Search near a landmark.** *Airbnb*: one field "Search by address or
  neighborhood", suggestions name + address, the map recentres on the pick.
  *Blackbird*: the location is a labelled pill on the results; change is a
  short list of cities, no typing. *District*: one screen with search, "Use
  current location", popular cities; a specific "No results found for '…'";
  rows carry a type and a distance. **Pattern:** a labelled location control
  on the results opens a sheet with one field; suggestions show a name and a
  second line.

## Findings

Ranked by severity, then evidence. ✅ = fixed on `feat/place-search`.

1. **Moderate · seen · 2-2, 1-4.** ✅ With the keyboard up and the list full,
   the "Search near" and "Find a place" sheets grew past the screen: the title
   and close X sat under the status bar. The sheets capped at 85% of the
   screen *plus* the keyboard inset. Cost: no visible way to close except
   Back; looks broken. *Airbnb* keeps its sheet below the status bar.
   **Change:** cap at the space above the keyboard minus the status bar
   (`sheetMaxHeight`).
2. **Moderate · seen · 2-2, 1-4.** ✅ The same place appeared twice ("SM
   Seaside City Cebu" as an area and as a building, "Ayala Center Cebu"
   likewise) with different second lines. Cost: a choice with no difference
   between the options (Hick's law), and doubt about which is right.
   **Change:** results with the same name within 1.5 km are one place, in the
   edge function and in the debug mapper.
3. **Moderate · seen · 1-6.** ✅ The toast said "Home saved. Searching near
   it." while the search screen still waited for a query or chip. Cost: the
   person waits for results that are not coming. **Change:** "Home saved.
   Distances now measure from it."
4. **Moderate · code · 1 (edit).** ✅ Changing Home's address while Home was
   the place in use kept searching from the old coordinates until Home was
   tapped again. **Change:** closing the sheet after editing the place in use
   moves the search to the new address.
5. **Moderate · inferred · 1-3.** ✅ Nothing in the editor said who can see a
   saved address, at the moment the app asks for a home address. *komoot*
   puts "Only you can see this information" under the map. **Change:** "Only
   you can see your saved places. They never show on your profile."
6. **Moderate · code · 1-3 (map).** ✅ Pick on the map, opened from the
   editor, still said "Search near" above the spot's name and "Search here"
   on the button. **Change:** the caption names the place being set ("Home",
   or the custom name) and the button says "Use this spot".
7. **Minor · code · 2-2.** ✅ The keyboard's Search key did nothing in the
   place fields. **Change:** it takes the first saved match, else the first
   place.
8. **Minor · seen · 1-4, 2-2.** ✅ Landmarks used a columned-building icon
   that reads as "bank". **Change:** a plain building icon.
9. **Minor · seen · 2-3.** The Near row truncates long places to "SM Sea…"
   (the Reset link takes the room); the count line under it carries the full
   name. *Blackbird*'s pill shows the whole short name. **Change:** let the
   label take the row's width and move Reset into the sheet, or show the
   place's short name.
10. **Minor · seen · 1-6.** After setting Home, finding cafes still needs a
    query or chip; the map tab instead recentres on Home at once. *Tripsy*
    lists places "Nearby <area>" straight away. **Change:** consider a
    "Cafes near Home" list (sort Nearest, no query) when a place is chosen
    with no query.
11. **Minor · seen · 2-2.** Map results include roads and stops ("SM Seaside
    City Access Road 4", "SM Seaside BRT Stop"). Bus stops are kept on
    purpose: for "USC Talamban" the only map result is the campus bus stop.
    **Change:** rank streets and stops below landmarks and areas, rather than
    dropping them.
12. **Minor · inferred · 2-2.** Map rows show no distance from the person;
    *District* and *Tripsy* do. **Change:** a distance on each row when the
    phone's position is known.

Working well and worth keeping: Home and School or work inside the same sheet
that uses them (as *komoot*); one tap on a saved place; the tick on the place
in use; Nook's own areas listed first with a cup icon; the map preview in the
editor; real names for dropped pins; the fallback to Nook's areas when map
search is down.

## Recommended flows

| Journey | Steps after the changes | Score before → after |
|---|---|---|
| 1 · Set Home, then cafes near Home | Near → Home → Search for a place → pick (one row per place) → Save as Home (privacy line shown) → "Near Home" with a toast that matches what happened → a chip or query | 9 → 7 |
| 2 · Search near SM Seaside | Near → type "SM Seaside" (sheet stays below the status bar, one row per place, Search key takes the first) → results near it | 4 → 3 |

Single-rater scores, for comparing before and after only.

## To test with real people

| Question | Method | Task or prompt | Success |
|---|---|---|---|
| Do people find where to set Home? | First-click test on the search screen | "Make Nook show cafes near your home." | First tap on the Near row |
| Do people expect results right after choosing a place? | 5-person task test, think aloud | "Find a cafe near SM Seaside." | Reach a cafe in under a minute; note any wait for results after the place is chosen |
| Is "School or work" the right second preset for students? | 5-person card sort of preset names | Sort "Home", "School", "Work", "Dorm", "Office" into the two they'd keep | Two names chosen by most |
| Does the privacy line settle worries about giving a home address? | 5-second test on the editor | "What happens to the address you enter here?" | Says only they can see it |
| Is the sheet used? | Analytics (HEART: adoption) | Goal: people search near places that matter to them. Signals: share of searches with a non-phone origin; saved places per account. Events to add: `search_origin_changed` with `source` (current, saved, search, map, recent) and `saved_place_saved` with `kind` | Rising share of searches from saved places; few saved places deleted soon after saving |
