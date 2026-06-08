# Crawl

> **Status:** ✅ Domain & Data Layer Complete — Presentation layer not yet started
> **Last updated:** 2026-06-08

---

## 1. Overview

Crawls are time-bound, multi-stop cafe tours that users can register for and
complete by visiting stops and claiming stamps. Each crawl is divided into
**tiers** (geographic or thematic groupings like "City Explorer" or "Island
Run"), and completing a tier awards the user an **achievement**.

The feature is built across two locations:

- **`lib/features/crawl/`** — Core crawl domain (entities, tiers, stamps, registration)
- **`lib/core/achievements/`** — Cross-feature achievement system (shared by crawls, drops, social, milestones)

Only the **domain** and **data** layers exist. No UI, BLoC, Cubit, page, or
widget has been created yet.

---

## 2. User Stories

> As a **user**, I want to **browse active crawls** so that **I can discover new cafe tours**.

> As a **user**, I want to **register for a crawl** so that **I can start collecting stamps at its stops**.

> As a **user**, I want to **claim a stamp by checking in at a stop** so that **my progress is recorded**.

> As a **user**, I want to **complete tiers and earn achievements** so that **my crawl progress is rewarded**.

> As a **user**, I want to **view my crawl progress and share a recap card** so that **I can share my experience**.

---

## 3. Feature Structure

```
lib/
├── features/crawl/
│   ├── data/
│   │   ├── models/
│   │   │   ├── crawl_model.dart
│   │   │   ├── crawl_tier_model.dart
│   │   │   ├── crawl_stop_model.dart
│   │   │   ├── crawl_detail_model.dart
│   │   │   ├── crawl_progress_model.dart
│   │   │   ├── crawl_stamp_model.dart
│   │   │   ├── stamp_claim_result_model.dart
│   │   │   └── crawl_share_card_model.dart
│   │   ├── sources/
│   │   │   └── crawl_remote_data_source.dart
│   │   └── repositories/
│   │       └── crawl_repository_impl.dart
│   └── domain/
│       ├── entities/
│       │   ├── crawl.dart                   + CrawlStatus enum
│       │   ├── crawl_tier.dart
│       │   ├── crawl_stop.dart
│       │   ├── crawl_detail.dart
│       │   ├── crawl_progress.dart
│       │   ├── crawl_stamp.dart
│       │   ├── stamp_claim_result.dart      + TierCompletionResult
│       │   └── crawl_share_card_data.dart   + CrawlStopShareItem
│       ├── failures/
│       │   └── crawl_failures.dart
│       ├── repositories/
│       │   └── i_crawl_repository.dart
│       └── use_cases/
│           ├── get_active_crawls_usecase.dart
│           ├── get_crawl_detail_usecase.dart
│           ├── register_for_crawl_usecase.dart
│           ├── claim_stamp_usecase.dart
│           └── get_share_card_data_usecase.dart
│
└── core/
    ├── achievements/
    │   ├── data/
    │   │   ├── models/
    │   │   │   ├── achievement_definition_model.dart
    │   │   │   └── user_achievement_model.dart
    │   │   ├── sources/
    │   │   │   └── achievement_remote_data_source.dart
    │   │   └── repositories/
    │   │       └── achievement_repository_impl.dart
    │   └── domain/
    │       ├── entities/
    │       │   ├── achievement_definition.dart  + AchievementCategory enum
    │       │   └── user_achievement.dart
    │       ├── repositories/
    │       │   └── i_achievement_repository.dart
    │       └── use_cases/
    │           └── get_user_achievements_usecase.dart
    └── errors/
        └── failure.dart
```

---

## 4. Domain Entities

All entities live in `domain/entities/`. They are pure Dart with zero Flutter
or Supabase imports.

| Entity | Key Fields | Notes |
|---|---|---|
| `Crawl` | `id`, `title`, `slug`, `startsAt`, `endsAt`, `status`, `city`, `totalStops` | `daysRemaining` is a computed getter |
| `CrawlTier` | `crawlId`, `slug`, `name`, `tierOrder`, `requiredTierTags`, `totalRequired`, `totalClaimed`, `isComplete` | Progress fields populated by RPC with user context |
| `CrawlStop` | `cafeId`, `cafeName`, `cafeAddress`, `cafeLat`, `cafeLng`, `stopOrder`, `tier`, `isClaimed`, `claimedAt` | Embeds cafe fields directly — no `CafeSummary` dependency |
| `CrawlDetail` | `crawl`, `isRegistered`, `userProgress?`, `stops[]`, `tiers[]` | Composite returned by `getCrawlBySlug` |
| `CrawlProgress` | `totalStamps`, `highestTier?`, `stamps[]` | `highestTier` is the full `CrawlTier` entity |
| `CrawlStamp` | `stopId`, `cafeName`, `claimedAt`, `claimMethod`, `isVerified` | Flat fields, no cafe entity |
| `StampClaimResult` | `stamp`, `totalStamps`, `tierCompletion?` | Returned by `claimStamp` |
| `TierCompletionResult` | `tierId`, `tierSlug`, `tierName`, `achievementId`, `badgeImageUrl`, `earnedAt` | Non-null when a tier was just completed |
| `CrawlShareCardData` | `userName`, `crawlTitle`, `crawlPeriod`, `totalStamps`, `totalStops`, `highestTier?`, `stops[]` | For share card rendering |
| `AchievementDefinition` | `slug`, `name`, `category`, `sourceType`, `sourceId`, `badgeImageUrl`, `isHidden` | Cross-feature; `category` enum: `crawl`, `drops`, `social`, `milestones`, `hidden` |
| `UserAchievement` | `userId`, `definition`, `earnedAt`, `sourceType`, `metadata`, `isVisible` | Has the full `AchievementDefinition` (composition) |

### CrawlStatus enum

```
draft → active → completed
                   → cancelled
```

---

## 5. Failure Types

**File:** `features/crawl/domain/failures/crawl_failures.dart`

Base class extracted to `core/errors/failure.dart`.

| Failure | Fields | Source |
|---|---|---|
| `LocationTooFarFailure` | `distanceMeters: int` | RPC returns `location_too_far` |
| `AlreadyClaimedFailure` | `claimedAt: DateTime` | RPC returns `already_claimed` |
| `CrawlEndedFailure` | — | RPC returns `crawl_ended` |
| `StopInactiveFailure` | — | RPC returns `stop_inactive` |
| `AlreadyRegisteredFailure` | — | Unique constraint on insert |
| `CrawlNotFoundFailure` | — | Slug resolves to nothing |

---

## 6. Repository Interfaces

### `ICrawlRepository` (`features/crawl/domain/repositories/`)

| Method | Returns | Notes |
|---|---|---|
| `getActiveCrawls()` | `Either<Failure, List<Crawl>>` | Filters `status = 'active'` |
| `getCrawlBySlug(String slug)` | `Either<Failure, CrawlDetail>` | Delegates to `get_crawl_detail` RPC |
| `registerForCrawl(String crawlId)` | `Either<Failure, Unit>` | Inserts `crawl_registrations` |
| `claimStamp(crawlId, stopId, lat, lng)` | `Either<Failure, StampClaimResult>` | Core mechanic — all validation on server |
| `getShareCardData(String crawlId)` | `Either<Failure, CrawlShareCardData>` | Delegates to `get_crawl_share_card` RPC |

### `IAchievementRepository` (`core/achievements/domain/repositories/`)

| Method | Returns | Notes |
|---|---|---|
| `getUserAchievements(String userId)` | `Either<Failure, List<UserAchievement>>` | Ordered by `earned_at DESC`, only `is_visible = true` |

---

## 7. Use Cases

| Use Case | Input | Output | Delegates To |
|---|---|---|---|
| `GetActiveCrawlsUseCase` | — | `List<Crawl>` | `repository.getActiveCrawls()` |
| `GetCrawlDetailUseCase` | `slug: String` | `CrawlDetail` | `repository.getCrawlBySlug(slug)` |
| `RegisterForCrawlUseCase` | `crawlId: String` | `Unit` | `repository.registerForCrawl(crawlId)` |
| `ClaimStampUseCase` | `crawlId`, `stopId`, `lat`, `lng` | `StampClaimResult` | `repository.claimStamp(...)` |
| `GetShareCardDataUseCase` | `crawlId: String` | `CrawlShareCardData` | `repository.getShareCardData(crawlId)` |
| `GetUserAchievementsUseCase` | `userId: String` | `List<UserAchievement>` | `repository.getUserAchievements(userId)` |

---

## 8. Data Layer

### Data Source

**File:** `features/crawl/data/sources/crawl_remote_data_source.dart`

`CrawlRemoteDataSourceImpl` takes `SupabaseClient` and implements
`ICrawlRemoteDataSource`. All methods wrap calls in try/catch and throw typed
exceptions (`CrawlDataSourceException`, `LocationTooFarException`, etc.).

| Method | Supabase Call | Notes |
|---|---|---|
| `getActiveCrawls()` | `supabase.from('crawls').select().eq('status', 'active')` | Ordered by `starts_at` ascending |
| `getCrawlBySlug(slug, userId)` | `supabase.rpc('get_crawl_detail', ...)` | RPC returns full denormalized shape |
| `registerForCrawl(crawlId)` | `supabase.from('crawl_registrations').insert(...)` | Catches unique violation (23505) → `AlreadyRegisteredException` |
| `claimStamp(crawlId, stopId, lat, lng)` | `supabase.rpc('claim_crawl_stamp', ...)` | Parses structured error codes from RPC |
| `getShareCardData(crawlId, userId)` | `supabase.rpc('get_crawl_share_card', ...)` | RPC returns share card shape |

### Repository Implementation

**File:** `features/crawl/data/repositories/crawl_repository_impl.dart`

Wraps data source calls in try/catch, maps typed exceptions from the data
source to the corresponding `Failure` subclass from `crawl_failures.dart`.
General exceptions map to a generic `Failure(message)`.

### Models

All models extend their entity counterpart (e.g., `CrawlModel extends Crawl`).
Each has a `factory ModelName.fromJson(Map<String, dynamic> json)` with safe
type coercion helpers (`_asString`, `_asInt`, `_asDouble`, `_asBool`,
`_asDateTime`, `_asNullableDateTime`, `_asStringList`, `_asNullableMap`).

Pattern follows `CafeSummaryModel` — see `core/cafe/data/cafe_summary_model.dart`.

---

## 9. Supabase

### Tables

| Table | Purpose | Key Constraints |
|---|---|---|
| `crawls` | Crawl metadata and schedule | `slug UNIQUE`, `status CHECK (draft, active, completed, cancelled)` |
| `crawl_tiers` | Tier definitions per crawl | `UNIQUE (crawl_id, slug)`, `UNIQUE (crawl_id, tier_order)` |
| `crawl_stops` | Stops (cafe + order + tier tag) per crawl | `UNIQUE (crawl_id, cafe_id)`, `UNIQUE (crawl_id, stop_order)` |
| `crawl_registrations` | User registration + progress per crawl | `UNIQUE (crawl_id, user_id)` |
| `crawl_stamps` | Individual stamp claims | `UNIQUE (stop_id, user_id)` |
| `achievement_definitions` | Global achievement catalog | `slug UNIQUE` |
| `user_achievements` | Per-user earned achievements | `UNIQUE (user_id, achievement_id)` |

### RPCs

#### `get_crawl_detail(p_slug, p_user_id)`

Returns a JSON object with:
- `crawl` — all crawl fields
- `is_registered` — boolean
- `progress` — `{ total_stamps, highest_tier, stamps[] }` or null
- `stops` — ordered list with `cafe_name`, `cafe_address`, `cafe_lat`, `cafe_lng`, `is_claimed`, `claimed_at`
- `tiers` — ordered list with `total_required`, `total_claimed`, `is_complete`

Security: `SECURITY INVOKER` — respects RLS.

#### `claim_crawl_stamp(p_crawl_id, p_stop_id, p_lat, p_lng)`

Server-side validation pipeline:
1. Validate crawl is active + within date range → `crawl_ended`
2. Validate stop belongs to crawl + `is_active = true` → `stop_inactive`
3. Auto-register user if not registered (`ON CONFLICT DO NOTHING`)
4. Check `UNIQUE (stop_id, user_id)` → `already_claimed` + `claimed_at`
5. Compute Haversine distance → `location_too_far` + `distance_meters` if > 200m
6. Insert stamp (`is_verified = true`)
7. Increment `total_stamps`, set `last_stamp_at`
8. Loop tiers by `tier_order` — if all required tag-matched stops are claimed:
   - Set `highest_tier_id`
   - Set `completed_at` if final tier
   - Insert `user_achievements` (`ON CONFLICT DO NOTHING`)
9. Return `{ stamp, total_stamps, tier_completion }`

Security: `SECURITY INVOKER` — respects RLS.

#### `get_crawl_share_card(p_crawl_id, p_user_id)`

Returns:
- `user_name`, `crawl_title`, `crawl_period`
- `total_stamps`, `total_stops`
- `highest_tier` or null
- `stops[]` with `cafe_name`, `cafe_lat`, `cafe_lng`, `is_claimed`, `claimed_at`

Security: `SECURITY INVOKER` — respects RLS.

---

## 10. DI Registration

All registered as lazy singletons in `lib/injection_container.dart` in the
"Future features registration area" section, following this ordering:

```
data sources → repositories → use cases
```

```
ICrawlRemoteDataSource → CrawlRemoteDataSourceImpl
ICrawlRepository       → CrawlRepositoryImpl
GetActiveCrawlsUseCase
GetCrawlDetailUseCase
RegisterForCrawlUseCase
ClaimStampUseCase
GetShareCardDataUseCase

IAchievementRemoteDataSource → AchievementRemoteDataSourceImpl
IAchievementRepository       → AchievementRepositoryImpl
GetUserAchievementsUseCase
```

---

## 11. Key Constraints & Business Rules

| Rule | Enforced Where |
|---|---|
| One stamp per user per stop | `UNIQUE (stop_id, user_id)` + RPC returns `already_claimed` |
| One registration per user per crawl | `UNIQUE (crawl_id, user_id)`; auto-register in RPC |
| GPS required — no bypass | RPC validates Haversine distance ≤ 200m |
| Only active crawls are claimable | RPC checks `status = 'active'` + date range |
| Inactive stops cannot be claimed | RPC checks `is_active = true` |
| Stamps are never deleted | No DELETE methods anywhere on stamps or achievements |
| No optimistic stamp award | Only return success after server confirms |
| Tier completion is data-driven | Read from `crawl_tiers.required_tier_tags`; no hardcoded tier names |

---

## 12. Packages Used

| Package | Why |
|---|---|
| `dartz` | `Either<Failure, T>` for repository return types |
| `supabase_flutter` | All data access (tables + RPCs) |
| `get_it` | DI registration |

---

## 13. Edge Cases & Error Handling

- **Stamp already claimed** — `AlreadyClaimedFailure` with `claimedAt` timestamp
- **Location too far** — `LocationTooFarFailure` with `distanceMeters` for UI messaging
- **Crawl ended** — `CrawlEndedFailure` (status changed or past date range)
- **Stop inactive** — `StopInactiveFailure` (stop disabled by admin)
- **Already registered** — `AlreadyRegisteredFailure` (idempotent — UI should show success)
- **Crawl not found** — `CrawlNotFoundFailure` (invalid slug)
- **Not authenticated** — RPCs return `not_registered`; handled by repository
- **PostgrestException** — Generic `Failure` fallback with error message

---

## 14. Coming Soon: Presentation Layer

When implementing the presentation layer, follow these constraints:

- **No hardcoded tier slugs** (`city_explorer`, `island_run`) in Dart — they come from the DB
- **Do not duplicate `CafeSummary`/`CafeDetails`** — `CrawlStop` embeds only needed cafe fields
- **Do not create a second filter or list state** — no dependency on `FilterCubit` or `ListsBloc`
- **Use `MapsDirectionsLauncher`** (in `core/utils/`) for map directions, not `url_launcher` directly
- **No hardcoded colors** — use theme tokens from `utils/theme/`
- **Defer `stamp_template_url`** on `Crawl` entity unless the share card rendering needs it

---

## 15. Open Questions

- [ ] Confirm share card design — does it need `stamp_template_url`?
- [ ] Should share card data include the user's avatar URL?
- [ ] Finalize GPS accuracy threshold (currently 200m Haversine) — may need adjustment per crawl
- [ ] Decide whether `claimStamp` should accept a `claim_method` override (currently hardcoded to `'qr'`)
