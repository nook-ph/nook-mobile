# Nook — App Overview

> **Status:** Living document
> **Last updated:** 2026-06-22
> **Audience:** Engineers, product, and contributors onboarding to the codebase

---

## 1. What is Nook?

**Nook** is a Flutter mobile app (iOS, Android, Web) that helps people in
**Cebu City** discover, evaluate, and keep track of local cafes. It is a
city-specific guide that combines:

- A **browseable feed** of cafes (featured, newest, top-rated, nearby)
- A **live map** of cafe locations with an interactive bottom sheet
- A **search experience** with tag- and location-based filtering
- **Cafe detail pages** with photos, hours, social links, menu highlights,
  and reviews
- A **social layer** — reviews, ratings, lists, favorites, profiles
- **Cafe owner tools** — claim your business, manage photos, edit info, and
  see analytics (views, hours checks, directions taps, favorites)

The product is built on top of **Supabase** (Postgres + Auth + Storage) and
uses **PostHog** for product analytics. The app talks to a single SQL RPC —
`get_cafes(...)` — for the discovery surfaces, and direct table reads for
detail, reviews, and lists.

> The data model in `DB.md` also includes tables for **crawls** (curated
> multi-cafe challenges), **drops** (limited-time visits), and
> **achievements** (badges). These exist in the schema and admin tooling but
> are not yet exposed in the mobile client — see §9.

---

## 2. The Problem

Cebu's cafe scene is dense and fast-moving. Existing options (Google Maps,
Instagram, generic review apps) do not answer the questions locals and
visitors actually ask:

1. **"Where can I actually sit and work right now?"** — generic maps show
   pins, not quiet vs. loud, Wi-Fi, outlets, or study-friendly ambience.
2. **"Is this place still good?"** — Google ratings are stale or gamed; a
   small local community gives fresher signal.
3. **"What's good to order?"** — menus live on Facebook pages or paper;
   there is no first-party source of menu highlights.
4. **"Which cafes should I visit in one trip?"** — no first-party curated
   routes or challenges.
5. **"I run a cafe — show me if anyone is actually looking at me."** — no
   lightweight analytics for small business owners.

Nook solves these with a focused, city-specific, community-driven catalog.

---

## 3. Core User Stories

> **As a cafe-hopper in Cebu,** I want to find a cafe near me that matches
> what I need right now (study, work, quick coffee) and save it for later
> so I don't have to re-research next time.

> **As a reviewer,** I want to leave a star rating, a note, and photos for
> cafes I've visited so I can help others and track my own visits.

> **As a list-maker,** I want to group cafes into named collections (e.g.
> "Quiet study spots", "Weekend brunch") and share them publicly or keep
> them private.

> **As a cafe owner,** I want to claim my listing, keep my photos, hours,
> and social links up to date, and see how many people are actually
> looking at me each week.

---

## 4. Feature Areas

### 4.1 Onboarding & Auth (`lib/features/auth/`, `lib/features/onboarding/`)

- 3-screen onboarding carousel on first launch
- Email / password sign-in and sign-up (Supabase Auth, PKCE flow)
- OAuth via Google (`google_sign_in`) and Apple (Supabase OAuth)
- `@username` setup required after first sign-in
- Password recovery and change-password / change-email flows
- Deep-link handling at the `ph.nook.app://login-callback` scheme
- `AuthBloc` is the **single source of truth** for session state;
  `GoRouter` listens to its stream and re-evaluates redirects on every
  state change

See `docs/features/auth.md` for the full breakdown.

### 4.2 Discovery (`lib/features/home_page/`, `lib/features/search/`, `lib/features/map/`)

- **Home feed** — Featured carousel, Newest, Trending, Top-Rated, and
  Nearby sections. Pulls from the `get_cafes` RPC with different `sort`
  values.
- **Search** — Free-text query + tag chips + location. Filter state is
  shared via `FilterCubit` (`lib/core/filters/`).
- **Map** — MapLibre GL (`maplibre_gl`) with a sliding panel of nearby
  cafes. Tapping a pin opens a sheet with a cafe summary card; tapping
  the card opens the full detail page.
- Permission handling for device location (`geolocator`, `permission_handler`).

### 4.3 Cafe Details (`lib/features/cafe_details/`)

- Hero photo gallery, name, address, neighborhood, rating, review count
- **Featured tags** (e.g. *Study-friendly*, *Pet-friendly*, *Wi-Fi*)
- **Operating hours** (collapsible; expanding fires a `check_hours`
  analytics event)
- **Menu highlights** (full menu page at `/menu-full`)
- **Reviews list** with sort options (Recommended, Newest) and rating
  filter; "Helpful" votes
- **Write a review** — star rating, text, photo upload (compressed via
  `flutter_image_compress` and uploaded to Supabase Storage)
- **Get directions** — opens native maps via `map_launcher`; fires
  `get_directions` analytics
- **Save to list** — opens the `SaveToListBottomSheet`
- **Claim this cafe** — surfaced on unclaimed listings; routes to the
  claim flow

### 4.4 Lists (`lib/features/lists/`)

- A default **Favorites** list is created for every user (`is_default`)
- Create / rename / delete custom lists
- Public vs. private visibility
- Add or remove cafes from any list
- `SaveToListBottomSheet` is reachable from cafe details and from the
  heart / favorite button

See `docs/features/lists.md` for state, events, and Supabase tables.

### 4.5 Profile (`lib/features/profile/`)

- Public profile with avatar, full name, `@username`, bio
- User-authored reviews list
- Edit profile (avatar upload, name, bio, username with rate-limited
  changes — see `last_username_change` in `profiles`)
- Settings screen
- Sign-out

### 4.6 Cafe Owner Tools

