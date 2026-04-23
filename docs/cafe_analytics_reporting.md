# Cafe analytics (`cafe_events`)

## Mobile client

Inserts are performed by [`AnalyticsService`](../lib/core/analytics/analytics_service.dart): one session id per app process, `user_id` when logged in, and optional `metadata` (e.g. `screen`, `map_app`, coordinates for directions).

## Core funnel (Superadmin / owner dashboard)

Prioritize these four `event_type` values as the **owner-facing funnel** when building a superadmin or cafe-owner dashboard:

| Stage | `event_type` | Meaning |
|--------|----------------|---------|
| **Awareness** | `view_details` | User opened the cafe profile (brand interest). |
| **Intent** | `check_hours` | User expanded **Hours** on the detail screen (planning a visit). |
| **Conversion (leads)** | `get_directions` | User committed to opening maps / directions. |
| **Loyalty** | `save_to_favorites` | User saved the cafe (repeat-interest signal). |

**Pitch framing**

- **Leads generated:** count `get_directions` + `check_hours` (strong visit intent).
- **Brand interest:** count `view_details` + `save_to_favorites`.

Constants on the client: `AnalyticsService.viewDetails`, `.checkHours`, `.getDirections`, `.saveToFavorites`.

## Example SQL (service role / dashboard)

```sql
-- Core funnel counts per cafe (last 30 days)
SELECT
  cafe_id,
  COUNT(*) FILTER (WHERE event_type = 'view_details') AS views,
  COUNT(*) FILTER (WHERE event_type = 'check_hours') AS hours_checks,
  COUNT(*) FILTER (WHERE event_type = 'get_directions') AS directions,
  COUNT(*) FILTER (WHERE event_type = 'save_to_favorites') AS saves
FROM cafe_events
WHERE created_at > now() - interval '30 days'
GROUP BY cafe_id;
```

## RLS note

If `SELECT` on `cafe_events` is restricted to `auth.uid() = user_id`, owner dashboards should use a **privileged** path (service role, Edge Function, or SQL in the Supabase dashboard), not the anon app client.

## Manual QA

1. Open cafe details → `view_details`.
2. Expand **Hours** → `check_hours`.
3. Tap **Get Directions** (after valid coordinates / map choice) → `get_directions`.
4. Heart / save favorite (logged in) → `save_to_favorites`.
