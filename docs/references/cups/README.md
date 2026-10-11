# Cups · references (ios)

Direction: the app's own tokens, unchanged: `CafeDetailsTokens` and
`CafeSectionTitle` on the cafe page, `ReviewTokens` / `ReviewSheetShell` for
the composer and option sheets, `ProfileTokens` for the profile grid;
Poppins, brand #344E41, Lucide icons. Nothing guessed beyond the kind icons
(coffee, cup-soda, croissant, armchair). Researched 2026-10-11 with partwise.
Backend: nook-supabase `feat/cups` (docs/CUPS_APPLY.md); a cup is one visit.

The screenshots are other products' and stay out of git (`.gitignore` here).
`screens/` holds the emulator checks (also ignored).

## Cup composer
"Add your cup" for this visit: what you had (photos and named items, each
with a kind: Coffee, Drink, Food, Space, and a name with menu suggestions),
an optional note, optional stars, the visit's day; Post. Edit and Delete for
your own cup.
Built in `lib/features/cups/presentation/widgets/cup_composer_sheet.dart`.

**Primary: Oku.** Borrow: Monday, Google Maps. Rejected: Kitchen Stories, Klarna.

| | Product | Taken |
|---|---|---|
| ![](composer-oku.png) | [Oku](https://refero.design/screens/2179e8d4-4b41-47d8-b001-0d8e4d2b28fc) | Sheet shell: title with close X, divider, "(optional)" in the field's label, full-width submit that shows progress while posting |
| ![](composer-monday.png) | [Monday](https://refero.design/screens/c0650544-727f-4331-bdff-46af833d304e) | Photo thumbnails in one row, each with a thin bar along its bottom edge while it uploads |
| ![](composer-maps.png) | [Google Maps](https://refero.design/screens/36629262-b69a-46bf-b366-86ed51dcaa60) | A "posting publicly" line under the header, with who reads it |

Not in any reference, designed here: the add tile ending the row, the
selected item's kind chips and name field, text-only items, the "Visited"
day row, the legacy-mode "needed with a note for now" hint, Delete.

## Cafe Cups section and Cups page
Where Reviews was: "Cups" with the count, the stats line (stars from people
who rated, each once; cups; photos), the kind filter, two cups, See all and
Add your cup. See all opens Cups | Photos with kind, rating and sort.
Built in `lib/features/cups/presentation/widgets/cafe_cups_section.dart`,
`lib/features/cups/presentation/widgets/cup_card_view.dart`,
`lib/features/cups/presentation/pages/cafe_cups_page.dart`.

**Primary: Klarna.** Borrow: Google Maps, Fable. Rejected: Promova, Fresha.

| | Product | Taken |
|---|---|---|
| ![](cups-klarna.png) | [Klarna](https://refero.design/screens/d4a0178f-b8a4-496e-810a-14711e82047a) | Card header with avatar, name and date on the left and stars on the right; footer with the Helpful pill and "…" at opposite ends |
| ![](cups-gmaps.png) | [Google Maps](https://refero.design/screens/404a1fa0-01b9-4274-aea3-4975df2aabef) | Photos under the words with a "+N" tile for the rest; note clamped with an inline More |
| ![](cups-fable.png) | [Fable](https://refero.design/screens/25d5df0c-be76-432b-b5a5-28c9af1c8286) | An outlined add pill closing the list; cards separated by dividers |

Not in any reference, designed here: the stats line, the kind chips with
counts, photo-only and text-only cards (no stars drawn when there are none),
"N visits here", the empty state, the Cups | Photos toggle.

## Profile Cups grid
One tile per cafe, newest visit first; tap opens that cafe's cups.
Built in `lib/features/cups/presentation/widgets/profile_cups_grid.dart`,
`lib/features/cups/presentation/widgets/profile_cafe_cups_sheet.dart`.

**Primary: TikTok.** Borrow: Instagram, Google Maps. Rejected: BeReal, Sora.

| | Product | Taken |
|---|---|---|
| ![](grid-tiktok.png) | [TikTok](https://refero.design/screens/9d54f8a6-732a-4ff7-925a-7057bc81229b) | Flush 3-column portrait grid under the tabs; a small label chip top-left (the stars) |
| ![](grid-instagram.png) | [Instagram](https://refero.design/screens/18cd0d4b-35ef-4d20-a875-5c731ac44066) | Stacked-squares mark top-right when a tile holds several photos |
| ![](grid-googlemaps.png) | [Google Maps](https://refero.design/screens/34662492-2f05-4903-bc3d-fbfa41a1977c) | Place name and a meta line at the bottom-left over a scrim |

Not in any reference, designed here: the counts line, the note-or-items tile
for a cafe without photos, the empty and private states, the per-cafe sheet.

## Latest cups (stories tray)
Kept from `docs/references/cafe-stories`; counts made honest: the title
counts cups (visits), a ring says "N visits" or "N photos", never "N cups"
for one visit.
