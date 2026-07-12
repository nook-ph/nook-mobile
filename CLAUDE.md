# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

**Nook** is a Flutter mobile app (iOS/Android primary, Web scaffolding) for discovering, reviewing, and saving cafes in Cebu City. Backend is **Supabase** (Postgres + Auth + Storage + RLS); product analytics via **PostHog**. Discovery surfaces are driven by a single Postgres RPC, `get_cafes(...)`, with different `sort` values; detail/reviews/lists use direct table reads.

The `docs/` folder is a maintained, authoritative source — read `docs/overview.md` first, then the relevant deep-dive (`docs/architecture/`, `docs/data_layer/`, `docs/features/`). `DB.md` is the full Postgres schema for reference (do not run it).

## Commands

```bash
flutter pub get                 # install deps (run after pulling pubspec changes)
flutter run                     # run on connected device/emulator
flutter analyze                 # lint (flutter_lints via analysis_options.yaml) — run before committing
dart format .                   # format
flutter test                    # run all tests
flutter test test/features/lists/presentation/cubit/save_to_list_cubit_test.dart   # single file
flutter test --name "substring of test description"                                 # single test by name
flutter build apk / flutter build ios                                               # release builds
```

A `.env` file (loaded via `flutter_dotenv`, listed as a Flutter asset) is **required** at runtime. Keys: `SUPABASE_URL`, `SUPABASE_KEY`, `POSTHOG_PROJECT_TOKEN`, `POSTHOG_HOST`, `UPLOAD_PRESIGN_URL`. The app will not boot without valid Supabase values.

## Architecture

Layered, **feature-first, Clean Architecture + BLoC**. Every feature under `lib/features/<name>/` splits into:

```
data/          # Supabase datasources, models, repository impls
domain/        # entities, repository interfaces (i_*.dart), use cases
presentation/  # bloc (or cubit), pages, widgets
```

`lib/core/` holds shared infrastructure. Notably `lib/core/cafe/` is a **shared** cafe data+domain layer consumed by every discovery feature (home, search, map, details, lists) — not a feature of its own. Other cross-cutting dirs: `analytics/`, `auth/` (Google/Apple glue + nonce), `filters/` (shared `FilterCubit`), `upload/` (image compress + presigned upload), `router/`, `preferences/` (SharedPreferences wrappers), `utils/` (error mapping).

**Dependency injection** uses `get_it` (`final sl = GetIt.instance`). Registration order in `lib/injection_container.dart` is strictly layered: external → data sources → repositories → use cases → blocs. Add new dependencies following that ordering. Repositories/use-cases/stores are `registerLazySingleton`; per-screen BLoCs are `registerFactory`; app-wide BLoCs (e.g. `ListsBloc`, `FilterCubit`) are singletons.

**Exception:** auth DI is *not* in `injection_container.dart`. It lives in `lib/features/auth/auth_injection.dart` as a manual static factory (`AuthInjection.createAuthBloc(...)`), because `AuthBloc` depends on `ListsBloc` and is built inside `main.dart`'s `MultiBlocProvider`.

**Navigation & auth state machine.** `AuthBloc` is the single source of truth for session state. `GoRouter` (`lib/core/router/app_router.dart`) uses `refreshListenable: GoRouterRefreshStream(authBloc.stream)` and re-evaluates its `redirect` on every auth state change. Redirect logic keys off auth state subclasses (`AuthAwaitingEmailConfirmation` → `/email-confirmation`, `AuthNeedsUsername` → `/username-setup`, `AuthPasswordRecovery` → `/change-password`, etc.). The root route `/` renders onboarding vs. home based on `AppBloc` state (`ShowOnboarding` / `ShowHome` / `AppInitial`). Auth uses Supabase **PKCE** flow; deep links arrive at `ph.nook.app://login-callback`.

**Bootstrap order** (`lib/main.dart`): `dotenv.load` → `Supabase.initialize` → `GoogleSignIn.initialize` (with a SHA-256 nonce stored in `GoogleAuthState.nonce`) → PostHog setup (skipped if token missing) → `initDependencies()` → `runApp`. The native splash is held until `AppBloc` leaves `AppInitial`.

## Conventions

- **State management is BLoC/Cubit** (`flutter_bloc`), states/events extend `Equatable`. Conventions are *not* fully uniform: some features use class-per-state, others a single state object + a `Status` enum. Match the feature you're editing. See `docs/architecture/state_management.md`.
- **Error propagation:** datasource catches `PostgrestException` and throws domain exceptions (e.g. `CafeFetchException`); repositories generally pass exceptions through; BLoCs catch and emit error states; UI maps raw errors to `ErrorInfo` via `AppErrorCopy` (`lib/core/utils/`). There is **no shared `Failure` hierarchy** and use cases return raw values (they do not use `Either`, despite `dartz` being a dependency). See `docs/architecture/overview.md`.
- **Analytics:** `AnalyticsService` (`lib/core/analytics/`) inserts one row per event into the Supabase `cafe_events` table. The four funnel events are `view_details`, `check_hours`, `get_directions`, `save_to_favorites`. See `docs/cafe_analytics_reporting.md`.
- **Theming:** single `TAppTheme.lightTheme`; brand color `0xFF344E41`; Poppins font family.
- Repository interfaces are named `i_*.dart` / `I*` (e.g. `ICafeRepository`).

## Note

Schema tables for **crawls**, **drops**, and **achievements** exist in `DB.md`/admin tooling but are **not** exposed in the mobile client yet (see `docs/overview.md` §9). Don't assume client code exists for them.
