# Saves left on a shared phone · UX research (2026-10-19)

## Question
What should happen when someone signs in on a phone that holds saves left by a *different*
account (one whose merge failed), without moving one person's saves into another person's
account?

- Product: a cafe listing and saving app, similar to Pocket, Pinterest boards and Airbnb wishlists.
- People: a person signing in on a phone that may be shared. When I sign in, I want my own saves
  in my account, so another person's cafes don't end up in my lists.
- Journey: sign in, then saves left on the phone, then decide, then see what moved.
- Evidence: the code (`GuestSavesSync`, `GuestSavesMerger`) and widget tests. There is no
  analytics yet: `guest_saves_merge_asked` and `guest_saves_merge_answered` are new.

## Journey today (after this change)
1. Sign in (Google, Apple or email). Saves made while signed out, and saves an earlier failed merge
   into this same account left, move automatically.
2. If saves left by another account remain, about 0.6 s later, and after any open sheet closes, the
   ask appears: "Add 3 saved cafes?" with "Flavour Coffee, Three Two Brew and 1 more were saved
   on this phone before. Add them to your account?", then **Add them** and **Not now**.
3. Add them: the saves move, and one toast covers everything that moved ("Moved 4 cafes to your
   account", with View). Not now or a swipe: the saves stay on the phone and still belong to the
   other account. The ask does not come back in this session, and comes back once on the next sign-in.
4. After a sign-out, everything still on the phone shows as guest saves again.

Single-rater scores (PURE): step 1 is 1, step 2 is 1, step 3 is 1, for a total of 3. Before this
change the journey had no step 2. The other account's saves moved silently, which costs the person
nothing at the time, but they find a stranger's cafes in their lists later.

## How others do it
Sheets in `ux-merge-ask/` (screenshots of other products, gitignored).
- **Structured** (task planner): opt-in "Structured Cloud". Before sign-in it says existing tasks
  will migrate and that you can revert. It then shows Syncing and Fully Synced.
- **Tripsy** (trip planner): starts from a "Save your trips" card. After sign-in the modal closes
  and the account's trips appear in the list, with no summary.
- **Binge** (TV tracker): one tap through the Sign in with Apple sheet. Watched counts on the
  account card confirm it worked.
- Pattern: the local data moves into the account, and the result shows as the list itself.
  Split: only Structured says the move will happen before it does. None offers a keep-separate
  choice or shows a count of what moved. Nook's case (data from *another* account) has no
  reference.

## Findings
1. **Moderate · code · step 2: no way to recognise the saves.** The first version gave only a
   count. On a shared phone the decision is "are these mine?", and a count does not answer it.
   The person would have to remember what they saved, which means recall, not recognition. The
   references show the items themselves (Tripsy's list, Binge's counts). **Changed:** the reason
   line names up to two cafes, then "and N more".
2. **Moderate · inferred · after step 3: no way to add them later in this session.** After Not
   now, the saves can only be added at the next sign-in, or by hand as guest saves after a sign-out.
   **Left:** an entry point on the Saved tab (for example "3 cafes on this phone · Add") would
   fix it, but it is a new surface. It is listed for the user to decide.
3. **Minor · code · step 3: the toast for the automatic part waits for the answer.** When there is
   also something to ask, the "Moved N cafes" toast comes after the ask, as one combined toast,
   instead of a toast that the sheet then covers. **Kept on purpose.**
4. **Minor · code · step 2: the ask must not stack.** It waits for any open sheet or dialog to close
   (`PopupRoute` on top), then takes the session's ask budget so no other pushed sheet follows it.
   **Done**, and covered by a widget test.

## Recommended flow
As in "Journey today". The change from the first build is the named cafes in step 2 (step score
unchanged at 1, with an easier decision). Finding 2 is a possible next step.

## To test with real people
| Question | Method | Task | Success |
|---|---|---|---|
| Do people on a shared phone recognise whose saves these are? | 5-person task test | "Sign in on this phone your sibling used. What do you do with the sheet?" | They name the cafes as theirs or not before choosing |
| Is "Not now" read as "keep on the phone" rather than "delete"? | 5-person task test | After Not now, "where are those cafes now?" | Says "still on this phone" |
| How often does this happen? | Analytics (HEART: task success) | `guest_saves_merge_asked`, `guest_saves_merge_answered.answer` | Asked rarely; add vs not_now split known |
