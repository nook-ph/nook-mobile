# Crawl

> **Status:** ✅ Domain, Data, and Presentation layers complete; detail page fully implemented with sticky CTA, registration toast, pull-to-refresh, and auto-refresh on re-entry; crawl stops map page fully implemented with interactive map, pin markers, symbol tapping, and slide-up cafe overlay card.
> **Last updated:** 2026-06-11

---

## 1. Overview

Crawls are time-bound, multi-stop cafe tours that users can register for and
complete by visiting stops and claiming stamps. Each crawl is divided into
**tiers** (geographic or thematic groupings like "City Explorer" or "Island
Run"), and completing a tier awards the user an **achievement**.

The feature is built across two locations:

- **`lib/features/crawl/`** — Core crawl domain (entities, tiers, stamps, registration)
- **`lib/core/achievements/`** — Cross-feature achievement system (shared by crawls, drops, social, milestones)

The **domain**, **data**, and **presentation** layers are all complete. The crawl detail page (`CrawlDetailPage`) has been fully implemented with a sticky CTA, registration toast, pull-to-refresh, and auto-refresh on route re-entry. The crawl stops map page (`CrawlStopsMapPage`) is fully implemented with an interactive MapLibre map, pin markers, symbol tapping, and a slide-up cafe overlay card. The stamp claim page (`StampClaimPage`) and passport page (`PassportPage`) remain placeholder UIs pending further work.

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
│       │   ├── crawl_stops_map_cubit.dart   # Loads CafeSummary data for stops map
│       │   └── crawl_stops_map_state.dart   # sealed: Initial, Loading, Loaded, Error
│       ├── pages/
│       │   ├── stamp_claim_page.dart        # Placeholder UI — wires CrawlClaimBloc
│       │   ├── crawl_detail_page.dart       # Fully implemented — sticky CTA, refresh, progress card, map preview
│       │   ├── crawl_stops_map_page.dart    # Fully implemented — interactive map, pins, overlay card
│       │   └── passport_page.dart           # Placeholder UI
│       ├── widgets/
│       │   ├── crawl_detail_cta.dart        # Sticky CTA for register / claim-stop
│       │   ├── crawl_home_banner.dart       # Placeholder
│       │   ├── crawl_stops_map_preview.dart # Non-interactive mini map for detail page
│       │   ├── tier_completion_modal.dart   # Placeholder
│       │   └── share_card_view.dart         # Placeholder
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
|---|---|
| `dartz` | `Either<Failure, T>` for repository return types |
| `supabase_flutter` | All data access (tables + RPCs) |
| `get_it` | DI registration |
| `flutter_bloc` | BLoC + Cubit state management |
| `equatable` | Value equality for state/event classes |
| `geolocator` | GPS position acquisition for stamp claiming |
| `maplibre_gl` | Interactive map rendering for `CrawlStopsMapPage` and `CrawlStopsMapPreview` |
| `lucide_icons_flutter` | Map pin icons in `CafeOverlayCard` |
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

### 14.7 Deep Link Handler

**File:** `features/crawl/presentation/deep_link/crawl_deep_link_handler.dart`

Parses deep links in the format `nook://crawl/{crawlId}/stop/{stopId}/claim`.

```dart
CrawlDeepLinkHandler.canHandle(uri)   // checks scheme + host
CrawlDeepLinkHandler.parse(uri)        // returns CrawlDeepLinkResult? 
```

Integrated in `main.dart` via `_handleIncomingLink` — rewrites URI path to GoRouter route `/crawl/:crawlId/stop/:stopId/claim`. Platform config:

- **Android:** `AndroidManifest.xml` intent filter for `nook://` scheme
- **iOS:** `Info.plist` `FlutterDeepLinkingEnabled` + `CFBundleURLTypes`

### 14.8 Pages

| Page | File | State |
|---|---|---|
| `StampClaimPage` | `pages/stamp_claim_page.dart` | **Placeholder** — wires `CrawlClaimBloc`, calls `ClaimInitialized` on mount |
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

### 14.9 Widgets

| Widget | File | Purpose |
|---|---|---|
| `CrawlDetailCta` | `widgets/crawl_detail_cta.dart` | **Fully implemented** — sticky CTA button for crawl detail page; adapts to registration and claim states |
| `CrawlHomeBanner` | `widgets/crawl_home_banner.dart` | **Placeholder** — home screen active crawl highlight |
| `CrawlStopsMapPreview` | `widgets/crawl_stops_map_preview.dart` | **Fully implemented** — non-interactive mini map (220px) used in `CrawlDetailPage`; all gestures disabled, single pin per stop |
| `TierCompletionModal` | `widgets/tier_completion_modal.dart` | **Placeholder** — shown when a tier is completed |
| `ShareCardView` | `widgets/share_card_view.dart` | **Placeholder** — crawl recap share card |

#### CrawlStopsMapPreview

**File:** `features/crawl/presentation/widgets/crawl_stops_map_preview.dart`

Non-interactive minimap (220px tall) embedded in `CrawlDetailPage`. All gestures disabled (`scrollGesturesEnabled: false`, `zoomGesturesEnabled: false`, etc.). Renders the same `MapLibreMap` with pin markers for each stop, fitted to bounds.

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

### 14.10 Shared Core Widgets

The following widgets extracted to `core/presentation/widgets/` for reuse across features:

| Widget | File | Purpose |
|---|---|---|
| `CafeOverlayCard` | `core/presentation/widgets/cafe_overlay_card.dart` | **Fully implemented** — cafe detail card with image, name, rating, location, tags; tappable to navigate to `/cafe/:id` |
| `SlideUpOverlay` | `core/presentation/widgets/slide_up_overlay.dart` | **Fully implemented** — generic animated slide-up wrapper using `AnimatedSwitcher` with `SlideTransition` + `FadeTransition`; configurable `duration`, `switchInCurve`, `switchOutCurve` |

Both moved/extracted from `features/map/presentation/widgets/` during the crawl map implementation.

### 14.11 DI Registration

**File:** `features/crawl/presentation/injection/crawl_presentation_injection.dart`

Called from `injection_container.dart` after domain/data registrations.

```
registerLazySingleton → GpsService → GpsServiceImpl
registerFactory       → ActiveCrawlsCubit
registerFactory       → CrawlDetailCubit
registerFactory       → CrawlClaimBloc
```

`CrawlStopsMapCubit` is **not** registered in DI — it's created inline in `CrawlStopsMapPage` via `BlocProvider(create: (_) => CrawlStopsMapCubit(sl<GetCafeCardUseCase>()))`.

### 14.12 GoRouter Route

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

### 14.13 Tests

**~35 tests total** — all passing:

| Suite | File | Tests |
|---|---|---|
| CrawlClaimBloc | `crawl_claim_bloc_test.dart` | 11 |
| ActiveCrawlsCubit | `active_crawls_cubit_test.dart` | 3 |
| CrawlDetailCubit | `crawl_detail_cubit_test.dart` | 10 — covers `loadDetail` (3), `register` (4), `refresh` (3) |
| StampClaimPage (widget) | `stamp_claim_page_test.dart` | 2 |
| CrawlDetailCta (widget) | `crawl_detail_cta_test.dart` | 6 — covers all CTA states: unauthenticated, register, registered but no stops, registered with unclaimed stops, all claimed, and error |
| SlideUpOverlay (widget) | `slide_up_overlay_test.dart` | 6 — covers visibility toggle, animation transitions, custom child, narrow screen rendering |

All cubit/bloc tests use `blocTest` for declarative emission assertions.
Widget tests use `WidgetTester` with `pumpWidget` + `MaterialApp` wrapper, and mock cubits via `BlocProvider.value`.
Mocks generated with `@GenerateNiceMocks` via `build_runner`.

### 14.14 Deep Link Config

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
