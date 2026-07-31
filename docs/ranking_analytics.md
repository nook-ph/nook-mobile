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

## The two numbers that matter

### North star — % of new users who rank ≥ 1 cafe on day 1

STICKY_FEATURES.md Phase 0. Not "viewed a cafe", not "created a list" — the whole point
is a meaningful action completed in session one.

```sql
SELECT
  toDate(person.properties.signup_date) AS signup_day,
  count(DISTINCT person_id) AS activated,
  count(DISTINCT person_id) / (
    SELECT count(DISTINCT id)
    FROM persons
    WHERE toDate(properties.signup_date) = signup_day
  ) AS activation_rate
FROM events
WHERE event = 'rank_completed'
  AND toDate(timestamp) = toDate(person.properties.signup_date)
  AND timestamp >= now() - INTERVAL 60 DAY
GROUP BY signup_day
ORDER BY signup_day
```

Judge this on 4+ weeks of cohorts, never a single week — at ~40 WAU every weekly figure
is noise (STICKY caveats).

### Guard — comparisons per completed ranking (p50)

The spec's fatigue tripwire. Beli's top complaint is that ranking gets tedious; the
mitigation is bucket-first with a hard cap of 4. **If p50 drifts above ~4, the cap and
per-dimension scoping need revisiting.**

```sql
SELECT
  toStartOfWeek(timestamp) AS week,
  quantile(0.5)(comparisons) AS p50,
  quantile(0.9)(comparisons) AS p90
FROM (
  SELECT
    person_id,
    toStartOfWeek(timestamp) AS timestamp,
    countIf(event = 'rank_comparison_answered') AS comparisons
  FROM events
  WHERE event IN ('rank_comparison_answered', 'rank_completed')
    AND timestamp >= now() - INTERVAL 90 DAY
  GROUP BY person_id, $session_id, timestamp
)
GROUP BY week
ORDER BY week
```

## Dashboard: "Ranking loop"

1. **Activation rate, day 1** — the north-star query above, line chart by week.
2. **Comparisons per ranking, p50/p90** — the guard query, line chart by week, with a
   marker at 4.
3. **Funnel** `mark_been` → `rank_bucket_chosen` → `rank_completed`, 1-day window.
   Step 1→2 is how many people the bucket sheet loses; 2→3 is how many the comparisons
   lose. These two drop-offs are what the flow's skip paths exist to keep small.
4. **Bucket mix** — `rank_bucket_chosen` broken down by `bucket`. If almost everything
   is `liked`, the bands are compressed and the scores stop discriminating.
5. **Skip rate** — `rank_skipped` ÷ `rank_bucket_chosen`. High means the comparisons are
   being dodged rather than answered, which is fatigue arriving early.
6. **Ranked cafes per user** — `rank_completed` count per person, distribution. The
   personal list only becomes an asset with depth; a mode of 1 means it never does.

Keep #1 and #2 at the top. The rest are diagnostics for when those two move.
