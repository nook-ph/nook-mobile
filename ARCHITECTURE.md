# Nook Flutter App — Architecture Reference

> **For agentic use.** This document describes the structural conventions, layer responsibilities, and cross-cutting patterns of the Nook Flutter codebase. Use it to determine where new code belongs, how data flows, and which patterns to follow.

---

## Stack

| Concern | Technology |
|---|---|
| UI Framework | Flutter |
| State Management | BLoC / Cubit (`flutter_bloc`) |
| Dependency Injection | `get_it` |
| Backend | Supabase (PostgreSQL, Auth, Storage, Edge Functions) |
| Routing | `go_router` |
| Analytics | PostHog |
| File Upload | Supabase Edge Function (`presign-upload`) |

---

## Top-Level Structure

```
lib/
├── core/           # App-wide shared infrastructure
├── features/       # Self-contained vertical feature slices
├── utils/theme/    # Global theming (color scheme, text theme)
├── injection_container.dart   # get_it DI registration
└── main.dart
```

---

## Architectural Pattern: Clean Architecture

Every feature and the shared `core/cafe` domain follow a strict three-layer structure:

```
data/       → Remote data sources, model classes, repository implementations
domain/     → Entities, repository interfaces (I*Repository), use cases
presentation/ → BLoC/Cubit, pages, widgets
```

**Rules:**
- `domain/` has zero Flutter/Supabase dependencies. Pure Dart.
- `data/` implements domain interfaces and maps models → entities.
- `presentation/` consumes use cases via BLoC/Cubit; never touches data sources directly.
- Use cases are single-responsibility classes with a `call()` method.

---

## `core/` — Shared Infrastructure

### `core/cafe/` — Canonical Cafe Domain

The central domain for cafe data, shared across features (home, map, search, lists).

```
core/cafe/
├── data/
│   ├── cafe_remote_data_source.dart   # Supabase RPC calls (get_cafes, etc.)
│   ├── cafe_repository_impl.dart
│   ├── cafe_store.dart                # In-memory TTL cache (CafeStore)
│   └── cafe_summary_model.dart
└── domain/
    ├── entities/
    │   ├── cafe_bundle.dart           # Wraps CafeSummary list + metadata
    │   ├── cafe_details.dart
    │   ├── cafe_list.dart             # User-created lists
    │   ├── cafe_query.dart            # Filter/sort parameters
    │   └── cafe_summary.dart          # Lightweight cafe card data
    ├── repositories/
    │   └── i_cafe_repository.dart
    └── use_cases/
        ├── get_cafes_usecase.dart
        ├── get_cafe_details_usecase.dart
        ├── get_cafe_list_memberships_usecase.dart
        ├── get_user_lists_usecase.dart
        ├── add_cafe_to_list_usecase.dart
        ├── remove_cafe_from_list_usecase.dart
        ├── create_list_usecase.dart
        ├── resolve_quick_save_list_usecase.dart
        ├── add_review_usecase.dart
        ├── get_cafe_reviews_usecase.dart
        └── get_reviews_written_by_user_usecase.dart
```

**`CafeStore`** — TTL-based in-memory cache keyed by `CafeQuery`. Prevents redundant Supabase calls when navigating between Home/Map/Search with the same filters.

**`CafeBundle`** — The canonical result shape returned by `get_cafes`. Contains `List<CafeSummary>` plus pagination/metadata.

### `core/filters/`

```
core/filters/
├── cubit/filter_cubit.dart    # Singleton via get_it; shared between Map and Search
└── models/cafe_filter.dart    # Tag selections, sort mode, distance radius
```

`FilterCubit` is registered as a **lazy singleton** in `injection_container.dart`. It is the handoff point between the Map page filter sheet and Search results, ensuring both pages reflect the same active filter state.

### `core/upload/`

Universal file upload subsystem. All uploads (review images, avatars) go through one edge function.

