# Saver survey · UX research (2026-10-16)

Job: partwise **ux**. This is desk research plus an expert walkthrough of branch
`retention/saver-survey` at `6cc8a99`. It is not user research. Nothing here reports what a user
said or did. The journey "as it is" comes from the review's screenshots in
`review-shots-saver-survey/` (Android emulator, guest, forced survey). The companion doc is
`partwise-review-saver-survey.md`. Its fixes are referenced here but not repeated. The Refero
contact sheets were kept locally and are not committed.

Constraint for everything recommended below: **no server changes**. Answers go to PostHog only,
and analytics carry no free text.

## Question

**When a saver who hasn't visited gets the one-question survey, will it tell the team why
savers don't visit, and does answering it do anything for the saver?**

- **Product:** local cafe discovery with Want to Try / Been. Comparable products are Google Maps
  Saved, Beli, Mapstr and Too Good To Go (favourites plus a one-time "what stopped you?"
  survey).
- **People:** someone in Metro Cebu on an Android phone, guest or signed in, who saved a cafe to
  Want to Try five or more days ago, hasn't marked anything Been in 14 days, and opens Nook on a
  later day. Job: *When I open Nook and see a cafe I meant to try, I want to be reminded and
  helped past whatever stopped me, so I actually go.* The team's job: *learn which obstacle is
  most common* (retention plan §5, E9 and §6 "Ask real people").
- **Journey:** a saver who hasn't visited opens Nook → the one-question survey opens → they
  answer or skip → what happens next.
