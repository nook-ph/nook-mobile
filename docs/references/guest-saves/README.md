# Guest saves follow-ups · references (ios mode, Android-first)

Direction: project tokens (brand `#344E41` / pill `#3A5A40`, Poppins, `ListsTokens`,
`AuthColors`, the dark toast bar in `toast_helper.dart`). Researched 2026-10-16 with partwise;
crops taken from Refero thumbnails (488 wide), enough for structure, not for measuring.

## Cafe page top-right save
For a guest, the top-right control is the Want to try save; signed in it adds to a custom list.
Built in `lib/features/cafe_details/presentation/pages/cafe_details_page.dart` (`_SavedButton`,
`_TopBarSaveIcon`).

**Primary: Oku.** Borrow: Blackbird. Rejected: Pinterest.

| | Product | Taken |
|---|---|---|
| ![](topsave-oku.png) | [Oku](https://refero.design/screens/57c36635-0b48-4219-87b4-ac46361d43f5) | "Add to a collection" sits top right with a plus, so adding to a list reads differently from saving |
| ![](topsave-blackbird.png) | [Blackbird](https://refero.design/screens/de8ad1e4-eff2-4300-ba89-72162b8f3dd9) | Want to Go is a fixed list a place is saved to directly, separate from custom lists |
| ![](topsave-pinterest.png) | [Pinterest](https://refero.design/screens/14be2925-6429-4f8e-9b65-217da11a9fe7) | Considered, not taken: a labeled Save in the action row duplicates Nook's pills |

## Save toast
Confirms a save, names where it went, offers Undo and View. Built in
`lib/core/utils/toast_helper.dart` and `lib/features/guest_saves/presentation/save_actions.dart`.

**Primary: Substack.** Borrow: Pinterest. Rejected: Matter.

| | Product | Taken |
|---|---|---|
| ![](toast-substack.png) | [Substack](https://refero.design/screens/26cf5676-0ea0-4c32-80f3-10cc2b323804) | A short past-tense confirmation at the bottom, above the bar, gone on its own |
| ![](toast-pinterest.png) | [Pinterest](https://refero.design/screens/4b3983ff-8c17-4895-8f0e-cf3ecea55247) | The message names the destination ("Saved to <list>") |
| ![](toast-matter.png) | [Matter](https://refero.design/screens/a6dac0bf-6e72-4af4-b1a2-4e5259a2e7e5) | Considered, not taken: a full-sheet confirmation is too heavy for a repeat action |

## Your places header
Title, a line saying what is in the rail, See all to Saved. Built in
`lib/features/home_page/presentation/widgets/your_places_rail.dart` (`HomeSectionTitle` in
`home_card_section.dart`).

**Primary: Google Maps.** Borrow: Fresha. Rejected: Newsadoo.

| | Product | Taken |
|---|---|---|
| ![](rail-gmaps.png) | [Google Maps](https://refero.design/screens/e0026982-0ef1-49c9-a63a-4bfb2a69dc62) | A plain section title over a horizontal row of saved places |
| ![](rail-fresha.png) | [Fresha](https://refero.design/screens/d1eb61e6-7940-434c-92d8-6a6a432f116e) | Saved and recently viewed are both named; Nook names both in one subtitle since it is one rail |
| ![](rail-newsadoo.png) | [Newsadoo](https://refero.design/screens/6c25d0c5-24e5-4ead-87f6-5bd5487b2421) | Considered, not taken: title only, nothing says why items are there |

## Keep-saves ask sheet
The engagement-score ask: icon, title, reason, provider buttons, terms, Not now. Built in
`lib/core/presentation/widgets/guest_sign_in_sheet.dart` and
`lib/features/auth/presentation/widgets/sign_in_choices.dart` (`_InlineTerms`).

**Primary: Promova.** Borrow: Dropbox. Rejected: X.

| | Product | Taken |
|---|---|---|
| ![](ask-promova.png) | [Promova](https://refero.design/screens/6b3754f8-b746-4b84-922e-ab70c7da76c2) | Title says what is kept, one reason line, provider buttons, a plain-text dismiss last |
| ![](ask-dropbox.png) | [Dropbox](https://refero.design/screens/4a27cf7a-cab3-4323-bc73-14280131095e) | The terms tick sits beside its sentence with both links, before the action |
| ![](ask-x.png) | [X](https://refero.design/screens/71e09a7e-d2bc-423d-892e-4a9ee8152d42) | Considered, not taken: a passive "By signing up, you agree" line; App Review 1.2 rejections ask for an explicit agreement |