```
core/upload/
├── data/
│   ├── upload_remove_data_source.dart     # Calls presign-upload edge function
│   └── upload_repository_impl.dart
└── domain/
    ├── entities/
    │   ├── uploaded_file.dart
    │   ├── uploaded_avatar.dart
    │   └── uploaded_review_image.dart
    ├── repositories/i_review_image_upload_repository.dart
    └── use_cases/upload_use_case.dart
```

### `core/preferences/`

Lightweight local persistence for ephemeral user preferences.

- `last_saved_list_store.dart` — Remembers which list was last used in the bookmark flow (drives the "quick save" behavior).
- `review_draft_store.dart` / `review_draft.dart` — Persists an in-progress review draft.

### `core/app_bloc.dart` / `app_event.dart` / `app_state.dart`

Top-level BLoC that owns global app state (auth session, onboarding completion flag). Drives the root `GoRouter` redirect logic.

### `core/router/app_router.dart`

`GoRouter` configuration. Redirect logic reads from `AppBloc` state to gate:
- Unauthenticated users → auth flow
- Authenticated users without username → `username_setup_page`
- Authenticated users without verified email → `email_confirmation_pending_page`
- Fully onboarded users → main shell

### `core/presentation/`

```
core/presentation/
├── bottom_nav.dart           # Persistent bottom navigation bar
├── pages/main_screen.dart    # Shell scaffold wrapping bottom nav + child routes
└── widgets/
    ├── bookmark_icon_button.dart        # Reusable save/bookmark CTA
    ├── cafe_summary_overflow_tags_row.dart
    ├── list_card.dart                   # Shared list preview card
    └── app_bar_circle_icon_button.dart
```

### `core/bloc/features/navigation/`

`NavigationBloc` — manages bottom nav tab index state.

### `core/utils/`

Pure utility helpers. No Flutter widget dependencies.

- `toast_helper.dart` — Wrapper around `another_flushbar` for consistent toast display.
- `tag_icon_resolver.dart` — Maps tag string keys to icon assets.
- `maps_directions_launcher.dart` — Opens native maps app for directions.
- `error_info.dart` / `app_error_copy.dart` — Typed error models and user-facing copy.
- `adaptive_tap.dart` — Platform-adaptive tap handler (InkWell vs GestureDetector).

### `core/widgets/`

Reusable, stateless UI primitives used across multiple features.

- `error/` — `FullPageErrorWidget`, `FullPageEmptyWidget`, `SectionErrorWidget`, `SectionEmptyWidget`, `LocationDeniedBanner`
- `prototype_height.dart` — Layout helper for prototyping fixed-height sections.

---

## `features/` — Vertical Feature Slices

Each feature is self-contained. Feature-level BLoCs/Cubits are **not** singletons unless explicitly noted.

---

### `features/auth/`

**Responsibility:** All authentication flows.

**Pages:** `email_entry_page`, `login_page`, `signup_details_page`, `username_setup_page`, `email_confirmation_pending_page`, `forgot_password_page`, `change_email_page`, `change_password_page`

**BLoC:** `AuthBloc` / `AuthEvent` / `AuthState`

**Use cases:** sign in (email, Google, Apple), sign up, sign out, check email exists, get current session.

**DI:** `auth_injection.dart` — feature-local DI registration, called from `injection_container.dart`.

**Notes:**
- `username_setup_page` is a mandatory gate post-registration before the user reaches the main app.
- Deep link handling for email verification is wired through `GoRouter` + `AuthBloc`.

---

### `features/home_page/`

**Responsibility:** Main discovery feed shown on app open.

**BLoC:** `HomeBloc` / `HomeEvent` / `HomeStates`

**Use case:** `get_cafe_summaries_usecase` (delegates to `core/cafe` repository)

**Widgets:** `HomeCafeCard`, `HomeCardSection`, `HomeFeaturedCard`, `RecommendedCard`, `HomeTopBar`

---

### `features/map/`

**Responsibility:** MapLibre GL map view with filterable cafe pins and a bottom sheet card carousel.

**BLoC:** `MapBloc` / `MapEvent` / `MapStates`

**Own domain:**
```
map/domain/
├── entities/cafe_tags_entity.dart
├── repositories/i_cafe_tags_repository.dart
└── use_cases/
    ├── get_cafe_cards_usecase.dart
    └── get_filter_tags_usecase.dart
```

