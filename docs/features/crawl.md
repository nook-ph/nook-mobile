# Crawl

> **Status:** ✅ Domain, Data, and Presentation layers complete. Share card fully implemented: `CrawlShareCard` composes `ShareCardStampHero`, `ShareCardStats`, and `ShareCardFooter` into a 360×640 card; `ShareCardView` uses `BlocBuilder<ShareCardCubit>` to reactively render; `ShareCardCubit` stores a `GlobalKey` internally and offers parameterless `captureAndShare()`; both `CrawlDetailPage` and `StampClaimPage` host their own `BlocProvider<ShareCardCubit>`, off-screen `RepaintBoundary`, and `ShareCardView`; `TierCompletionModal` replaced `VoidCallback onShare` with `GlobalKey shareCardKey` prop and handles loading/spinner + error SnackBar via `BlocListener`.
> **Last updated:** 2026-06-12

---

## 1. Overview

Crawls are time-bound, multi-stop cafe tours that users can register for and
complete by visiting stops and claiming stamps. Each crawl is divided into
**tiers** (geographic or thematic groupings like "City Explorer" or "Island
Run"), and completing a tier awards the user an **achievement**.

The feature is built across two locations:

- **`lib/features/crawl/`** — Core crawl domain (entities, tiers, stamps, registration)
- **`lib/core/achievements/`** — Cross-feature achievement system (shared by crawls, drops, social, milestones)

The **domain**, **data**, and **presentation** layers are all complete. The crawl detail page (`CrawlDetailPage`) has been fully implemented with a sticky CTA, registration toast, pull-to-refresh, and auto-refresh on route re-entry. The crawl stops map page (`CrawlStopsMapPage`) is fully implemented with an interactive MapLibre map, pin markers, symbol tapping, and a slide-up cafe overlay card. The stamp claim page (`StampClaimPage`) is fully implemented with GPS acquisition, stamp animation, and tier completion flow. The passport page (`PassportPage`) remains a placeholder UI pending further work.

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
│   ├── domain/
│   │   ├── entities/
│   │   │   ├── crawl.dart                   + CrawlStatus enum
│   │   │   ├── crawl_tier.dart
│   │   │   ├── crawl_stop.dart
│   │   │   ├── crawl_detail.dart
│   │   │   ├── crawl_progress.dart
│   │   │   ├── crawl_stamp.dart
│   │   │   ├── stamp_claim_result.dart      + TierCompletionResult
│   │   │   └── crawl_share_card_data.dart   + CrawlStopShareItem
│   │   ├── failures/
│   │   │   └── crawl_failures.dart
│   │   ├── repositories/
│   │   │   └── i_crawl_repository.dart
│   │   └── use_cases/
│   │       ├── get_active_crawls_usecase.dart
│   │       ├── get_crawl_detail_usecase.dart
│   │       ├── register_for_crawl_usecase.dart
│   │       ├── claim_stamp_usecase.dart
│   │       └── get_share_card_data_usecase.dart
│   └── presentation/
│       ├── bloc/
│       │   ├── crawl_claim_bloc.dart
│       │   ├── crawl_claim_event.dart
│       │   └── crawl_claim_state.dart
│       ├── cubit/
│       │   ├── active_crawls_cubit.dart
│       │   ├── active_crawls_state.dart
│       │   ├── crawl_detail_cubit.dart
│       │   ├── crawl_detail_state.dart
│       │   ├── crawl_stops_map_cubit.dart          # Loads CafeSummary data for stops map
│       │   ├── crawl_stops_map_state.dart          # sealed: Initial, Loading, Loaded, Error
│       │   ├── share_card_cubit.dart               # Loads data & handles capture/share
│       │   └── share_card_state.dart               # sealed: Initial, Loading, Ready, Capturing, Shared, Error
│       ├── pages/
│       │   ├── stamp_claim_page.dart        # Fully implemented — GPS, animation, tier completion flow
│       │   ├── crawl_detail_page.dart       # Fully implemented — sticky CTA, refresh, progress card, map preview
│       │   ├── crawl_stops_map_page.dart    # Fully implemented — interactive map, pins, overlay card
│       │   └── passport_page.dart           # Placeholder UI
│       ├── widgets/
│       │   ├── crawl_detail_cta.dart        # Sticky CTA for register / claim-stop
│       │   ├── crawl_home_banner.dart       # Placeholder
│       │   ├── crawl_stops_map_preview.dart # Non-interactive mini map for detail page
│       │   ├── tier_completion_modal.dart   # Fully implemented — badge, share, continue buttons
│       │   ├── share_card/
│       │   │   ├── crawl_share_card.dart              # Full 360×640 share card composition
│       │   │   ├── share_card_stamp_hero.dart         # Stamp seal hero section of share card
│       │   │   ├── share_card_stamp_hero_preview.dart # Preview file
│       │   │   ├── share_card_stats.dart              # 3-column stat section (STOPS/LATEST/CRAWL or STOPS/TIER/CRAWL)
│       │   │   └── share_card_footer.dart             # Nook wordmark + crawl title footer
│       │   └── share_card_view.dart         # BlocBuilder bridge, renders CrawlShareCard on Ready
│       ├── deep_link/
│       │   └── crawl_deep_link_handler.dart
│       └── injection/
│           └── crawl_presentation_injection.dart

├── core/
│   ├── achievements/
│   │   ├── data/
│   │   │   ├── models/
│   │   │   │   ├── achievement_definition_model.dart
│   │   │   │   └── user_achievement_model.dart
│   │   │   ├── sources/
│   │   │   │   └── achievement_remote_data_source.dart
│   │   │   └── repositories/
│   │   │       └── achievement_repository_impl.dart
│   │   └── domain/
│   │       ├── entities/
│   │       │   ├── achievement_definition.dart  + AchievementCategory enum
│   │       │   └── user_achievement.dart
│   │       ├── repositories/
│   │       │   └── i_achievement_repository.dart
│   │       └── use_cases/
│   │           └── get_user_achievements_usecase.dart
│   ├── errors/
│   │   └── failure.dart
│   ├── presentation/
│   │   └── widgets/
│   │       ├── cafe_overlay_card.dart      # Reusable cafe card — image, name, rating, location, tags
│   │       └── slide_up_overlay.dart       # Animated slide-up wrapper (AnimatedSwitcher + SlideTransition)
│   └── services/
│       └── gps_service.dart
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
data sources → repositories → use cases → services → cubits → blocs
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

GpsService → GpsServiceImpl
ActiveCrawlsCubit
CrawlDetailCubit
CrawlClaimBloc
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
|---|---|---|
| `dartz` | `Either<Failure, T>` for repository return types |
| `supabase_flutter` | All data access (tables + RPCs) |
| `get_it` | DI registration |
| `flutter_bloc` | BLoC + Cubit state management |
| `equatable` | Value equality for state/event classes |
| `geolocator` | GPS position acquisition for stamp claiming |
| `image_gallery_saver_plus` | Save share card PNG bytes to device camera roll |
| `go_router` | Navigation, deep links, route params |
| `cached_network_image` | Cafe photo caching with `CustomCacheManager` |
| `flutter_animate` | Stamp success animation (scale + fadeIn) |
| `gap` | Spacing widgets (`Gap(4)`, `Gap(12)`, etc.) |
| `maplibre_gl` | Interactive map rendering for `CrawlStopsMapPage` and `CrawlStopsMapPreview` |
| `lucide_icons_flutter` | Map pin icons in `CafeOverlayCard`, GPS status icons (`loader`, `mapPinOff`, `circleCheckBig`) |
| `phosphor_flutter` | Star rating icon in `CafeOverlayCard` |

### Dev Dependencies

| Package | Why |
|---|---|
| `bloc_test` | Unit testing BLoC and Cubit emission sequences |
| `mockito` | Mocking use cases and services in tests |

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

## 14. Presentation Layer

### 14.1 State Management Strategy

Hybrid approach:

- **Cubit** — Simple async fetch-and-emit flows (`ActiveCrawlsCubit`, `CrawlDetailCubit`, `CrawlStopsMapCubit`)
- **BLoC** — Complex event-driven pipelines with multiple orchestration steps (`CrawlClaimBloc`)

All states use `sealed class` hierarchies for exhaustive pattern matching with Dart 3 switch expressions.

### 14.2 CrawlClaimBloc

**File:** `features/crawl/presentation/bloc/crawl_claim_bloc.dart`

Orchestrates the stamp-claim flow: acquire GPS position → validate → submit claim → map result.

**Events (3):**

| Event | Payload | Trigger |
|---|---|---|
| `ClaimInitialized` | `crawlId`, `stopId`, `crawlTitle`, `cafeName` | Page mount / deep link |
| `ClaimRetryRequested` | — | User taps retry |
| `ClaimResetRequested` | — | User closes / resets |

**States (12, sealed):**

| State | Fields | Meaning |
|---|---|---|
| `CrawlClaimInitial` | — | Idle, no claim in progress |
| `AcquiringGps` | `crawlId`, `stopId`, `crawlTitle`, `cafeName` | Waiting for GPS fix |
| `ClaimSubmitting` | `crawlId`, `stopId`, `crawlTitle`, `cafeName`, `lat`, `lng` | Submitting to server |
| `ClaimSuccess` | `result`, `crawlTitle`, `cafeName` | Stamp claimed (no tier completion) |
| `ClaimSuccessWithTierCompletion` | `result`, `tier`, `crawlTitle`, `cafeName` | Stamp claimed + tier completed |
| `GpsDenied` | — | Location permission denied |
| `GpsTimeout` | — | GPS acquisition timed out (10s) |
| `LocationTooFar` | `distanceMeters` | User >200m from stop |
| `AlreadyClaimed` | `claimedAt` | Stamp already collected |
| `CrawlExpired` | — | Crawl is no longer active |
| `StopInactive` | — | Stop disabled by admin |
| `NotRegistered` | — | User not registered for crawl |
| `ClaimNetworkError` | `failure` | Generic server/network error |

**Flow:**

```
CrawlClaimInitial
  → ClaimInitialized → AcquiringGps
    → (GPS success) → ClaimSubmitting
      → (success)           → ClaimSuccess / ClaimSuccessWithTierCompletion
      → (location_too_far)  → LocationTooFar
      → (already_claimed)   → AlreadyClaimed
      → (crawl_ended)       → CrawlExpired
      → (stop_inactive)     → StopInactive
      → (generic)           → ClaimNetworkError
    → (GPS denied)  → GpsDenied
    → (GPS timeout) → GpsTimeout

ClaimRetryRequested → (re-emits ClaimInitialized from AcquiringGps) / (resets to CrawlClaimInitial from error states)
ClaimResetRequested → CrawlClaimInitial (from any state)
```

**Dependencies:** `ClaimStampUseCase`, `GpsService`

### 14.3 ActiveCrawlsCubit

**File:** `features/crawl/presentation/cubit/active_crawls_cubit.dart`

Simple fetch cubit for the home screen crawl banner.

**States (4, sealed):**

| State | Fields | Meaning |
|---|---|---|
| `ActiveCrawlsLoading` | — | Fetch in progress |
| `ActiveCrawlsLoaded` | `crawls`, `registeredCrawlIds` | Data available |
| `ActiveCrawlsEmpty` | — | No active crawls |
| `ActiveCrawlsError` | `failure` | Fetch failed |

**Dependencies:** `GetActiveCrawlsUseCase`, `SupabaseClient` (for auth)

### 14.4 CrawlDetailCubit

**File:** `features/crawl/presentation/cubit/crawl_detail_cubit.dart`

Fetches crawl detail, handles registration, and supports refresh for pull-to-refresh / auto-refresh on re-entry.

**States (5, sealed):**

| State | Fields | Meaning |
|---|---|---|
| `CrawlDetailInitial` | — | Not loaded |
| `CrawlDetailLoading` | — | Fetch in progress |
| `CrawlDetailLoaded` | `detail` (with `totalStamps`, `totalStops`, `progressFraction` getters) | Data available |
| `CrawlDetailRegisterSuccess` | `detail` | Registration succeeded — distinct from `Loaded` so the UI layer can show a toast |
| `CrawlDetailError` | `failure` | Fetch failed |

**Methods:**
- `loadDetail(String slug)` — fetches detail, maps failures
- `register()` — calls `RegisterForCrawlUseCase`. On success, emits `CrawlDetailRegisterSuccess(detail)` after re-fetch; silently ignores `AlreadyRegisteredFailure` (re-fetches silently)
- `refresh()` — re-fetches detail from current slug. Only acts when current state is `Loaded` or `RegisterSuccess`; no-op otherwise

**Dependencies:** `GetCrawlDetailUseCase`, `RegisterForCrawlUseCase`

### 14.5 GPS Service

**File:** `core/services/gps_service.dart`

Abstract wrapper around `Geolocator` to decouple BLoC from static SDK methods.

```dart
abstract class GpsService {
  Future<GpsResult> getCurrentPosition({Duration timeout = Duration(seconds: 10)});
  Future<bool> requestPermission();
  Future<bool> isLocationEnabled();
}
```

`GpsResult` is a sealed-like value class with `position`, `denied`, and `timeout` fields. `GpsServiceImpl` handles permission checks, service checks, and timeout exceptions internally.

**Dependencies:** `geolocator`

### 14.6 CrawlStopsMapCubit

**File:** `features/crawl/presentation/cubit/crawl_stops_map_cubit.dart`

Simple fetch cubit that loads `CafeSummary` data for the crawl stops map, filtering cafes by the crawl's stop cafe IDs.

**States (4, sealed):**

| State | Fields | Meaning |
|---|---|---|
| `CrawlStopsMapInitial` | — | Not loaded |
| `CrawlStopsMapLoading` | — | Fetch in progress |
| `CrawlStopsMapLoaded` | `cafeById`, `cafes` | Cafe data available, keyed by ID |
| `CrawlStopsMapError` | `error` | Fetch failed |

**Method:**
- `loadCafes(List<CrawlStop> stops)` — calls `GetCafeCardUseCase(limit: 50)`, filters to cafes matching stop IDs, emits `Loaded` with `cafeById` map

**Dependencies:** `GetCafeCardUseCase`

Not registered in DI — created inline in `CrawlStopsMapPage` via `BlocProvider(create: ...)`.

### 14.7 ShareCardCubit

**File:** `features/crawl/presentation/cubit/share_card_cubit.dart`

Manages share card data loading and the capture-and-share flow (render → PNG → gallery → share sheet).

**States (6, sealed):**

| State | Fields | Meaning |
|---|---|---|
| `ShareCardInitial` | — | Not loaded |
| `ShareCardLoading` | — | Fetching share card data |
| `ShareCardReady` | `data` | Share card data available for rendering |
| `ShareCardCapturing` | — | Image capture in progress |
| `ShareCardShared` | — | Capture done, share sheet launched |
| `ShareCardError` | `message` | Loading or capture failed |

**Methods:**

- `loadData(String crawlId)` — emits `Loading` → calls `GetShareCardDataUseCase` → `Ready(data)` or `Error(failure.message)`
- `setShareCardKey(GlobalKey key)` — stores the `GlobalKey` internally in `_shareCardKey` for later capture
- `captureAndShare()` — no parameters; emits `Capturing` → reads `_shareCardKey` (throws if null) → finds `RenderRepaintBoundary` → `toImage(pixelRatio: 3.0)` → PNG bytes via `toByteData(ImageByteFormat.png)` → saves to gallery via `ImageGallerySaver.saveImage(bytes)` → writes temp file via `path_provider` → launches OS share sheet via `SharePlus.instance.share(ShareParams(files: [...]))` → emits `Shared`. Catches any exception and emits `Error(e.toString())`

**Capture dimensions:** 360×640 logical pixels at `pixelRatio: 3.0` → 1080×1920 output (Instagram Stories ratio).

**Share trigger:** Called from `TierCompletionModal`'s share button via `context.read<ShareCardCubit>().captureAndShare()` — no key passing needed since the cubit stores the `GlobalKey` internally.

**Note:** `ShareCardCubit` is registered as `registerFactory` in DI. Each hosting page (`CrawlDetailPage`, `StampClaimPage`) provides its own `BlocProvider<ShareCardCubit>` instance, so cubits are never shared across pages. Each page also owns its own `GlobalKey` and `RepaintBoundary`.

**Dependencies:** `GetShareCardDataUseCase`, `image_gallery_saver_plus`, `share_plus`, `path_provider`

### 14.8 Deep Link Handler

**File:** `features/crawl/presentation/deep_link/crawl_deep_link_handler.dart`

Parses deep links in the format `nook://crawl/{crawlId}/stop/{stopId}/claim`.

```dart
CrawlDeepLinkHandler.canHandle(uri)   // checks scheme + host
CrawlDeepLinkHandler.parse(uri)        // returns CrawlDeepLinkResult? 
```

Integrated in `main.dart` via `_handleIncomingLink` — rewrites URI path to GoRouter route `/crawl/:crawlId/stop/:stopId/claim`. Platform config:

- **Android:** `AndroidManifest.xml` intent filter for `nook://` scheme
- **iOS:** `Info.plist` `FlutterDeepLinkingEnabled` + `CFBundleURLTypes`

### 14.9 Pages

| Page | File | State |
|---|---|---|---|
| `StampClaimPage` | `pages/stamp_claim_page.dart` | **Fully implemented** — see details below |
| `CrawlDetailPage` | `pages/crawl_detail_page.dart` | **Fully implemented** — see details below |
| `CrawlStopsMapPage` | `pages/crawl_stops_map_page.dart` | **Fully implemented** — see details below |
| `PassportPage` | `pages/passport_page.dart` | **Placeholder** — renders placeholder text |

All pages use `sl<...>()` (GetIt) for BLoC/Cubit resolution in production, and accept an optional `bloc` parameter for test injection.

#### CrawlDetailPage

**File:** `features/crawl/presentation/pages/crawl_detail_page.dart`

Accepts `crawlSlug` and uses `CrawlDetailCubit`. Implemented as a `StatefulWidget` that owns the cubit instance. Renders a `CrawlStopsMapPreview` as a non-interactive mini-map within the detail content.

**Behavior:**
- Loads crawl detail on `initState` via `_cubit.loadDetail(slug)`
- Renders a `RefreshIndicator` (pull-to-refresh) wrapping the scrollable body; uses `AlwaysScrollableScrollPhysics` so the indicator activates even when content doesn't overflow
- Listens to GoRouter route changes via `GoRouter.of(context).routerDelegate.listen(...)`; on re-entry to `/crawl/:slug`, calls `_cubit.loadDetail(widget.slug)` to auto-refresh data (uses `_isFirstRouteChange` flag to avoid double-load on initial navigation)
- Cleans up the cubit and route listener in `dispose`

**Sticky CTA (bottomNavigationBar):**
- Uses `CrawlDetailCta` widget in `bottomNavigationBar`
- When `isRegistered == false`: shows "Register" button → calls `_cubit.register()`
- When `isRegistered == true`: shows "Claim your next stamp" button → navigates to first unclaimed stop's claim page (`/crawl/:slug/stop/:stopId/claim`)
- When the user is not authenticated: navigates to `/login` instead of calling `register()`
- Button style matches the login page: `Color(0xFF344E41)` background, `borderRadius: 12`, `fontSize: 16` w500, `vertical: 18` padding, elevation 0, white text

**Toast on Registration:**
- Uses `BlocConsumer` (instead of `BlocBuilder`) to listen for `CrawlDetailRegisterSuccess` state
- On that state, calls `showPrimaryToast(context, 'Successfully registered for the crawl!')`
- Renders `CrawlDetailLoaded` content normally (body and CTA unchanged)

**Share card infrastructure:**
- Owns a `_shareCardKey` (`GlobalKey`) and `_shareCardCubit` (`ShareCardCubit`) created in `initState`
- Wraps the existing `BlocProvider<CrawlDetailCubit>.value` in a nested `BlocProvider<ShareCardCubit>.value` so both cubits are available to the page tree
- In the `BlocConsumer<CrawlDetailCubit, CrawlDetailState>` listener branch: when `state` is `CrawlDetailLoaded`, calls `_shareCardCubit.loadData(state.detail.crawl.id)` to pre-load share card data
- The `Scaffold` body is wrapped in a `Stack` that contains:
  1. The normal scrollable body content
  2. An off-screen `RepaintBoundary(key: _shareCardKey, child: ShareCardView())` — positioned with `top: 0, left: 0, width: 360, height: 640` and `Transform.scale(scale: 1, ...)` at `Offset(0, -660)` to render invisibly off-screen
- In `build`: calls `_shareCardCubit.setShareCardKey(_shareCardKey)` so the cubit knows which `RepaintBoundary` to capture

**Dependencies:** `GetCrawlDetailUseCase`, `RegisterForCrawlUseCase`, `GoRouter`

#### CrawlStopsMapPage

**File:** `features/crawl/presentation/pages/crawl_stops_map_page.dart`

Full-screen interactive crawl stops map. Accepts `slug` and `stops` list. Navigated to via GoRouter route `/crawl/:slug/map` (defined in `app_router.dart`).

Implemented as a `StatefulWidget` that owns the `MapLibreMapController`.

**Behavior:**
- Loads the map style from `assets/mapstyle.json` on `initState` (falls back to `tiles.openfreemap.org` on failure)
- Computes initial camera position and bounds from stop coordinates — handles 0, 1, or 2+ valid stops
- On style load, adds custom `MapPin.png` symbol icons for each stop with `iconSize: 0.17`
- Fits camera to bounds for 2+ stops; single stop zooms to 13.0
- `_onSymbolTapped`: highlights tapped pin (`iconSize: 0.23`), resets previous pin, shows the `CafeOverlayCard` via `SlideUpOverlay` with cafe details
- `_dismissOverlay`: resets the selected symbol size, hides the overlay
- `_defaultView`: floating action button that re-centers camera to bounds

**Key UI elements:**
- **Background**: `MapLibreMap` with compass disabled
- **Pin markers**: One `Symbol` per stop, identified by `cafeId` stored in custom `data` payload
- **FloatingActionButton**: "Reset view" button (my_location icon) — white bg, `borderRadius: 16`
- **SlideUpOverlay**: Positioned above the bottom of the screen, wraps `CafeOverlayCard` — animates in/out with `AnimatedSwitcher`

**CafeOverlayCard** (in `core/presentation/widgets/`):
- Displays cafe cover image (or `_fallbackImageUrl`), name, rating, review count, location label, and tags
- Entire card is tappable via `AdaptiveTap` → navigates to `/cafe/:id`
- Close button (top-right) dismisses the overlay

**Dependencies:** `GetCafeCardUseCase`, `CrawlStopsMapCubit`

#### StampClaimPage

**File:** `features/crawl/presentation/pages/stamp_claim_page.dart`

Full-screen stamp claim page. Accepts `crawlSlug`, `stopId`, and optional `bloc`, `getCrawlDetailUseCase`, and `cafeRemoteDataSource` for test injection. Renders cafe hero photo (fetched via `CafeRemoteDataSource.fetchDetailsById` with `CustomCacheManager` fallback), cafe info header, GPS status row, and action area. Implements `SingleTickerProviderStateMixin` for the GPS spin animation.

**Behavior:**
- On `initState`: starts `_loadPageData()` which fetches crawl detail via `GetCrawlDetailUseCase`, finds the matching stop, optionally fetches cafe details for hero photo and neighborhood, then dispatches `ClaimInitialized` to the bloc. Shows a `CircularProgressIndicator` while loading.
- On data error (use case failure, stop not found): shows error screen with "Retry" button that re-triggers `_loadPageData()`.
- On `AcquiringGps` state: rotates a `loader` icon via `AnimationController.repeat()` (1s duration, linear curve). Shows "Acquiring GPS..." text. "Claim Stamp" button is disabled.
- On `GpsDenied` state: shows `mapPinOff` icon and "Enable location access in Settings" text with an "Open Settings" link (`Geolocator.openAppSettings()`). Button is disabled.
- On `GpsTimeout` state: same UI as `GpsDenied`.
- On `ClaimSubmitting` state: shows a `CircularProgressIndicator` inside the claim button.
- On `AlreadyClaimed` state: shows "Already Claimed" banner with the `claimedAt` date.
- On `LocationTooFar` state: shows "Too Far Away" banner with distance (meters or kilometers).
- On `ClaimSuccess`: shows `StampAwardedOverlay` on a dark scrim over all page content — 80px `stamp` icon with `flutter_animate` scale (elasticOut, 500ms) + fadeIn (300ms), and "Stop X claimed!" text. After 2 seconds, auto-pops via `Navigator.maybePop(context)`.
- On `ClaimSuccessWithTierCompletion`: same `StampAwardedOverlay`, but after 1.5 seconds dismisses it and opens `TierCompletionModal` as a bottom sheet. "Continue" button pops back to crawl detail.
- On `CrawlExpired`: shows "This crawl has ended" banner with `clock` icon.
- On `StopInactive`: shows "This stop is no longer active" banner with `circleX` icon.
- On `NotRegistered`: shows "You are not registered for this crawl" banner with `userX` icon.
- On `ClaimNetworkError`: shows error message with "Retry" button that re-dispatches `ClaimInitialized`.

**Hero photo logic:**
```dart
final imageUrl = _cafePhotoUrl ??
    _crawlDetail?.crawl.coverImageUrl ?? '';
```
If neither cafe photo nor crawl cover exists, renders a gradient placeholder with an `image` icon.

**Deep link format:**
```
nook://crawl/{crawlSlug}/stop/{stopId}/claim
```
The `crawlSlug` in the deep link is the crawl's string slug (e.g., `summer-brew-trail`), not a UUID. The `stopId` is a UUID. This link is what each cafe's QR code encodes.

**Share card infrastructure:**
- Owns a `_shareCardKey` (`GlobalKey`) and `_shareCardCubit` (`ShareCardCubit`) created in `initState`
- Wraps the existing `BlocProvider<CrawlClaimBloc>.value` in a nested `BlocProvider<ShareCardCubit>.value` so both bloc/cubit are available to the page tree
- In `_loadPageData()`: after successfully loading crawl detail, calls `_shareCardCubit.setShareCardKey(_shareCardKey)` and `_shareCardCubit.loadData(crawlDetail.crawl.id)` in a `WidgetsBinding.instance.addPostFrameCallback` (ensures the `RepaintBoundary` is mounted before the key is stored)
- The existing `Stack` wrapping the `Scaffold` body is extended with an off-screen `RepaintBoundary(key: _shareCardKey, child: ShareCardView())` — identical positioning to `CrawlDetailPage` (`top: 0, left: 0, 360×640`, transformed off-screen)
- `_showTierCompletionSheet` passes `shareCardKey: _shareCardKey` to `TierCompletionModal` instead of the old `onShare` callback

**Dependencies:** `GetCrawlDetailUseCase`, `CafeRemoteDataSource`, `CrawlClaimBloc`, `GpsService`

#### 14.9.1 GPS Bypass (Testing Mode)

GPS checking is **temporarily disabled** for testing the claiming flow without requiring physical proximity to a cafe.

**Client-side** (`features/crawl/presentation/bloc/crawl_claim_bloc.dart`):
- `_onClaimInitialized` skips `_gpsService.getCurrentPosition()` and calls `_submitClaim` directly with `lat: 0.0, lng: 0.0`
- **To re-enable**: Restore the original `_gpsService.getCurrentPosition()` call and its `switch` on `GpsResult` (the original code is preserved as a comment)

**Server-side** (`supabase/functions/claim_crawl_stamp.sql`):
- The Haversine distance check (step 6) is commented out, allowing claims from any location
- `v_distance_meters` is set to `0` before the disabled block to avoid NOT NULL violations on insert
- **To re-enable**: Remove the `v_distance_meters := 0;` line, uncomment the distance computation and the `location_too_far` return block, then re-apply the function to your Supabase project via the dashboard SQL editor or a migration

### 14.10 Widgets

| Widget | File | Purpose |
|---|---|---|---|
| `CrawlDetailCta` | `widgets/crawl_detail_cta.dart` | **Fully implemented** — sticky CTA button for crawl detail page; adapts to registration and claim states |
| `CrawlHomeBanner` | `widgets/crawl_home_banner.dart` | **Placeholder** — home screen active crawl highlight |
| `CrawlStopsMapPreview` | `widgets/crawl_stops_map_preview.dart` | **Fully implemented** — non-interactive mini map (220px) used in `CrawlDetailPage`; all gestures disabled, single pin per stop |
| `StampAwardedOverlay` | `widgets/stamp_awarded_overlay.dart` | **Fully implemented** — animated full-screen overlay shown on successful stamp claim; extracted from `StampClaimPage` |
| `TierCompletionModal` | `widgets/tier_completion_modal.dart` | **Fully implemented** — shown as a bottom sheet when a tier is completed after claiming a stamp |
| `ShareCardView` | `widgets/share_card_view.dart` | **Fully implemented** — `BlocBuilder<ShareCardCubit, ShareCardState>` bridge; renders `CrawlShareCard` on `Ready`, `SizedBox.shrink()` otherwise |
| `CrawlShareCard` | `widgets/share_card/crawl_share_card.dart` | **Fully implemented** — composes `ShareCardStampHero` + `ShareCardStats` + `ShareCardFooter` in a 360×640 `SizedBox` |
| `ShareCardStampHero` | `widgets/share_card/share_card_stamp_hero.dart` | **Fully implemented** — stamp seal hero section of the share card |
| `ShareCardStats` | `widgets/share_card/share_card_stats.dart` | **Fully implemented** — 3-column stats section (STOPS/LATEST/CRAWL or STOPS/TIER/CRAWL) |
| `ShareCardFooter` | `widgets/share_card/share_card_footer.dart` | **Fully implemented** — Nook wordmark + crawl title footer |

#### CrawlStopsMapPreview

**File:** `features/crawl/presentation/widgets/crawl_stops_map_preview.dart`

Non-interactive minimap (220px tall) embedded in `CrawlDetailPage`. All gestures disabled (`scrollGesturesEnabled: false`, `zoomGesturesEnabled: false`, etc.). Renders the same `MapLibreMap` with pin markers for each stop, fitted to bounds.

#### StampAwardedOverlay

**File:** `features/crawl/presentation/widgets/stamp_awarded_overlay.dart`

Animated full-screen overlay shown immediately after a stamp is claimed successfully (`ClaimSuccess` or `ClaimSuccessWithTierCompletion`). Extracted from `StampClaimPage._buildActionArea` into a reusable presentation widget with zero dependencies on the page's Bloc or state.

**Layout:**
1. Semi-transparent dark scrim (`Colors.black` at 40% opacity) filling the entire screen
2. Centered column with:
   - 80px `stamp` icon (`LucideIcons.stamp`) in `colors.success` — animated with `elasticOut` scale (500ms) + fade-in (300ms) via `flutter_animate`
   - `Gap(16)` spacing
   - "Stop X claimed!" text using `titleSmall` text style in `colors.primary100`

**Behavior:**
- Wrapped in `IgnorePointer` — no user interaction; auto-dismissal handled by the parent page's `Timer`
- On `ClaimSuccessWithTierCompletion`, the parent page dismisses this overlay after 1.5s before opening `TierCompletionModal`
- `stopOrder` is required; an optional `cafeName` param is reserved for future use

**Dependencies:** `flutter_animate`, `lucide_icons_flutter`

Has a widget preview file (`stamp_awarded_overlay_preview.dart`) with 1 `@Preview` annotation.

#### CrawlDetailCta

**File:** `features/crawl/presentation/widgets/crawl_detail_cta.dart`

Placed in `CrawlDetailPage.bottomNavigationBar`. Adapts its button based on state:

| Prop | Value | Behavior |
|---|---|---|
| `isRegistered: false` | "Register" | Calls `onRegisterTap` |
| `isRegistered: true, allStopsClaimed: false` | "Claim your next stamp" | Calls `onClaimStopTap` |
| `isRegistered: true, allStopsClaimed: true` | "All stamps claimed! 🎉" | Disabled button |

Button style matches the login page: `Color(0xFF344E41)` background, `borderRadius: 12`, `fontSize: 16` w500, `vertical: 18` padding, elevation 0, white text.

Has a widget preview file (`crawl_detail_cta_preview.dart`) with 3 `@Preview` annotations covering all states.

#### TierCompletionModal

**File:** `features/crawl/presentation/widgets/tier_completion_modal.dart`

Shown as a bottom sheet when a `ClaimSuccessWithTierCompletion` state is emitted. Displayed 1.5 seconds after the stamp animation via `showModalBottomSheet`.

**Props:**
| Prop | Type | Description |
|---|---|---|
| `tier` | `TierCompletionResult` | Tier data for badge, name, and copy |
| `shareCardKey` | `GlobalKey` | Key to the off-screen `RepaintBoundary` hosting the share card (owned by the parent page, not the cubit directly) |

**Layout (top to bottom):**
1. Badge image — fetched from `tier.badgeImageUrl` via `CachedNetworkImage` with `CustomCacheManager`; if empty or fails to load, shows a gradient placeholder with a `trophy` icon
2. Tier name — displayed using `titleLargeSemi` text style
3. Completion copy — optional message from `tier.completionCopy`, or a default "You completed the {tierName} tier!"
4. "Share with friends" button — wrapped in `BlocBuilder<ShareCardCubit, ShareCardState>`; shows `CircularProgressIndicator` (20px, white) during `ShareCardCapturing` state, otherwise shows `share2` icon with "Share with friends" text
5. "Continue" button — text-only button that dismisses the bottom sheet and pops back to the crawl detail page

**Share flow (inside modal):**
- Share button calls `context.read<ShareCardCubit>().captureAndShare()` (parameterless — cubit stores the `GlobalKey` internally via `setShareCardKey()`)
- `BlocListener<ShareCardCubit, ShareCardState>` at the root of the modal listens for `ShareCardError` → shows `showPrimaryToast` error SnackBar
- `BlocListener` listens for `ShareCardShared` → auto-closes the bottom sheet via `Navigator.of(context).pop()`

**Dependencies:** `cached_network_image`, `flutter_animate`

#### ShareCardStampHero

**File:** `features/crawl/presentation/widgets/share_card/share_card_stamp_hero.dart`

Pure presentational widget — no BLoC dependency. Renders the top ~55% (352px) of the Strava-style share card. Used within the full `ShareCardView` which composes the stamp hero, stats section, and footer.

**Props:**
| Prop | Type | Description |
|---|---|---|
| `cafeName` | `String` | Cafe name displayed on the top arc of the stamp seal |
| `stopNumber` | `int` | Stop number displayed on the bottom arc as "STOP {N}" |

**Layout:**
- 352px tall `Container` with `Color(0xFF0F1F0F)` background
- `Stack` with two layers:
  1. `Center` → `CustomPaint` (200×200) rendering `_StampSealPainter`
  2. Grain texture overlay via `Positioned.fill` → `Opacity(0.08)` → `Image.asset` with `errorBuilder` fallback (skips gracefully if `assets/crawl/stamp_grain.png` is missing)

**`_StampSealPainter` (CustomPainter):**

| Layer | Details |
|---|---|
| Outer ring | `Paint()` stroke only, `Color(0xFF4CAF50)`, `strokeWidth: 2`, diameter 200px |
| Inner fill | `Color(0xFF1A2E1A)`, diameter 180px |
| Wordmark | Centered "nook" text via `TextPainter` at `fontSize: 28`, `w600` (placeholder — real brand asset TBD) |
| Top arc | Cafe name (`toUpperCase()`) curved from 200° to 340° (clockwise through top) at `fontSize: 12`, `letterSpacing: 2`, `Colors.white` |
| Bottom arc | "STOP {N}" curved from 160° to 20° (counterclockwise through bottom) at same style |

**Arc text rendering:**
- Per-character `canvas.save()` / `restore()` with `translate(center)` → `rotate(angle)` → `translate(arcRadius, 0)` → `rotate(-π/2)` → center character and paint
- `rotate(-π/2)` aligns the character baseline with the clockwise tangent, with the character top facing radially outward (readable from outside the seal)
- Characters evenly distributed along the arc sweep; single character case centered at `t = 0.5`
- No external packages required — manual `dart:math` trigonometry

**Preview:** `share_card_stamp_hero_preview.dart` with 1 `@Preview` annotation (Cafe Brindle, Stop 3).

**Dependencies:** None (pure Flutter + `dart:math`)

#### ShareCardStats

**File:** `features/crawl/presentation/widgets/share_card/share_card_stats.dart`

Pure presentational widget — no BLoC dependency. Renders the middle ~35% (240px) of the Strava-style share card, sandwiched between `ShareCardStampHero` (top) and `ShareCardFooter` (bottom).

**Props:**
| Prop | Type | Description |
|---|---|---|
| `data` | `CrawlShareCardData` | Share card data containing stamps, stops, tier info, and stop list |

**Layout:**
- `Container` with `Color(0xFF0F1F0F)` background, `EdgeInsets.symmetric(horizontal: 20, vertical: 16)` padding
- Top and bottom `Divider(color: Color(0xFF2A3E2A), thickness: 1, height: 1)`
- `Row` of 3 `Expanded` columns, each a `_Column` widget with label + value

**Column logic:**

| State | Col 1 | Col 2 | Col 3 |
|---|---|---|---|
| In-progress (`highestTier == null`) | STOPS: `totalStamps` | LATEST: last claimed `cafeName` or `—` | CRAWL: `crawlTitle · crawlPeriod` |
| Completed (`highestTier != null`)  | STOPS: `totalStamps of totalStops` | TIER: `highestTier.name` | CRAWL: `crawlTitle · crawlPeriod` |

**Label style:** `fontSize: 11`, `color: Color(0x80FFFFFF)`, `letterSpacing: 1.5`, `fontWeight: w500`, rendered uppercase
**Value style:** `fontSize: 26`, `color: Colors.white`, `fontWeight: w700`, `overflow: TextOverflow.ellipsis`, `maxLines: 1`

**Last claimed stop resolution:** Filters `data.stops` where `isClaimed && claimedAt != null`, reduces to the stop with the highest `claimedAt`. If none claimed, shows `"—"` (em dash).

**Dependencies:** `gap`

#### ShareCardFooter

**File:** `features/crawl/presentation/widgets/share_card/share_card_footer.dart`

Pure presentational widget — no BLoC dependency. Renders the bottom ~10% (48px) of the share card.

**Props:**
| Prop | Type | Description |
|---|---|---|
| `crawlTitle` | `String` | Crawl title displayed below the wordmark |

**Layout:**
- 48px tall `Container` with `Color(0xFF0F1F0F)` background, centered alignment
- `Column` with `mainAxisAlignment: MainAxisAlignment.center`:
  1. `Text('nook')` — `fontSize: 18`, `fontWeight: w800`, `color: Colors.white`, `letterSpacing: 3`
  2. `Gap(2)`
  3. `Text(crawlTitle)` — `fontSize: 10`, `color: Color(0x60FFFFFF)`, `letterSpacing: 1`, centered

**Dependencies:** `gap`

#### ShareCardView

**File:** `features/crawl/presentation/widgets/share_card_view.dart`

`BlocBuilder<ShareCardCubit, ShareCardState>` bridge widget that reactively renders the share card. Intended to be placed inside a `RepaintBoundary` for capture.

**Behavior:**
- On `ShareCardReady`: renders a `SizedBox(width: 360, height: 640)` containing `CrawlShareCard(data: state.data)`
- On any other state (`Initial`, `Loading`, `Capturing`, `Shared`, `Error`): renders `SizedBox.shrink()` (zero-size, invisible)

**Dependencies:** `ShareCardCubit`

#### CrawlShareCard

**File:** `features/crawl/presentation/widgets/share_card/crawl_share_card.dart`

Full 360×640 share card composition widget. Takes `CrawlShareCardData` and renders the complete shareable recap card with stamp hero, stats, and footer.

**Props:**
| Prop | Type | Description |
|---|---|---|
| `data` | `CrawlShareCardData` | Share card data containing stamps, stops, tier info, and stop list |

**Layout (top to bottom, 360×640 `SizedBox`):**
1. `ShareCardStampHero(cafeName:, stopNumber:)` — top ~55% (352px); derives `cafeName` and `stopNumber` from `data.stops` — finds the last claimed stop (`isClaimed && claimedAt != null`) with the highest `claimedAt` value; defaults to "NO STOPS" / "—" if none claimed
2. `ShareCardStats(data: data)` — middle ~35% (240px); three-column stat row
3. `ShareCardFooter(crawlTitle: data.crawlTitle)` — bottom ~10% (48px); wordmark + title

**Total height:** 352 + 240 + 48 = 640px

**Dependencies:** `ShareCardStampHero`, `ShareCardStats`, `ShareCardFooter`

### 14.12 Shared Core Widgets

The following widgets extracted to `core/presentation/widgets/` for reuse across features:

| Widget | File | Purpose |
|---|---|---|
| `CafeOverlayCard` | `core/presentation/widgets/cafe_overlay_card.dart` | **Fully implemented** — cafe detail card with image, name, rating, location, tags; tappable to navigate to `/cafe/:id` |
| `SlideUpOverlay` | `core/presentation/widgets/slide_up_overlay.dart` | **Fully implemented** — generic animated slide-up wrapper using `AnimatedSwitcher` with `SlideTransition` + `FadeTransition`; configurable `duration`, `switchInCurve`, `switchOutCurve` |

Both moved/extracted from `features/map/presentation/widgets/` during the crawl map implementation.

### 14.13 DI Registration

**File:** `features/crawl/presentation/injection/crawl_presentation_injection.dart`

Called from `injection_container.dart` after domain/data registrations.

```
registerLazySingleton → GpsService → GpsServiceImpl
registerFactory       → ActiveCrawlsCubit
registerFactory       → CrawlDetailCubit
registerFactory       → ShareCardCubit
registerFactory       → CrawlClaimBloc
```

`CrawlStopsMapCubit` is **not** registered in DI — it's created inline in `CrawlStopsMapPage` via `BlocProvider(create: (_) => CrawlStopsMapCubit(sl<GetCafeCardUseCase>()))`.

### 14.14 GoRouter Route

**File:** `lib/core/router/app_router.dart`

The crawl stops map is registered as a full-screen route — must come before the `/crawl/:slug` route to avoid conflicts:

```dart
GoRoute(
  path: '/crawl/:slug/map',
  builder: (context, state) {
    final slug = state.pathParameters['slug'] ?? '';
    final stops = state.extra as List<CrawlStop>? ?? [];
    return CrawlStopsMapPage(slug: slug, stops: stops);
  },
),
```

### 14.15 Tests

**~41 tests total** — all passing:

| Suite | File | Tests |
|---|---|---|
| CrawlClaimBloc | `crawl_claim_bloc_test.dart` | 11 |
| ActiveCrawlsCubit | `active_crawls_cubit_test.dart` | 3 |
| CrawlDetailCubit | `crawl_detail_cubit_test.dart` | 10 — covers `loadDetail` (3), `register` (4), `refresh` (3) |
| StampClaimPage (widget) | `stamp_claim_page_test.dart` | 16 — covers data loading (3), GPS states (4), claim states (5), error states (3), not registered (1) |
| StampAwardedOverlay (widget) | `stamp_awarded_overlay_test.dart` | 2 — covers stop number text, animation without error |
| CrawlDetailCta (widget) | `crawl_detail_cta_test.dart` | 6 — covers all CTA states: unauthenticated, register, registered but no stops, registered with unclaimed stops, all claimed, and error |
| SlideUpOverlay (widget) | `slide_up_overlay_test.dart` | 6 — covers visibility toggle, animation transitions, custom child, narrow screen rendering |
| ShareCardStats (widget) | `share_card_stats_test.dart` | 3 — covers in-progress state, completed state, em dash when no claimed stops |
| ShareCardFooter (widget) | `share_card_footer_test.dart` | 1 — renders wordmark and crawl title |

All cubit/bloc tests use `blocTest` for declarative emission assertions.
Widget tests use `WidgetTester` with `pumpWidget` + `MaterialApp` wrapper, and mock cubits via `BlocProvider.value`.
Mocks generated with `@GenerateNiceMocks` via `build_runner`.

### 14.16 Deep Link Config

**Android** (`android/app/src/main/AndroidManifest.xml`):
```xml
<intent-filter>
  <action android:name="android.intent.action.VIEW" />
  <category android:name="android.intent.category.DEFAULT" />
  <category android:name="android.intent.category.BROWSABLE" />
  <data android:scheme="nook" />
</intent-filter>
```

**iOS** (`ios/Runner/Info.plist`):
```xml
<key>FlutterDeepLinkingEnabled</key>
<true/>
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleURLSchemes</key>
    <array><string>nook</string></array>
  </dict>
</array>
```

---

## 15. Open Questions

- [ ] Confirm share card design — does it need `stamp_template_url`?
- [ ] Should share card data include the user's avatar URL?
- [ ] Finalize GPS accuracy threshold (currently 200m Haversine) — may need adjustment per crawl
- [ ] Decide whether `claimStamp` should accept a `claim_method` override (currently hardcoded to `'qr'`)
