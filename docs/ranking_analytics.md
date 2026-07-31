# Ranking — analytics

Instrumentation for the comparison-based ranking loop
([RANKING_DESIGN.md](https://github.com/nook-ph/nook-supabase/blob/main/docs/RANKING_DESIGN.md) §5.2.5).
The spec is explicit that this gets set up **before** the loop ships, not after —
without it the release tells you nothing.

Everything below goes through `AnalyticsService` → PostHog. Note `kAnalyticsEnabled`
(`lib/core/analytics/analytics_config.dart`): events only leave the device in release
builds, so none of these fire from `flutter run`. To smoke-test instrumentation
locally:

```sh
flutter run --dart-define=NOOK_FORCE_ANALYTICS=true
```

## Events

Every event carries `cafe_id`. The ranking events also carry `screen: 'cafe_details'`.

| Event | Fires when | Extra properties |
|---|---|---|
| `rank_bucket_chosen` | A feeling is picked in step 1 | `bucket` — `liked` \| `fine` \| `disliked` |
| `rank_comparison_answered` | One head-to-head is answered | `comparison_index` (1-based), `preferred_new` (bool — did the cafe being ranked win) |
| `rank_skipped` | "Too close — skip" | `comparisons_answered` |
| `rank_completed` | The score is written and revealed | `bucket`, `score`, `position` |
| `mark_been` | Been is set | — |
| `mark_want_to_try` | Want to Try is set | — |
| `unmark_status` | Either is cleared | — |

`rank_completed` is the activation event. A bucket with no comparisons still emits it
(first cafe in a bucket lands at the band midpoint), which is intended — the payoff
fires either way.

### Person properties

`signup_date` — set once at identify from the Supabase `user.created_at`, **not**
PostHog's own person `created_at`. PostHog's is when the device was first seen, which
for a reinstall or a second device is a different day, and day-1 activation is measured
against the real account age.

## Dashboard

**[Nook — Ranking loop](https://us.posthog.com/project/473868/dashboard/1934617)** — built
and live. Every tile reads empty until the ranking release ships, which is the point: the
baseline starts the day it lands rather than being reconstructed afterwards.

All tiles exclude emulator traffic (`$is_emulator = false`), matching the convention on
the existing "Nook — Product Health" dashboard.

### The two that matter

| Tile | Reads |
|---|---|
| [Activation — % of new users who rank a cafe on day 1](https://us.posthog.com/project/473868/insights/CtJW2SKw) | The Phase 0 north star. Cohorted by signup week off `signup_date`. Judge on 4+ weeks of cohorts, never a single week — at ~40 WAU every weekly figure is noise. Goal line at 25%. |
| [Fatigue guard — comparisons per ranking session (p50 / p90)](https://us.posthog.com/project/473868/insights/Dp1YZiro) | The tripwire. Goal line at 4: **if p50 drifts above it, the cap and per-dimension scoping need revisiting.** |

### Diagnostics, for when those two move

| Tile | Reads |
|---|---|
| [Ranking funnel — Been → bucket → score](https://us.posthog.com/project/473868/insights/ikcsMBWa) | 1→2 is what the bucket sheet costs, 2→3 what the comparisons cost. Both steps are skippable by design, so some drop-off is the price of the skip paths. |
| [Bucket mix](https://us.posthog.com/project/473868/insights/zPrNDtd1) | Everything in `liked` means the 7.0–10.0 band does all the work and scores stop discriminating. |
| [Skip rate](https://us.posthog.com/project/473868/insights/pONrELIq) | Feeling tapped, head-to-heads bailed. Climbing = fatigue arriving early. Read with the p50 guard, not alone. |
| [Ranked cafes per user](https://us.posthog.com/project/473868/insights/p29RkZyx) | Whether the list is becoming an asset. Piled at 1 means people try it once and the "My Cebu Cafes" thesis isn't landing. |

### Activation query

Kept here because it's the one worth understanding before trusting the number. The
right-hand side is pre-aggregated to one row per person so the join stays small, and the
join is equality-only — HogQL forbids relational operators in `JOIN`, so the day-1 window
is applied in the aggregate instead.

```sql
SELECT
    toStartOfWeek(toDate(p.properties.signup_date), 1) AS cohort_week,
    count(DISTINCT p.id) AS signed_up,
    count(DISTINCT if(dateDiff('day', toDate(p.properties.signup_date), toDate(r.first_rank)) <= 1, p.id, NULL)) AS activated,
    round(100.0 * count(DISTINCT if(dateDiff('day', toDate(p.properties.signup_date), toDate(r.first_rank)) <= 1, p.id, NULL)) / count(DISTINCT p.id), 1) AS activation_pct
FROM persons AS p
LEFT JOIN (
    SELECT person_id, min(timestamp) AS first_rank
    FROM events
    WHERE event = 'rank_completed'
      AND timestamp >= now() - INTERVAL 180 DAY
    GROUP BY person_id
) AS r ON r.person_id = p.id
WHERE p.properties.signup_date IS NOT NULL
GROUP BY cohort_week
ORDER BY cohort_week
```

**This reads zero until `signup_date` is populated**, which only happens on identify from
a release build carrying the change. Users who signed up before it shipped never get the
property backfilled, so the first few cohorts will be thin — expected, not a bug.