**Own data layer:** `cafe_tags_remote_data_source.dart`, `cafe_tags_repository_impl.dart`

**Widgets:** `BottomModalSheet` (DraggableScrollableSheet), `CafeCard`, `CafeOverlayCard`, `MapFilterBottomSheet`, `MapFilterContent`, `MapFilterSubSheet`, `MapSheetCafeCard`

**Notes:**
- Map pins are rendered as SVG-to-bitmap bitmaps.
- `DraggableScrollableSheet` replaced `sliding_panel_kit` to fix horizontal swipe gesture conflicts with `PageView`.
- Shared `FilterCubit` (singleton) bridges filter state between Map and Search.

---

### `features/cafe_details/`

**Responsibility:** Full cafe profile page including menu, reviews, and hours.

**BLoCs (3):**
- `CafeDetailsBloc` — loads cafe details.
- `ReviewsBloc` — loads + paginates reviews; supports filtering.
- `ReviewSubmitBloc` — handles review draft submission, image upload, and optimistic UI.

**Data flow:** delegates to `core/cafe` — `CafeDetailsBloc` uses the core `GetCafeDetailsUseCase` → `ICafeRepository.getCafeBundleById()`. Cafe details are not cached in `CafeStore` (fetched on demand).

**Pages:** `CafeDetailsPage`, `MenuFullPage`, `ReviewsPage`

**Widgets:** `HeroImageSlider`, `CafeInfoHeader`, `CafeInfo`, `CafeTagsList`, `CafeHoursTitle`, `DayRow`, `MenuHighlights`, `MenuCategorySection`, `MenuItemCard`, `MenuItemVariantsSheet`, `RatingReviewSummary`, `ReviewsSection`, `ReviewFilterBottomSheet`, `WriteReviewSheet`, `CafeLocationMapPreview`

---

### `features/lists/`

**Responsibility:** User-created cafe collections (Lists).

**BLoC:** `ListsBloc` / `ListsEvent` / `ListsState` — registered as a **lazy singleton** (so list membership state is consistent across the bookmark flow from any page).

**Cubit:** `SaveToListCubit` — ephemeral, per-instance cubit that manages the bottom sheet interaction for adding/removing a cafe from lists.

**Pages:** `ListPage` (all lists), `ListDetailPage` (cafes in a list)

**Widgets:** `SaveToListBottomSheet`, `ListOptionsBottomSheet`

**Notes:**
- Backed by `lists` / `list_members` / `list_cafes` schema in Supabase.
- `SECURITY DEFINER` RPC `get_user_list_ids` is used to prevent RLS infinite recursion.
- The "quick save" flow (bookmark icon → saves to last-used list without opening the sheet) reads from `LastSavedListStore`.

---

### `features/search/`

**Responsibility:** Tag-based and text-based cafe search.

**BLoC:** `SearchBloc` / `SearchEvent` / `SearchState`

**Use case:** `search_cafes_usecase` (delegates to `core/cafe` repository with a text query in `CafeQuery`)

**Widgets:** `SearchEntryButton` (tap target on home/map), `SearchResultsPage`, `SearchTagChips`, `BestForTagList`, `AmenitiesTagList`

---

### `features/profile/`

**Responsibility:** User profile view, edit profile, settings, avatar upload, user's written reviews.

**BLoC:** `AvatarUploadBloc` — wraps `core/upload` use case for avatar-specific logic.

**Cubit:** `ProfileCubit` — loads profile data.

**Own data layer:** `profile_remote_data_source.dart`, `profile_repository_impl.dart`

**Use case:** `update_profile_usecase.dart` (placed at feature level — note: not under `domain/use_cases/`, minor deviation from convention).

**Pages:** `ProfilePage`, `ProfilePageV2` (active version), `EditProfilePage`, `ReviewsPage` (profile-scoped), `SettingsPage`

---

### `features/onboarding/`

**Responsibility:** First-launch onboarding screens shown before the main app.

**BLoC:** `OnboardingBloc`

