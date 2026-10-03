# Profile · references (ios)

Direction: `docs/design_system.md`. Researched 2026-10-03 with partwise (`part`).
Screenshots are gitignored.

## Ranked tab
The person's Been list as their ranking, as the profile's first tab (before
Reviews and Lists), with the ranked count on the tab. Built in
`lib/features/profile/presentation/widgets/profile_ranked_tab.dart`, reusing
`RankedBeenList`.

A strip of top cafes above the tabs was built first from these references and
replaced by the tab, because profiles are planned to be public and the ranking
is the profile's main content rather than a summary of it.

| | Product | Taken |
|---|---|---|
| ![](taste-showcase.png) | [Showcase](https://refero.design/screens/88b9205e-52ad-4b65-990a-3619bfc87fd9) | Considered for the strip: a heading over one row of poster cards with a score badge |
| ![](taste-gowalla.png) | [Gowalla](https://refero.design/screens/3e86fbdb-6aaf-4538-a535-e4cabcabcb64) | Considered for the strip: a heading row ending in its count and a chevron |
| ![](taste-vinyls.png) | [Vinyls](https://refero.design/screens/f27c8a87-0802-4502-b30c-a56753414c94) | Considered, not taken: stat cells with no tap affordance and nothing ranked |
