# Notification pre-prompt and Visit reminders row · references (ios, Android-first)

Direction: project tokens (`ProfileTokens`, the guest sign-in sheet's structure).
Nothing guessed beyond the states no reference showed (noted below).
Researched 2026-10-16 with partwise. Crops are gitignored (other companies' screens).

## Notification pre-prompt sheet
Superseded by "Directions ask sheet" below: the ask moved to the Directions tap and the save
ask was removed. Kept for the record.
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

## Directions ask sheet
At the Directions tap, before Maps opens: the real send time as the title ("Want a reminder
around 4:35 PM?" / "…tomorrow at 10 AM?"), the cafe in the reason, "Remind me", "Just
directions". Shown only when a reminder would actually go out.
Built in `lib/features/visit_reminders/presentation/widgets/notification_preprompt_sheet.dart`
(`NotificationPrePromptSheet`, `VisitReminderPrompts.atDirections`). Researched 2026-10-16.

**Primary: the existing sheet (Roi structure).** Borrow: Linear, Clearful. Rejected: Airbnb's
close X (as before).

| | Product | Taken |
|---|---|---|
| ![](ask-linear.png) | [Linear](https://refero.design/screens/3b00073f-9a3a-4b05-82ee-fa2b3a89f6e7) | The resolved clock time is the promise ("12:39 PM", "Jul 23 at 9:00 AM"); here it is the title |
| ![](ask-clearful.png) | [Clearful](https://refero.design/screens/9cf4bf42-239f-4d19-b3eb-76facfda6966) | "Remind me" pill with a quiet text secondary centred under it |
| ![](ask-airbnb.png) | [Airbnb](https://refero.design/screens/a292abe9-8a8b-405f-b588-588d9aeb739b) | Considered, not taken: the close X; grabber, scrim and "Just directions" already dismiss |

No reference showed an ask attached to a Directions or follow tap that then continues; the
today / tomorrow wording follows Linear's.