**Data:** `onboarding_data.dart` — static slide content.

---

## Dependency Injection (`injection_container.dart`)

All singletons and factories are registered with `get_it`. Registration follows this order:

1. External dependencies (Supabase client, etc.)
2. Data sources
3. Repositories
4. Use cases
5. BLoCs / Cubits

**Singletons (persistent across the app lifetime):**
- `FilterCubit`
- `ListsBloc`
- `AuthBloc`

**Factories (new instance per registration):**
- Feature BLoCs injected via `BlocProvider` at the route level.

Feature-local DI (e.g., `auth_injection.dart`) is called from `injection_container.dart` to keep registration modular.

---

## Theming (`utils/theme/`)

```
utils/theme/
├── theme.dart                        # ThemeData assembly
└── custom_themes/
    ├── color_scheme.dart             # Brand color tokens
    └── text_theme.dart               # Typography scale
```

All colors and typography come from these files. Never hardcode colors in widgets.

---

## Data Flow (Example: Browsing Cafes on Home)

```
HomeBloc (GetCafeSummariesUseCase)
  → ICafeRepository
    → CafeRepositoryImpl
      → CafeStore (TTL cache hit?)
        → YES: return cached CafeBundle
        → NO:  CafeRemoteDataSource.getCafes(query)
                 → Supabase RPC get_cafes(...)
                 → returns List<CafeSummaryModel>
               → map to List<CafeSummary>
               → store in CafeStore
               → return CafeBundle
  → HomeBloc emits HomeLoaded(bundle)
  → HomePage rebuilds with cafe list
```

---

## Conventions & Rules for New Code

| Rule | Detail |
|---|---|
| New feature → new folder under `features/` | Follow `data/domain/presentation` structure |
| Shared domain logic → `core/cafe/` | Do not duplicate cafe entities in features |
| Shared UI primitives → `core/widgets/` or `core/presentation/widgets/` | Not inside features |
| Upload anything (image/avatar) → `core/upload/` | Single edge function, one use case |
| Filter state → `FilterCubit` singleton | Don't create a second filter state |
| List membership state → `ListsBloc` singleton | Don't create parallel list state |
| Error UI → use `core/widgets/error/` variants | Don't write one-off error widgets |
| Toast → `ToastHelper` | Don't call `another_flushbar` directly |
| Maps launch → `MapsDirectionsLauncher` | Don't use `url_launcher` directly for maps |
| Colors/fonts → theme tokens only | No hardcoded hex values in widgets |
| BLoC events → immutable, named clearly | `LoadCafes`, `CafeSelected`, not `Event1` |
| Repository interfaces in `domain/repositories/` | Prefix with `I` (e.g., `ICafeRepository`) |

---

## Files to Read for Deeper Context

Ask for these files when working on specific areas:

| Area | Files |
|---|---|
| Auth flow & routing | `core/app_bloc.dart`, `core/router/app_router.dart`, `features/auth/presentation/bloc/auth_bloc.dart` |
| Cafe data fetching | `core/cafe/data/cafe_remote_data_source.dart`, `core/cafe/data/cafe_store.dart`, `core/cafe/domain/entities/cafe_query.dart` |
| Filter system | `core/filters/cubit/filter_cubit.dart`, `core/filters/models/cafe_filter.dart` |
| Lists/Bookmarks | `features/lists/bloc/lists_bloc.dart`, `core/preferences/last_saved_list_store.dart`, `core/presentation/widgets/bookmark_icon_button.dart` |
| Upload system | `core/upload/data/upload_remove_data_source.dart`, `core/upload/domain/use_cases/upload_use_case.dart` |
| DI registration | `injection_container.dart`, `features/auth/auth_injection.dart` |
| Map page | `features/map/presentation/pages/map_page.dart`, `features/map/bloc/map_bloc.dart` |
| Review flow | `features/cafe_details/bloc/review_submit_bloc.dart`, `features/cafe_details/presentation/widgets/write_review_sheet.dart` |
| Theming | `utils/theme/custom_themes/color_scheme.dart`, `utils/theme/theme.dart` |