- **Cafe claim flow** (`cafe_claims` table) — submit Instagram handle or
  business documents; superadmin reviews
- **Edit own cafe** — photos, hours, social links, logo
- **Analytics** — powered by the `cafe_events` table (see
  `docs/cafe_analytics_reporting.md`). The four key funnel events are
  `view_details`, `check_hours`, `get_directions`, and
  `save_to_favorites`. Aggregates roll up into
  `cafe_analytics_summaries`.

### 4.7 Cross-Cutting

- **Analytics** — `AnalyticsService` (`lib/core/analytics/`) inserts one
  row per event into `cafe_events` with a session id, optional user id,
  and metadata. PostHog is also wired up for product analytics.
- **Caching** — image cache via `cached_network_image`; cafe data
  short-lived cache in `lib/core/cache/`
- **Theming** — `TAppTheme.lightTheme`; brand color `0xFF344E41` (dark
  green); Poppins font family
- **Error handling** — `CafeFetchException` at the data source, bloc-level
  error states, UI mapped to `ErrorInfo` via `AppErrorCopy` (see
  `docs/architecture/overview.md`)

---

## 5. Architecture at a Glance

Layered, feature-first, BLoC for state management. Detail in
`docs/architecture/overview.md` (error handling), `state_management.md`,
and `di.md`.

```
lib/
├── core/                  # Shared infrastructure
│   ├── analytics/         # cafe_events insert + PostHog
│   ├── auth/              # Google / Apple glue, nonce handling
│   ├── bloc/              # Base classes
│   ├── cache/             # Short-lived data cache
│   ├── cafe/              # Cafe data + domain (used by every discovery feature)
│   ├── constants/         # AppConstants (email redirect URI, etc.)
│   ├── extensions/        # BuildContext.textTheme, etc.
│   ├── filters/           # Shared CafeFilter + FilterCubit
│   ├── preferences/       # SharedPreferences wrappers
│   ├── presentation/      # Reusable widgets
│   ├── router/            # GoRouter
│   ├── services/          # Cross-cutting services
│   ├── upload/            # Image upload + compression
│   ├── utils/             # ErrorInfo, AppErrorCopy, responsive sizes
│   └── widgets/           # Shared widgets
├── features/              # One folder per feature
│   ├── auth/
│   ├── cafe_details/
│   ├── home_page/
│   ├── lists/
│   ├── map/
│   ├── onboarding/
│   ├── profile/
│   └── search/
├── utils/                 # Theme, helpers
├── injection_container.dart   # get_it registrations
└── main.dart              # Bootstrap: env, Supabase, Google, PostHog, router
```

Each feature follows:

```
feature/
├── data/         # datasources (Supabase), models, repository impl
├── domain/       # entities, repository interface, use cases
└── presentation/ # bloc, pages, widgets
```

---

## 6. Data Sources

- **Supabase** — Postgres, Auth, Storage, RLS
- **MapLibre GL** — vector tiles served by a self-hosted style
  (`assets/mapstyle.json`)
- **PostHog** — product analytics (`posthog_flutter`)
- **Google Sign-In** — OAuth id token for Supabase
- **Map launcher** — `map_launcher` opens Apple/Google Maps for directions
- **Geolocator** — device location for nearby sorting

---

## 7. Platform Targets

| Platform | Status |
|---|---|
| Android | Primary |
| iOS | Primary |
| Web | Scaffolding present (`web/`), lower priority |
| Desktop | Not supported |

The app is built with Flutter (`sdk: ^3.10.8`) and runs through a single
`runApp(const MyApp())` entry point with a `GoRouter` driving navigation.

---

## 8. Where to Start Reading the Code

1. `lib/main.dart` — bootstrap (env, Supabase, Google, PostHog,
   `MultiBlocProvider`, router)
2. `lib/core/router/app_router.dart` — every route in the app
3. `lib/features/home_page/` — the most user-facing surface
4. `lib/core/cafe/` — the central cafe data + domain layer
5. `lib/features/auth/` — the auth state machine and router redirects
6. `lib/injection_container.dart` — `get_it` registrations (note: Auth
   uses a manual factory in `lib/features/auth/auth_injection.dart`)

---

## 9. Roadmap (visible in DB, not yet in client)

These are present in the Supabase schema (`DB.md`) and intended for
upcoming mobile work:

- **Crawls** — curated multi-cafe challenges with tiers, QR-code stamps,
  and badges (`crawls`, `crawl_tiers`, `crawl_stops`,
  `crawl_registrations`, `crawl_stamps`)
- **Drops** — limited-time visits with redemptions (referenced in
  `achievement_definitions.source_type = 'drop_redemption'`)
- **Achievements / badges** — earned for crawl tiers, drops, streaks, and
  milestones (`achievement_definitions`, `user_achievements`)
- **Owner invite flow** — invite a co-owner via email token
  (`owner_invites`)
- **Review moderation** — owner reports, superadmin review, and audit
  logs (`review_reports`, `review_moderation_actions`, `audit_logs`)

---

## 10. Related Documentation

- `docs/architecture/overview.md` — error-handling strategy
- `docs/architecture/state_management.md` — BLoC conventions
- `docs/architecture/di.md` — dependency injection
- `docs/data_layer/supabase.md` — Supabase client setup
- `docs/data_layer/repositories.md` — repository pattern
- `docs/data_layer/data_source.md` — data source pattern
- `docs/data_layer/caching.md` — caching layer
- `docs/features/auth.md` — auth deep dive
- `docs/features/lists.md` — lists deep dive
- `docs/cafe_analytics_reporting.md` — `cafe_events` funnel
- `DB.md` — full Postgres schema (reference only, do not run)
