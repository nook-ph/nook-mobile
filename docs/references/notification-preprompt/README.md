# Notification pre-prompt and Visit reminders row · references (ios, Android-first)

Direction: project tokens (`ProfileTokens`, the guest sign-in sheet's structure).
Nothing guessed beyond the states no reference showed (noted below).
Researched 2026-10-16 with partwise. Crops are gitignored (other companies' screens).

## Notification pre-prompt sheet
Bottom sheet after Directions or a Want to try save, before the system dialog:
icon, title tied to the moment, one-line reason, "Turn on", "Not now".
Built in `lib/features/visit_reminders/presentation/widgets/notification_preprompt_sheet.dart`.

**Primary: Roi.** Borrow: none taken. Rejected: Airbnb's close X, Box Box Club.

| | Product | Taken |
|---|---|---|
| ![](preprompt-sheet-roi.png) | [Roi](https://refero.design/screens/593044fc-0d47-4071-a69f-f281ab582182) | Edge-anchored sheet with grabber, centred icon above title and two-line reason |
| ![](preprompt-sheet-airbnb.png) | [Airbnb](https://refero.design/screens/a292abe9-8a8b-405f-b588-588d9aeb739b) | Considered, not taken: a close X; grabber, scrim tap and "Not now" already dismiss |
| ![](preprompt-sheet-boxbox.png) | [Box Box Club](https://refero.design/screens/c1905c15-de70-489d-9b72-1f023be49737) | Stacked full-width primary above secondary (also the project's own sheet pattern), so large text never squeezes a side-by-side row |

## Visit reminders settings row
One switch row in Settings > Permissions that follows the OS permission.
Built in `lib/features/profile/presentation/pages/settings_page.dart` (`_SwitchRow`).

**Primary: Opal.** Borrow: Lumy. Rejected: Revolut's shared card.

| | Product | Taken |
|---|---|---|
| ![](row-opal.png) | [Opal](https://refero.design/screens/3f0544c3-1b67-42ef-808a-2360272e8e49) | Title and trailing switch on one line, description beneath |
| ![](row-lumy.png) | [Lumy](https://refero.design/screens/7055b8d6-074a-4796-ac23-19e7f2dc0435) | Blocked state: a line saying what is off, then "Open settings" (inline here, not a red card) |
| ![](row-revolut.png) | [Revolut](https://refero.design/screens/23e03b1a-e493-428d-b950-dec7ad6287b0) | Leading icon column (already the project's row); the shared card was not taken |

No reference showed a "not asked yet" or loading row: not asked keeps the switch usable and
asks on turn-on; loading disables the switch until the permission is read.
