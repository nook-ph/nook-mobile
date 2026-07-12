# UGC Compliance — Supabase Deployment Map

Everything the mobile UGC work needs on the backend, and exactly where each
piece goes. Apply in this order.

## 1. SQL migration (version-controlled)
**File:** `nook-admin/supabase/migrations/20260713000000_user_blocking_and_report_ingestion.sql`
**Apply:** from the `nook-admin` repo run `supabase db push`, or paste the file
into **Supabase Dashboard → SQL Editor** and run it.

Creates, all in schema `public`:
| Object | Type | Notes |
|---|---|---|
| `blocked_users` | table | `(blocker_id, blocked_id)` PK, FKs → `profiles(id)`, `created_at` |
| `blocked_users_blocked_id_idx` | index | fast "who blocked author X" |
| `blocked_users_select_own` / `_insert_own` / `_delete_own` | RLS policies | `auth.uid() = blocker_id` |
| `review_reports_insert_own` | RLS policy | lets a user file a report (`reporter_id = auth.uid()`, `reporter_type='user'`, `status='pending'`) |
| `review_reports_select_own` | RLS policy | user can see reports they filed |
| `is_author_blocked_by(uuid, uuid)` | function | `SECURITY DEFINER`, used by feed filtering; `GRANT EXECUTE` to `authenticated, service_role` |

## 2. DB function edit — MANUAL (not in any repo)
**Object:** `get_reviews_with_vote_status` RPC
**Where it lives:** only in the live project — **Dashboard → Database →
Functions** (or `supabase db dump --schema public`). It is **not** in git.

**Change:** add one predicate to its `WHERE` clause so blocked authors drop out
server-side (client already filters immediately; this is defense-in-depth):
```sql
AND NOT public.is_author_blocked_by(r.user_id, p_user_id)
```
(`r` = the reviews alias, `p_user_id` = the caller-id parameter it already
takes.) Dump the current body first, add the line, re-run `CREATE OR REPLACE`.
Step-by-step is in the migration file's §4 comment.

## 3. Edge function edit + redeploy
**Function:** `delete-user` (invoked by the app at
`supabase_auth_remote_data_source.dart:158`).
**Where it lives:** deployed in Supabase; **source is not version-controlled**
(there is no `nook-admin/supabase/functions/delete-user/` dir — only
invite/stamp functions exist there). The reference implementation is
`nook-mobile/docs/backend/delete-user-edge-function.ts` (already updated).

**Change:** add the two `blocked_users` cleanup lines (alongside the existing
`review_reports` / `review_moderation_actions` deletes):
```ts
await supabaseAdmin.from('blocked_users').delete().eq('blocker_id', userId)
await supabaseAdmin.from('blocked_users').delete().eq('blocked_id', userId)
```
**Deploy:** edit in **Dashboard → Edge Functions → delete-user**, or create
`nook-admin/supabase/functions/delete-user/index.ts` from the doc and run
`supabase functions deploy delete-user`.

## Nothing else changes
- `review_reports`, `review_moderation_actions`, `profiles.is_suspended`, and
  the `mod_*` RPCs already exist (migration `20260607120000_moderation_actions.sql`).
- The nook-admin moderation queue already reads/acts on `review_reports` — once
  step 1 is applied, mobile reports start arriving there.

## Post-deploy smoke test
1. From the app, report a review → row appears in `review_reports` (status `pending`).
2. Block a user → row in `blocked_users`, an auto-filed report, review vanishes from the feed.
3. Delete a test account that had blocks → `blocked_users` rows for it are gone.
