# Saver survey sheet · references (ios / Android-first)

Direction: project tokens (`lib/core/widgets/error/state_styles.dart`), the
anatomy of `ConfirmSheet` and `CityWaitlistSheet`. Guessed: nothing new.
Researched 2026-10-16 with partwise.

## Saver survey sheet
One question at app open, pick up to two of six reasons, "Something else"
opens a 120-character field, Skip and Send.
Built in `lib/features/saver_survey/presentation/saver_survey_sheet.dart`.

**Primary: LinkedIn.** Borrow: Todoist, 222.

| | Product | Taken |
|---|---|---|
| ![](sheet-linkedin.png) | [LinkedIn](https://refero.design/screens/344666cf-aa08-4096-8196-987e0471fcc3) | Grabber, title and one line, rows with a trailing checkbox, the text field under the last "Other" row, actions under a hairline |
| ![](sheet-todoist.png) | [Todoist](https://refero.design/screens/b5494d57-8a09-4371-a3db-8dd105a3b094) | Skip (quiet) and the primary side by side in one equal-width row; "pick" hint under the title |
| ![](sheet-222.png) | [222](https://refero.design/screens/ca15da8a-7888-4425-9113-c15c29a3070c) | With the keyboard open the field sits last, directly above it |

Not in any reference, designed here: rows dim once two are picked, Send
disabled until one is, the thanks toast.

## Follow-up card
After Send, the same sheet swaps to one card picked from the answer: the
named cafe's open state today, the nearest Want to Try (or the location
ask), Share, or "It'll stay in Your places."; one action, a close button.
Built in `lib/features/saver_survey/presentation/saver_survey_sheet.dart`
(`_FollowUpCard`). Researched 2026-10-16 with partwise.

**Primary: Klarna.** Borrow: Blackbird, Kickstarter. Rejected: Drinkit
(promo tiles, too busy for one card), Omio (inline banner, not a sheet).

| | Product | Taken |
|---|---|---|
| ![](followup-klarna.png) | [Klarna](https://refero.design/screens/48f14fc6-ff41-42f0-91f7-73d45641ce01) | Thank-you sheet anatomy: grabber, left-aligned headline with the close button on its line |
| ![](followup-blackbird.png) | [Blackbird](https://refero.design/screens/40912fec-7c6a-4e39-a65a-e8183b6f6c84) | Place row: photo left, name, then the open state as the last line (state, dot, time) |
| ![](followup-kickstarter.png) | [Kickstarter](https://refero.design/screens/0106a48f-e654-4cbb-88db-4ad955321b2a) | One short sentence, then a single full-width Share as the only next step |

Not in any reference, designed here: the location-ask, no-hours and
"later" states; the distance leading the fact line on the nearest card.
