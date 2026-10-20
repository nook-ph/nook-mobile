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

## Keep-saves ask sheet, follow-ups (2026-10-16)
The sheet now opens with a line confirming the save that triggered it, names the count in the
title, and on a repeat ask states the stake and offers "Keep using on this phone". Built in
`lib/core/presentation/widgets/guest_sign_in_sheet.dart` (`_ConfirmationLine`, `stayLabel`) and
`lib/features/guest_saves/presentation/engagement_score.dart` (`SignUpAskCopy`). No reference
shows a confirmation line or a count in the title; those are Nook's own (ux finding 1). The
structure above (Promova primary) stands.

**Primary: Omio.** Borrow: Kitchen Stories. Rejected: Atoms.

| | Product | Taken |
|---|---|---|
| ![](ask-omio.png) | [Omio](https://refero.design/screens/91290c5d-e769-4e23-a17e-3e72fef70b27) | Heading, one reason line, the tick, stacked provider buttons: the order kept |
| ![](ask-kitchen.png) | [Kitchen Stories](https://refero.design/screens/427368d3-312c-4c5f-bb32-18186500479a) | The way out is plain text set apart from the providers; "Keep using on this phone" is a quiet text button under Not now |
| ![](ask-atoms.png) | [Atoms](https://refero.design/screens/66a77ac8-5469-4883-a1f7-56abf63fd640) | Considered, not taken: a close X in the corner; Not now already sits at the thumb |

## Saved tab, keep-saves row
After two declined asks the keep-saves card becomes one row below the lists: phone icon, "On
this phone only", Sign in; the whole row is one button. Built in
`lib/features/guest_saves/presentation/pages/guest_saved_page.dart` (`_KeepSavesRow`). Refero
has no direct match; these are proxies.

**Primary: Google Maps.** Borrow: Ten Percent Happier. Rejected: On.

| | Product | Taken |
|---|---|---|
| ![](saved-row-maps.png) | [Google Maps](https://refero.design/screens/7d12720e-6049-481a-90e2-9ec0c9bd5666) | After the list's last hairline, one quiet row that reads as a footer, not a list item |
| ![](saved-row-tenpercent.png) | [Ten Percent Happier](https://refero.design/screens/55358d7d-4c59-4202-9aa9-f6a00cf150e5) | A guest-status line below the lists, label and trailing action in one tap target |
| ![](saved-row-on.png) | [On](https://refero.design/screens/811fd337-c6f8-42ae-b3dd-b99d611cce97) | Considered, not taken: label and chevron only, nothing says the saves are on this phone |

## Merge ask sheet
After a sign-in, asks before moving saves another account left on this phone into the account
just signed in ("Add 3 saves from this phone?" · Add them / Not now). Built in
`lib/features/guest_saves/presentation/widgets/merge_ask_sheet.dart`, laid out like the
notification pre-prompt and guest sign-in sheets (grabber, icon in the 56 tinted circle, centred
title and reason, pill, text action). Researched 2026-10-19 with partwise.

**Primary: World App.** Borrow: Copilot. Rejected: Nike Training Club.

| | Product | Taken |
|---|---|---|
| ![](mergeask-world.png) | [World App](https://refero.design/screens/2f94df17-b13e-42e4-b05a-b1da0ffb3cc6) | Icon on top, centred title and reason, full-width primary, borderless "Not now" under it |
| ![](mergeask-copilot.png) | [Copilot](https://refero.design/screens/0e17ef62-4ee7-4600-a438-e3071c9e2e25) | The sheet hugs its content at the bottom, the screen dimmed above it |
| ![](mergeask-nike.png) | [Nike Training Club](https://refero.design/screens/8344f748-a83c-4996-97d1-8ad1aafca9bb) | Considered, not taken: full-screen with an outlined second button and a close X, too heavy for a yes/no |
