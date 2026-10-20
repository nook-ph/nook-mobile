# Places progress · references (ios, Android-first)

Direction: project tokens (`lib/features/lists/presentation/widgets/list_tokens.dart`,
`docs/design_system.md`). Guessed: the all-visited state (no reference showed one).
Researched 2026-10-16 with partwise.

## Places progress pill
"Been to 3 of 8": how many of a person's places (Been + Want to Try) they have
been to, beside the Saved tab's "Your lists" title and Home's "Your places" rail title.
States: none visited (0 of 5), some, all visited (check instead of ring), nothing saved (hidden).
Built in `lib/features/lists/presentation/widgets/places_progress_pill.dart`
(count logic: `lib/core/cafe/domain/places_progress.dart`).

**Primary: Pinkllama.** Borrow: Tripsy. Rejected: Google Maps.

| | Product | Taken |
|---|---|---|
| ![](list-progress-pinkllama.png) | [Pinkllama](https://refero.design/screens/06c10625-7398-44ba-b187-9d9271c528f5) | Title and a compact count pill share one row, pill at the end, rail directly beneath; 0 of N reads as a plain pill |
| ![](list-progress-tripsy.png) | [Tripsy](https://refero.design/screens/ed256fd8-bb30-49a7-bffe-e635fbdd1086) | A ring showing the share visited, shrunk to an icon inside the pill |
| ![](list-progress-maps.png) | [Google Maps](https://refero.design/screens/7d12720e-6049-481a-90e2-9ec0c9bd5666) | Considered, not taken: list rows carry only "Private · N places", no visited count |
