# App Store UGC — On-Device Recording QA Checklist

Capture on a **physical device** (Apple requires it). Record the three starred
flows below and paste the video into **App Store Connect → App Review
Information → Notes**.

## Pre-flight (do these first)
- [ ] Supabase migration applied: `blocked_users` table, `review_reports`
      user-INSERT policy, `is_author_blocked_by`. Wire the block filter into
      `get_reviews_with_vote_status` (see migration §4).
- [ ] `nook-privacy` pages live and reachable at the URLs in
      `AppConstants.eulaUrl` / `privacyPolicyUrl` (open both in a browser).
- [ ] Build a **release/TestFlight** build on a real device (not simulator).
- [ ] Have **two test accounts**: Account A (reviewer/recorder) and Account B
      (writes an objectionable-looking review to report/block).
- [ ] Seed data: with Account B, post a review on a cafe so Account A has
      someone else's content to act on.
- [ ] **Fresh install** on the device before recording (delete app first) so
      the EULA gate is unchecked.

## ★ Recording 1 — EULA gate (before login/registration)
- [ ] Launch fresh; reach the email entry screen.
- [ ] Show the terms checkbox is **unchecked** and Continue + Google + Apple are
      **disabled**.
- [ ] Tap **Terms of Use (EULA)** → page opens (show the zero-tolerance text).
- [ ] Tap **Privacy Policy** → page opens.
- [ ] Check the box → show the buttons become **enabled**.
- [ ] Proceed to sign in as Account A.

## ★ Recording 2 — Flag objectionable content
- [ ] Open the cafe with Account B's review; scroll to it.
- [ ] Tap the **⋯ (more)** icon on that review → actions sheet appears.
- [ ] Tap **Report review** → reason picker appears.
- [ ] Pick a reason, add optional detail, tap **Submit report**.
- [ ] Show the confirmation ("reviewed within 24 hours").
- [ ] (Optional proof) In nook-admin, show the report now in the queue.

## ★ Recording 3 — Block an abusive user
- [ ] On Account B's review, tap **⋯** → **Block user** → confirm dialog → **Block**.
- [ ] Show the review **disappears from the feed immediately**.
- [ ] Reopen the cafe → confirm the blocked user's review stays hidden.
- [ ] Go to **Settings → Blocked Users** → show Account B listed.
- [ ] (Optional) Tap **Unblock** → show the review reappears.

## Also verify (not required on camera)
- [ ] Submit a review containing a banned word → rejected inline.
- [ ] Try a banned word as username / bio → rejected.
- [ ] In nook-admin, a report can be actioned: **remove review** + **suspend
      (eject) user** — confirm the 24-hour workflow end-to-end.

## Submit
- [ ] Trim to the three starred flows (one video or three clips).
- [ ] Upload to App Review Information → **Notes**.
- [ ] Reply to the reviewer noting the precautions are implemented.
