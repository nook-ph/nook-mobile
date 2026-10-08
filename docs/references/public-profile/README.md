# Public profile · references (ios + web)

Direction: `docs/design_system.md` and the profile tokens
(`lib/features/profile/presentation/widgets/profile_tokens.dart`); web:
nook-webapp `design.md` (Photo shelves). Researched 2026-10-05 with partwise
(`build`). The crops were lost with the session's scratch folder; the Refero
links below are the record. Screenshots in this folder are gitignored.

## Profile header
Avatar, name, counts line, bio; owner's Edit profile with a square Share
beside it; room for Follow in the same row later. Built in
`lib/features/profile/presentation/widgets/profile_header.dart`.

**Primary: BeReal.** Borrow: Duolingo, Gowalla.

| Product | Taken |
|---|---|
| [BeReal](https://refero.design/screens/9a9ebdd2-6e0e-48b0-87c6-a22b86ef4834) | Avatar, name, bio, counts, then one full-width action; the bio line drops out when absent |
| [Duolingo](https://refero.design/screens/d53d927f-ab99-4009-8fea-1acc4c3da3ee) | A wide primary button and a square share button side by side, which leaves Follow's place |
| [Gowalla](https://refero.design/screens/23981c7b-d983-482b-9a1f-23d97bf6f272) | Considered, not taken: owner's Edit as a pill in the top corner; Nook keeps Edit in the row |

## Top 3 strip
Three equal photo tiles in rank order, rank marker on the photo, name and
area under it, no scores. Built in
`lib/features/public_profile/presentation/widgets/top_cafes_strip.dart` and
nook-webapp `app/components/profile/TopCafes.tsx`.

**Primary: Airbuds.** Borrow: Showcase.

| Product | Taken |
|---|---|
| [Airbuds](https://refero.design/screens/e4416b20-3acc-44cd-ae22-75b29878e3cb) | Three equal tiles in one row, image on top, title and subtitle under it, truncated |
| [Showcase](https://refero.design/screens/88b9205e-52ad-4b65-990a-3619bfc87fd9) | The marker inside the photo's top-left corner (here the rank, never a score) |
| [Apple Music](https://refero.design/screens/f8e1c92c-775e-4f9d-a816-83db6af33b0c) | Considered, not taken: a ranked vertical list; a strip keeps it to three |

## Visitor preview
What the owner's own Ranked tab says about visitors, and the preview.
Built in `lib/features/public_profile/presentation/widgets/visitor_hint.dart`
and `PublicProfilePage(preview: true)`.

**Primary: TikTok.** Borrow: Tinder.

| Product | Taken |
|---|---|
| [TikTok](https://refero.design/screens/0e0ad199-dd6d-465d-821f-f6333f8c9e5e) | One plain muted line by the private content: "Only you can see this" |
| [Tinder](https://refero.design/screens/eb776b9b-396d-42ec-b2c7-27e5b6713c5a) | A screen titled Preview showing the profile as others see it, with one way out |
| [LinkedIn](https://refero.design/screens/1931588f-8055-42f1-b422-994c406b1736) | Considered, not taken: visibility levels with miniatures; Nook has one switch |

## Web profile page
Built in nook-webapp `app/u/[username]/page.tsx`.

**Primary: Tripadvisor.** Borrow: Instagram.

| Product | Taken |
|---|---|
| [Tripadvisor](https://refero.design/pages/d5cba12e-c898-48aa-9a7b-923ca39faa80) | Avatar left; name, handle and counts beside it; section tabs right under the header |
| [Instagram](https://refero.design/pages/7ab0a6c4-c2e3-4a83-a539-10f31d9fe9dd) | A private profile replaces content with a lock line under the header |
| [Bento](https://refero.design/pages/6e568aa5-b390-481f-8070-92fc734f2c9a) | Considered, not taken: identity in a side column beside a card grid |
