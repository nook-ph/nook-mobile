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