- **Evidence:** the source in `lib/features/saver_survey/` and `lib/core/analytics/saver_survey_events.dart`,
  the 8 review shots, the TGTG teardown ("Bring Back Magic": a one-time survey at app open, "What
  has stopped you from reserving a Surprise Bag?", pick 1-2 of 5), and the retention plan. **No
  funnel exists.** The branch has not been released. The plan's live context as of 2026-10-15:
  147 external mobile users in 90 days, 6 (4%) ever saved, 8 external users fired
  `mark_want_to_try`, and about 16% return on a later day.

## Journey today

The scores are single-rater, after NN/g PURE: 1 easy, 2 noticeable effort, 3 hard enough to
give up. The walkthrough questions are try / notice / connect / see it worked.

| # | Step | What they must know or decide | Confirms | Score | Walkthrough fails |
|---|---|---|---|---|---|
| 1 | App open on Home. After the feed settles 1.5s, the sheet "What's kept you from going?" opens (`01`). The rules: once ever, not the first session, 2 or more open days, a Want to Try save 5 or more days old, no Been in 14 days, no other prompt this run | **Which cafe?** The message says "You saved a cafe a while back". It does not name the cafe | — | 2 | **connect**: someone with 3 saves, or who saved once 3 weeks ago, has to remember which cafe is meant |
| 2 | Pick up to two of 6 rows: Haven't had time · Too far from me · Not sure it's open · Waiting for a friend · Found somewhere else · Something else (`02`). Once two are picked, the other rows dim and go inert | Which obstacle is true. "Not ready yet" is not on the list | Checkbox fills | 1 | **try** fails for someone who is simply saving it for later: nothing true to pick |
| 2a | "Something else" opens "Tell us more (optional)", 120 chars (`03`, `04`) | What to type | Counter | 2 | The text is thrown away (code). The person can't see that, so it is a broken promise, not a visible failure |
| 3 | Send (disabled until a pick) or Skip. Swipe, scrim and Back also count as Skip | — | — | 1 | — |
| 4 | Sheet closes. Toast "Thanks, that helps." (`05`) over the same Home | **What now?** Nothing about their answer is used | Toast | 2 | **see it worked**: the answer goes nowhere they can see. The cafe they were asked about is not shown |

**Total: 6 (single-rater).** States: the loading state is invisible by design (the gate waits for
data). If the save read fails, nothing is shown (`saves_unknown`). If the person is offline,
PostHog queues the event. There is no undo of an answer, and none is needed.

## How others do it

Refero has no Duolingo, Spotify, Headspace, Uber Eats, Airbnb or LinkedIn micro-survey flows
(the scout searched for them). The three closest real flows:

| | TikTok, "Why are you leaving TikTok?" ([2811](https://refero.design/flows/2811)) | Omio, post-booking survey ([5189](https://refero.design/flows/5189)) | Netflix, cancel exit survey ([10595](https://refero.design/flows/10595)) |
|---|---|---|---|
| Moment | Before deleting the account | Right after a booking completes, as an invite ("Got a minute?") | After the cancel is done, as a card on the confirmation |
| Question | 7 single-select reasons, with "I'm leaving temporarily" first | 6 questions, one per sheet, with a progress bar | 10 checkboxes, "select all that apply" |
| Skip | "Skip" top right, plus back | "No thanks", plus an X on every sheet | Optional by placement, Done |
| Free text | Only under "Another reason" | Only under "Other", plus one open question | Only under "Other" |
| **Does the answer change anything?** | **Yes, inline.** Picking "I'm on TikTok too much" shows "The following may help: Setting a limit on your watch time ›" under the row, on the same screen | No. Thank-you, back to the booking | No, the survey itself does nothing. But before the cancel, it offers *Pause for a month* and "What to watch before you leave" |

Related: TikTok's in-context feedback sheet ([2780](https://refero.design/flows/2780)) makes the
answer the action. Tapping a chip closes the sheet with "We'll recommend less similar products
to you." TGTG's "Bring Back Magic" (teardown) is the closest match in form (one time, app open,
pick 1-2 of 5). Whether TGTG tailors what happens after the answer is not determined.

**Pattern:** a short tap-to-pick list, a visible way out, free text only behind "Other", and a
one-line thanks. **Split:** only TikTok uses the answer to help the person, and it does so right
where the reason was given. Two of the four (TikTok, Netflix) offer a "not now, not never" path
(leaving temporarily / pause). Nook's list has none.

## Findings

Ranked by severity, then by evidence.

1. **Major · code · step 4. The answer changes nothing for the saver.** Every answer ends in the
   same toast over the same Home. A person who says "Not sure it's open" or "Too far from me"
   has told Nook exactly what would get them there. Nook already has what it needs to answer
   them on the device: each saved cafe carries `operatingHours` and `lat/lng`
   (`CafeSnapshot`, `CafeSummary`), "Your places" and `openWantToTry` exist, and so does the
   open-state label. Cost: the one moment the saver is thinking about this cafe ends with
   nothing to do, which is the pattern behind the plan's R2 ("nothing changes on the second
   open"). Peak-end: the survey is remembered as "they asked me something", not "they helped".
   Reference: TikTok shows the fix under the reason. Netflix offers the alternative (pause)
   before the exit. Change: after Send, show at most one helpful card matched to the answer
   (see the recommended flow). It is client-only and adds no server work.
2. **Major · data + code · whole journey. At ~150 installs the survey cannot give the team a
   ranking of reasons.** Eligibility needs a Want to Try save, and only 6 of 147 external users
   ever saved (8 fired `mark_want_to_try`). They also have to come back on a second day and
   reach Home, once per phone. Even after guest saves ship, expect single digits shown per month
   and fewer answered. With 10 answers, a reason picked by 5 has a 95% interval of about 24-76%.
   Cost: the team reads "40% too far" from 2 of 5 people and builds for it. Change: read it as
   cases, not shares (see "How to read the PostHog results"). Pair it with the E9 conversations,
   and do not wait on it for the Nov 11 call.
3. **Major · code · step 2a. "Something else" asks for words nobody will read.** The no-free-text
   rule means `otherText` never leaves the sheet. Only a length bucket is sent
   (`SaverSurveyAnswer.analytics()`). The team learns "someone had another reason" and nothing
   else, and the person is thanked for text that was discarded. Reference: all three flows put
   text only behind "Other", but they keep it. Change: under this constraint, drop the field.
   "Something else" becomes a plain row, and anyone who picks it is the person to message for
   E9. (The review's fix (a) is the same.)
4. **Moderate · code · step 2. Every answer is an obstacle, so "not yet" gets counted as a
   problem.** There is no "Saving it for later". A person with no obstacle skips or picks
   "Haven't had time", and both inflate "no time". TikTok lists "I'm leaving temporarily" first.
   Netflix offers a pause. Change: add `saving_for_later` as the first row and soften the line
   (the review's wording works). It also gives the data a baseline: how many savers are fine.
5. **Moderate · code · step 1. The question doesn't say which cafe.** The decision carries only
   `savesCount` and `daysSinceFirstSave`, not the stale save itself, so the copy can only say "a
   cafe". People should recognize, not recall. "Too far" or "not sure it's open" only means
   something about a specific place. Change: carry the oldest stale Want to Try (name, hours,
   coordinates) in the decision and name it ("You saved **Brew Szn** 9 days ago"; with several:
   "Brew Szn and 2 others"). This is local data, and nothing is added to analytics except
   counts.
6. **Moderate · code · step 1. A missed showing is lost for good.** `evaluate()` marks the survey
   done and claims the run's prompt slot before the host's last `_onHome` check (review, "Must
   fix"). With an eligible pool this small, every silent loss is a real share of the sample.
   Change: commit only right before `showSaverSurveySheet`.
7. **Minor · code · analytics. The events don't measure the outcome or the denominator.** Gaps:
   - `days_since_first_save` measures the oldest save of *either* kind, not the stale Want to
     Try's age.
   - No event says *why* someone was not shown (`no_old_save`, `recent_been`,
     `session_prompt`), so "eligible but crowded out" can't be counted.
   - Nothing ties the answer to a later visit.
   - `reasons` is an array, which needs `arrayJoin` to break down.

   Change: see "How to read" for the additions. They are all client-side and use no free text.
8. **Minor · seen · step 2. Six options, pick two, then the rest go inert.** Six is above the
   ~4 risk line but well under overload, and matches TGTG's 1-2 of 5. Keep it at 6-7. The fix
   for the inert rows is in the review.

## Recommended flow

What changed is marked **[new]** or **[changed]**.

1. App open, same rules (keep them: they are respectful). **[changed]** The once-only flag and
   the prompt slot are taken only as the sheet opens.
2. Sheet: "What's kept you from going?" **[changed]** "You saved **Brew Szn** 9 days ago. No
   rush. If something's in the way, pick up to two."
3. Rows: **[new]** Saving it for later · Haven't had time · Too far from me · Not sure it's open ·
   Waiting for a friend · Found somewhere else · Something else **[changed: no text field]**. Skip and
   Send stay as they are.
4. Send logs `saver_survey_answered`. **[new]** The sheet then swaps its content (no second sheet,
   no second question) to **one** follow-up chosen from the picks, in this order:

   | Pick | Follow-up (all from data on the phone) | Action |
   |---|---|---|
   | Not sure it's open | The named cafe's open state today, from saved hours: "Brew Szn is open now · until 9 PM" or "Opens tomorrow at 8 AM". With no hours: "No hours listed yet" | **See cafe** (the cafe page) |
   | Too far from me | The nearest of their saves, if location is on: "Closest of your saves: Cafe Julio, 1.2 km". If location is off: the existing "See cafes near you" ask | **See cafe** / **Use my location** |
   | Waiting for a friend | "Send it to them" | **Share** (the existing cafe share) |
   | Saving it for later | "It'll stay in Your places." | **Done** |
   | Haven't had time · Found somewhere else · Something else | No card. The sheet closes with "Thanks, that helps." (today's toast) | — |

   **Done** closes the follow-up card. Nothing is asked twice, and "Found somewhere else" never
   gets a remove-it suggestion: deleting saves is not a goal. Skip stays exactly as it is today:
   no follow-up and no guilt.
5. Back on Home. "Your places" still shows the cafe, so the next open still has it.

Single-rater score: **before 6 → after 4** (step 1 to 1 with the cafe named, step 4 to 1 with an
end that does something). Step 2a goes away.

Why after Send and not inline under the row (TikTok's way): help inline makes picking a reason
also a way to see help, which bends the data, and someone who taps through to the cafe would
leave before Send. Recording first, then helping, keeps both.

## How to read the PostHog results

**Events today:** `saver_survey_shown {saves_count, days_since_first_save, signed_in}`,
`saver_survey_answered {reasons[], other_text_present, other_text_length}` and
`saver_survey_skipped`.

**Add these with the flow above (client-only, no free text):**
- `saver_survey_followup_shown {kind}` and `saver_survey_followup_tapped {kind}`, where `kind` is
  `open_state | nearest | share | later`.
- On `shown`: `oldest_stale_days` (the stale Want to Try's age) and `location_on`.
- Optional: `saver_survey_suppressed {reason}`, once per run when a save was old enough but
  something else blocked it (`recent_been`, `session_prompt`, `not_on_home`).

**Always filter** to the "External mobile users" cohort (plan §6). Exclude the forced debug
flag (debug builds don't ship it, but internal phones may run them).

**Read it in this order:**
1. **Exposure:** distinct persons with `saver_survey_shown`. Below about 20, report raw counts
   only ("4 of 7 answered; reasons: too_far ×2, unsure_open ×1, no_time ×1"), never percentages.
2. **Answer rate:** answered ÷ shown, per person. Skips include swipes and Back. A rate under
   ~30% means the moment or the question is wrong, not that savers have no reasons.
3. **Reasons:** count each reason per person (one person can give two):
   ```sql
   SELECT r, count(DISTINCT person_id) FROM events
   ARRAY JOIN JSONExtractArrayRaw(properties.reasons) AS r
   WHERE event = 'saver_survey_answered' GROUP BY r ORDER BY 2 DESC
   ```
   A reason counts as a **signal only when 3 or more different people pick it**. Fewer than
   that is an anecdote to follow up in E9.
4. **Did the answer move anything:** for each person, `mark_been` or `directions_tapped` within
   14 days of `answered` vs of `skipped`, and `followup_tapped` ÷ `followup_shown` by `kind`.
   At this size it is a yes/no per person, not a lift. "Someone who saw the open-state card went
   within a week" is worth knowing and proves nothing.
5. **Pool health:** `saver_survey_suppressed` by reason. If most eligible savers are
   `recent_been`, the problem is smaller than feared (they are visiting).

**When it is meaningful:** with about 30 answers from different people, a reason picked by half
of them has a 95% interval of roughly ±17 points. That is enough to say "this is the top
reason" when one reason doubles the next. At today's eligibility, that is months away, which is
why point 2 above uses counts and the plan's E9 conversations carry the Nov 11 decision.

## To test with real people

| Question | Method | Exact task or prompt | Success |
|---|---|---|---|
| Do savers recognize which cafe they're being asked about, with and without the name? | Five-second test, both versions | "What is this asking you about?" | 4/5 name the cafe (named version); note how many can't (current) |
| Is "Saving it for later" a real, common answer, and is the list missing one? | 5 short calls with savers (E9) | "You saved X and haven't gone yet. What's kept you?" before showing the list, then show it | Their unprompted reason maps to a row for 4 of 5 |
| Does the open-state or nearest card feel helpful or pushy? | 5-person task test, think aloud | "Answer this as you really would", then watch the card | No one calls it a sales push; 2+ tap through |
| Is app open the right moment, or is it in the way? | The same sessions | Open the app with the forced flag while they have a task ("find a cafe for tonight") | They answer or skip in under 10s and finish the task |
| Does a helpful follow-up lead to a visit? | Analytics, HEART "task success" | Goal: a saver goes. Signal: `mark_been` / `directions_tapped` within 14 days. Event: `saver_survey_followup_tapped {kind}` | Any follow-up tapper who visits; read per person until ~30 |
