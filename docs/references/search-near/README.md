# Search near · saved places and place search · references (ios)

Direction: the search redesign's tokens (`lib/features/search/presentation/widgets/search_tokens.dart`),
the existing "Search near" sheet and `nook-supabase/docs/DESIGN_SYSTEM.md`. Nothing new was
guessed: every colour, radius and type size is an existing search token.
Researched 2026-10-05 with partwise. The crops are gitignored (other products' screenshots).

## Saved places section
Home and School or work presets, custom named places, Add a place; one tap searches near it.
Built in `lib/features/search/presentation/widgets/saved_places_section.dart`.

**Primary: Google Maps.** Borrow: Lumy, Uber. Rejected: none padded in.

| | Product | Taken |
|---|---|---|
| ![](saved-googlemaps.png) | [Google Maps](https://refero.design/screens/47734815-544c-43f4-91d8-1c1f72f7b16d) | Home and Work are the first rows, custom places follow in the same row shape, each with a trailing ⋯ for edit and delete |
| ![](saved-uber.png) | [Uber](https://refero.design/screens/e088f240-b009-46ba-acab-f5f1b1eaf484) | A "Saved places" section label above the rows (in the sheet's existing muted 12 label, not Uber's icon header) |
| ![](saved-lumy.png) | [Lumy](https://refero.design/screens/a18a8df8-e338-4339-a1d7-a93becea9ed9) | The place in use carries a trailing check, with Recent directly below the saved rows |

## Place results
Matching places while typing: Nook's own areas first, then the map's; credit line; pick-on-map fallback.
Built in `lib/features/search/presentation/widgets/place_search_results.dart`.

**Primary: Google Maps.** Borrow: SSENSE, Uber Eats. Rejected: Uber, Shazam.

| | Product | Taken |
|---|---|---|
| ![](results-googlemaps.png) | [Google Maps](https://refero.design/screens/99eac15a-b000-4d8f-8d5e-fc9eb7f17cbd) | Two-line rows (name, then area) with a leading round icon and one-line ellipsis on long names |
| ![](results-ssense.png) | [SSENSE](https://refero.design/screens/34353b83-f14a-44a0-86dd-52e7a3dfc63f) | Right-aligned data credit under the list ("© OpenStreetMap contributors") |
| ![](results-ubereats.png) | [Uber Eats](https://refero.design/screens/9e0fd0bf-d4ab-4d20-b1a5-bff937cfb6b3) | The last row is a separate action row with its own icon: "Pick on the map" |

Own additions, no reference had them: a cup icon on areas that have cafes on Nook, and the
loading / no match / map-search-down lines in the list slot.

## Saved place editor
Name (custom only), where it is (search, current location, map), map preview, Save, Delete.
Built in `lib/features/search/presentation/pages/saved_place_editor_page.dart`.

**Primary: Poppy.** Borrow: Fresha. Rejected: Uber.

| | Product | Taken |
|---|---|---|
| ![](editor-poppy.png) | [Poppy](https://refero.design/screens/2a9cf455-c4ef-4b05-90dd-50669a676707) | Name, address, a map card with the pin, a hint under it, and one bottom Save that names the kind ("Save as Home") |
| ![](editor-fresha.png) | [Fresha](https://refero.design/screens/f4c33f92-2137-4b54-97ef-660674851bda) | Leading icon in the name field, pin glyph leading the address row |
| ![](editor-uber.png) | [Uber](https://refero.design/screens/bbd2aec2-9ae3-44a7-8694-9ae4252164ab) | Considered, not taken: label/value rows with no map, and a toast over the field |
