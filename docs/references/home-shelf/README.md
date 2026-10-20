# Home shelf page · references (ios, Android-first)

Direction: project theme (`lib/core/theme`, `SearchTokens`, `primary20` sage from the Home
banner). Rows reuse `SearchResultRow`. Researched 2026-10-16 with partwise.

## Collection landing
Full-screen list behind a custom shelf's "See all" and a banner link (`nook://shelf/<id>`):
header with the shelf or campaign title and an optional line, a count, then the cafes.
Built in `lib/features/home_page/presentation/pages/home_shelf_page.dart`.

**Primary: Uber Eats.** Borrow: Blackbird, World App. Rejected: Instagram Places, Google Maps.

| | Product | Taken |
|---|---|---|
| ![](collection-ubereats.png) | [Uber Eats](https://refero.design/screens/c4e99cba-1932-4a24-9686-f8d1e812848f) | Back arrow above a big title on a tinted header block, a results count, then photo-left rows |
| ![](collection-blackbird.png) | [Blackbird](https://refero.design/screens/40912fec-7c6a-4e39-a65a-e8183b6f6c84) | Distance and area in one line, Open or Closed with its time on its own line under it |
| ![](collection-world.png) | [World App](https://refero.design/screens/02c62372-30d4-4e1f-bf08-21618d862aa9) | A one-line context header with the count over the list |
| ![](collection-instagram.png) | [Instagram Places](https://refero.design/screens/2a16c501-ed0c-401e-9c9d-4656f218bf89) | Considered, not taken: three-photo strip per place makes 30 rows too tall |
| ![](collection-gmaps.png) | [Google Maps](https://refero.design/screens/7b90715a-f1a5-4dd8-8f4e-cddc877fb6d8) | Considered, not taken: tabbed header and full-width photo cards |

None of the five shows a description line, loading, empty/ended or error states; those follow
the app's own (search skeleton, `LinkNotFoundPage` wording).
