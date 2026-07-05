# Auth

> **Status:** ✅ Done (core flow) / 🚧 In Progress (recovery + change flows)
> **Last updated:** 2026-06-19
> **Owners:** Auth (app shell)

---

## Table of Contents

1. [Overview](#1-overview)
2. [User Story](#2-user-story)
3. [Screens & Entry Points](#3-screens--entry-points)
4. [Architecture & File Map](#4-architecture--file-map)
5. [State Management](#5-state-management)
6. [Data Flow](#6-data-flow)
7. [Repository](#7-repository)
8. [Use Cases](#8-use-cases)
9. [Supabase](#9-supabase)
10. [Deep Link / OAuth Callback](#10-deep-link--oauth-callback)
11. [Router & Redirects](#11-router--redirects)
12. [Integration Points](#12-integration-points)
13. [Key Widgets](#13-key-widgets)
14. [Packages Used](#14-packages-used)
15. [Error Mapping Reference](#15-error-mapping-reference)
16. [Edge Cases & Error Handling](#16-edge-cases--error-handling)
17. [Conventions](#17-conventions)
18. [Testing Status](#18-testing-status)
19. [Open Questions / TODOs](#19-open-questions--todos)

---

## 1. Overview

Handles user authentication via email/password and OAuth (Google, Apple).
The email entry screen probes whether an account exists, then routes the user
to login or signup. After successful auth, the profile is checked for a
`username`; if missing, the user is sent through the username-setup flow
before they can access protected tabs. `AuthBloc` is the **single source of
truth** for the session: the `GoRouter` listens to its stream and re-evaluates
redirects on every state change.

The feature also owns the password-recovery flow, change-password, and
change-email screens, plus the email-confirmation-pending screen for the
implicit Supabase auth flow.

---

## 2. User Story

> As a **user**, I want to **sign in or create an account** so that **I can
> access protected tabs and my profile**. I also want to recover my password
> and update my email/password without leaving the app.

---

## 3. Screens & Entry Points

| Screen / Widget | Class | Route | Purpose |
|---|---|---|---|
| Email entry | `EmailEntryScreen` | `/login` | Email entry; routes to login or signup based on `check_email_exists` |
| Login password | `LoginPasswordScreen` | `/login-password` | Email/password login |
| Signup details | `SignupDetailsScreen` | `/signup-details` | Name + password signup |
| Email confirmation | `EmailConfirmationPendingScreen` | `/email-confirmation` | "Check your inbox" state; resend with 60s cooldown |
| Username setup | `UsernameSetupScreen` | `/username-setup` | Pick unique `@username` post-auth |
| Forgot password | `ForgotPasswordScreen` | `/forgot-password` | Email reset link (`resetPasswordForEmail`) |
| Change password | `ChangePasswordScreen` | `/change-password` | New password entry; **also the recovery landing screen** |
| Change email | `ChangeEmailScreen` | `/change-email` | Update email + resend verification |
| Main shell | `MainScreen` | `/` | Protected tab guard (via `AppBloc`) |

**Route extras (passed via `GoRouterState.extra`):**

| Route | Extra type | Notes |
|---|---|---|
| `/login-password` | `String?` | Prefilled email |
| `/signup-details` | `String?` | Prefilled email |
| `/username-setup` | `Map<String, dynamic>?` | `{ fullName: String?, avatarUrl: String? }` |
| `/change-email` | `String?` | Current email to prefill |

> Routes are declared in `lib/core/router/app_router.dart`. The `/` root is
> gated by `AppBloc` (onboarding vs home), not `AuthBloc` directly.

---

## 4. Architecture & File Map

Layered structure (UI → Logic → Data → External):

```
lib/features/auth/
├── auth_injection.dart                       # Manual DI factory (NOT get_it)
├── data/
│   ├── datasources/
│   │   └── supabase_auth_remote_data_source.dart
│   ├── models/
│   │   └── profile_model.dart                # ProfileModel.fromJson
│   ├── repositories/
│   │   └── auth_repository_impl.dart
│   └── profile_model.dart                    # ⚠️ DUPLICATE of data/models/profile_model.dart
├── domain/
│   ├── entities/
│   │   └── profile_entites.dart              # ProfileEntity (typo intentional, matches file)
│   ├── repository/
│   │   └── auth_repository.dart              # AuthRepository + Failure
│   └── use_cases/
│       ├── check_email_exists_usecase.dart
│       ├── get_current_session_usecase.dart
│       ├── sign_in_with_apple_usecase.dart
│       ├── sign_in_with_email_usecase.dart
│       ├── sign_in_with_google_usecase.dart
│       ├── sign_out_usecase.dart
│       └── sign_up_with_email_usecase.dart
└── presentation/
    ├── bloc/
    │   ├── auth_bloc.dart                    # AuthBloc
    │   ├── auth_event.dart                   # part of auth_bloc.dart
    │   └── auth_state.dart                   # part of auth_bloc.dart
    └── pages/
        ├── change_email_page.dart
        ├── change_password_page.dart
        ├── email_confirmation_pending_page.dart
        ├── email_entry_page.dart
        ├── forgot_password_page.dart
        ├── login_page.dart
        ├── signup_details_page.dart
        └── username_setup_page.dart
```

**Key file references (for jumping in):**

- Bloc core: `lib/features/auth/presentation/bloc/auth_bloc.dart:1`
- Supabase data source: `lib/features/auth/data/datasources/supabase_auth_remote_data_source.dart:1`
- Repository contract: `lib/features/auth/domain/repository/auth_repository.dart:10`
- Router: `lib/core/router/app_router.dart:23`
- App bootstrap + deep links: `lib/main.dart:23`
- Email redirect constant: `lib/core/constants/app_constants.dart:2`

---

## 5. State Management

**BLoC:** `AuthBloc`
**File:** `lib/features/auth/presentation/bloc/auth_bloc.dart:25`
**Provided at:** Root in `lib/main.dart:124` via `AuthInjection.createAuthBloc(...)`.
**Initial event on create:** `AuthSessionCheckEvent()` (in `lib/main.dart:127`).

### Events

| Event | Trigger | Payload | Handler |
|---|---|---|---|
| `AuthCheckEmailEvent` | Continue on `/login` | `email: String` | `_onCheckEmail` |
| `AuthSignUpEvent` | Submit signup form | `email, name, password` | `_onSignUp` |
| `AuthSignInEvent` | Submit login form | `email, password` | `_onSignIn` |
| `AuthSignInWithAppleEvent` | Apple button (iOS only) | — | `_onSignInWithApple` |
| `AuthSignInWithGoogleEvent` | Google button | — | `_onSignInWithGoogle` |
| `AuthSignOutEvent` | Logout | — | `_onSignOut` |
| `AuthUsernameSetEvent` | Confirm username | `username: String` | `_onUsernameSet` |
| `AuthPasswordRecoveryEvent` | Internal: Supabase `passwordRecovery` event | — | `_onPasswordRecovery` |
| `AuthSessionCheckEvent` | App start / Supabase `signedIn` / post-recovery | — | `_onSessionCheck` |

> Events are defined in `auth_event.dart` as `part of 'auth_bloc.dart'`.
> Note the inconsistent naming: some events end in `Event` (`AuthSignInEvent`),
> others don't (`AuthSessionCheckEvent`, `AuthSignOutEvent`).

### States

| State | Meaning | Key Fields |
|---|---|---|
| `AuthInitial` | Default; session not yet checked | — |
| `AuthLoading` | A handler is in flight | — |
| `AuthEmailChecked` | `check_email_exists` returned | `exists: bool`, `email: String` |
| `AuthAwaitingEmailConfirmation` | Signup succeeded but `session == null` (email unconfirmed) | `email: String` |
| `AuthPasswordRecovery` | Supabase emitted `passwordRecovery` deep link | — |
| `AuthNeedsUsername` | Signed in but `profile.username` is null/empty | `user: User`, `fullName: String?`, `avatarUrl: String?` |
| `AuthAuthenticated` | User is signed in **and** has a username | `user: User` |
| `AuthUnauthenticated` | No active session | — |
| `AuthLoggedOut` | Explicit sign-out just completed (transient) | — |
| `AuthError` | Auth flow failed | `message: String` |

> The router treats `AuthLoggedOut` and `AuthUnauthenticated` the same way
> (see `app_router.dart:66`).

### Supabase Auth State Subscription

`AuthBloc` listens to `Supabase.instance.client.auth.onAuthStateChange`
(`auth_bloc.dart:66`) and translates these events:

| Supabase `AuthChangeEvent` | AuthBloc reaction |
|---|---|
| `passwordRecovery` | Dispatch `AuthPasswordRecoveryEvent` → emit `AuthPasswordRecovery` |
| `userUpdated` (during recovery) | Dispatch `AuthSessionCheckEvent` |
| `signedIn` | Dispatch `AuthSessionCheckEvent` |
| _other_ | Ignored (no state change) |

> The subscription is canceled in `AuthBloc.close()` (`auth_bloc.dart:152`).

### Cross-BLoC Integration: `ListsBloc`

`AuthBloc` holds a direct reference to `ListsBloc` (injected via
`AuthInjection.createAuthBloc`):

- On sign-in / sign-up / session-check success → `listsBloc.add(LoadUserLists())`.
- On sign-out → clear `listsBloc.defaultListId` and `listsBloc.userLists`.

This is the **only** cross-BLoC coupling in the feature and is documented in
`auth_bloc.dart:324-329`.

---

## 6. Data Flow

### Email/Password Sign-In

```
User taps "Log In" on LoginPasswordScreen
  → context.read<AuthBloc>().add(AuthSignInEvent(email, password))
    → AuthBloc._onSignIn emits AuthLoading
      → SignInWithEmailUseCase.call
        → AuthRepositoryImpl.signIn
          → SupabaseAuthRemoteDataSource.signInWithPassword
            → Supabase.auth.signInWithPassword(...)
      ← AuthResponse { user, session }
    → AuthBloc._identifyPosthogUser(user)   (PostHog.identify)
    → AuthBloc._initListsSession()          (LoadUserLists)
    → AuthBloc._emitAuthSuccess(user)
        → supabase.from('profiles').select(...).eq('id', user.id).single()
        → username present?  AuthAuthenticated(user)
        → username missing?  AuthNeedsUsername(user, fullName, avatarUrl)
        → profile fetch error? AuthAuthenticated(user) (graceful fallback)
  → UI BlocConsumer reacts:
      AuthNeedsUsername → context.go('/username-setup', extra: {...})
      AuthAuthenticated → context.go('/')
```

### Email/Password Sign-Up (implicit flow)

```
User submits SignupDetailsScreen
  → AuthSignUpEvent dispatched
    → _onSignUp emits AuthLoading
      → SignUpWithEmailUseCase.call
        → Supabase.auth.signUp(email, password, data: {full_name},
                                 emailRedirectTo: 'ph.nook.app://login-callback')
      ← AuthResponse { user, session }
    → if session == null → AuthAwaitingEmailConfirmation(email)
       (UI routes to /email-confirmation; user must click link in email)
    → if session != null → identify + init lists + _emitAuthSuccess
```

### OAuth (Google / Apple)

```
User taps "Continue with Google" on EmailEntryScreen
  → AuthSignInWithGoogleEvent dispatched
    → _onSignInWithGoogle emits AuthLoading
      → SignInWithGoogleUseCase.call(webClientId)
        → AuthRepositoryImpl.signInWithGoogle
          → SupabaseAuthRemoteDataSource.signInWithGoogle
              • validates webClientId (throws AuthException if placeholder)
              • GoogleSignIn.instance.initialize(serverClientId: ...)
              • GoogleSignIn.instance.authenticate()  (may throw GoogleSignInException)
              • fetches idToken + accessToken (email, profile scopes)
              • Supabase.auth.signInWithIdToken(provider: google, idToken, accessToken)
          ← AuthResponse
        → returns Right(null)  (no Failure wrapping; bloc re-reads session)
    → bloc reads _getCurrentSessionUseCase()?.user
      → user present → identify + init lists + _emitAuthSuccess
      → user null    → AuthUnauthenticated
    → on failure: AuthError(failure.message)

Apple flow mirrors Google but uses Supabase OAuth (signInWithOAuth) with
redirectTo: 'ph.nook.app://login-callback' (no Google Sign-In SDK).
```

### Username Setup

```
User on UsernameSetupScreen types username
  → local validation: 3-20 chars, [a-zA-Z0-9_] only
  → 600ms debounce
  → supabase.rpc('is_username_available', {p_username})  → bool
  → if available, "Confirm" enables
  → User taps Confirm
    → AuthUsernameSetEvent(username)
      → _onUsernameSet
        → supabase.rpc('set_username', {p_username: username})
        → on success: AuthAuthenticated(user)
        → on Postgres error containing 'invalid username format' → AuthError(...)
        → on Postgres error containing 'already taken'           → AuthError(...)
```

### Password Recovery

```
1. User on /forgot-password submits email
   → supabase.auth.resetPasswordForEmail(email, redirectTo: 'ph.nook.app://login-callback')
   → toast "Password reset link sent" + context.pop()

2. User taps link in email
   → deep link opens app at 'ph.nook.app://login-callback'
   → main.dart handler: Supabase.instance.client.auth.getSessionFromUrl(uri)
   → Supabase emits AuthChangeEvent.passwordRecovery
   → AuthBloc receives it → emits AuthPasswordRecovery
   → router redirect → /change-password
   → ChangePasswordScreen: user types new password
   → Supabase.auth.updateUser(UserAttributes(password: newPassword))
   → Supabase emits AuthChangeEvent.userUpdated
   → AuthBloc re-checks session (now AuthUnauthenticated because recovery
     session is consumed) → router sends back to /login
```

### Change Email

```
1. User on /change-email submits new email
2. supabase.auth.updateUser(UserAttributes(email: newEmail),
                            emailRedirectTo: 'ph.nook.app://login-callback')
3. Supabase sends verification email to NEW address
4. User clicks verification link → app re-opens with new email active
```

---

## 7. Repository

**Contract:** `lib/features/auth/domain/repository/auth_repository.dart:10`

| Method | Returns | Data source call | Notes |
|---|---|---|---|
| `emailExists(String email)` | `Future<bool>` | `supabase.rpc('check_email_exists', {check_email})` | — |
| `signUp({email, name, password})` | `Future<AuthResponse>` | `supabase.auth.signUp(...)` with `data: {full_name}` and `emailRedirectTo: AppConstants.emailRedirectUri` | Returns full `AuthResponse` (session may be null) |
| `signIn({email, password})` | `Future<AuthResponse>` | `supabase.auth.signInWithPassword(...)` | Direct (no remote data source indirection) |
| `signOut()` | `Future<void>` | `supabase.auth.signOut(scope: SignOutScope.global)` | Global scope clears all sessions across devices |
| `deleteAccount({String? password})` | `Future<void>` | If `password` is provided, `supabase.auth.signInWithPassword(email, password)` to verify; then data source calls the `delete-user` Edge Function. | Hard-deletes user + all related rows server-side |
| `signInWithGoogle(String webClientId)` | `Future<Either<Failure, void>>` | `signInWithGoogle(webClientId)` in data source | Catches exceptions, wraps in `Failure(message)` |
| `signInWithApple()` | `Future<Either<Failure, void>>` | `signInWithApple()` in data source | Catches exceptions, wraps in `Failure(message)` |
| `getCurrentSession()` | `Session?` | `supabase.auth.currentSession` | Synchronous lookup; cached |

**`Failure` class** (`auth_repository.dart:4`): simple `{ message: String }`
class used by the OAuth `Either` returns. Not a `Failure` hierarchy — see
`docs/architecture/overview.md` for the broader error story.

> **Inconsistency note:** Only OAuth methods return `Either<Failure, void>`.
> The other methods rethrow `AuthException` / `PostgrestException` for the
> bloc to map. The bloc then *also* calls `getCurrentSession()` to read the
> user after OAuth success, rather than receiving it from the use case.

---

## 8. Use Cases

Each use case is a thin wrapper around the repository (one `call` method).
Listed for reference — agents should not add logic here; keep them pass-through.

| Use case | File | Signature |
|---|---|---|
| `CheckEmailExistsUseCase` | `domain/use_cases/check_email_exists_usecase.dart` | `Future<bool> call(String email)` |
| `SignUpWithEmailUseCase` | `domain/use_cases/sign_up_with_email_usecase.dart` | `Future<AuthResponse> call({email, name, password})` |
| `SignInWithEmailUseCase` | `domain/use_cases/sign_in_with_email_usecase.dart` | `Future<AuthResponse> call({email, password})` |
| `SignInWithAppleUsecase` | `domain/use_cases/sign_in_with_apple_usecase.dart` | `Future<Either<Failure, void>> call()` (note: missing "se" — **typo in class name**, not a doc issue) |
| `SignInWithGoogleUseCase` | `domain/use_cases/sign_in_with_google_usecase.dart` | `Future<Either<Failure, void>> call(String webClientId)` |
| `SignOutUseCase` | `domain/use_cases/sign_out_usecase.dart` | `Future<void> call()` |
| `DeleteAccountUseCase` | `domain/use_cases/delete_account_usecase.dart` | `Future<void> call({String? password})` |
| `GetCurrentSessionUseCase` | `domain/use_cases/get_current_session_usecase.dart` | `Session? call()` |

> The `Auth` feature is **not** registered with `get_it`. It uses a manual
> factory `AuthInjection.createAuthBloc` in `lib/features/auth/auth_injection.dart:46`.

---

## 9. Supabase

### Tables Used

| Table | Operations | Notes |
|---|---|---|
| `profiles` | `select` (`username, full_name, avatar_url` by `id`) | Read only from app. Rows are auto-created by the `handle_new_user` trigger on `auth.users` insert. |
| `auth.users` | Created by `signUp` | — |

### RPCs Used

| Function | Params (app-side key) | Returns | Where called |
|---|---|---|---|
| `check_email_exists` | `{ check_email: email }` | `bool` | `SupabaseAuthRemoteDataSource.checkEmailExists` |
| `is_username_available` | `{ p_username: username }` | `bool` | `UsernameSetupScreen._checkAvailability` |
| `set_username` | `{ p_username: username }` | `void` | `AuthBloc._onUsernameSet` |

### Direct Auth Calls

| Call | File | Notes |
|---|---|---|
| `supabase.auth.signUp(...)` | data source `signUp` | With `emailRedirectTo: AppConstants.emailRedirectUri` |
| `supabase.auth.signInWithPassword(...)` | repository `signIn` | Direct, not via data source |
| `supabase.auth.signInWithIdToken(provider: google, idToken, accessToken)` | data source `signInWithGoogle` | Uses `GoogleSignIn.instance.authenticate()` |
| `supabase.auth.signInWithOAuth(OAuthProvider.apple, redirectTo: ...)` | data source `signInWithApple` | Deep-link flow |
| `supabase.auth.resend(type: OtpType.signup, email, emailRedirectTo: ...)` | `EmailConfirmationPendingScreen` | 60s cooldown enforced in widget |
| `supabase.auth.resetPasswordForEmail(email, redirectTo: ...)` | `ForgotPasswordScreen` | Sends recovery link |
| `supabase.auth.updateUser(UserAttributes(password: ...))` | `ChangePasswordScreen` | New password entry |
| `supabase.auth.updateUser(UserAttributes(email: ...), emailRedirectTo: ...)` | `ChangeEmailScreen` | Triggers verification email |
| `supabase.auth.getSessionFromUrl(uri)` | `main.dart:97` | Handle deep-link callback |
| `supabase.auth.onAuthStateChange.listen(...)` | `AuthBloc` constructor | Translates to internal events |
| `supabase.auth.signOut(scope: SignOutScope.global)` | data source `signOut` | Clears all sessions |

### Postgres Trigger

**`handle_new_user`** — fires on `INSERT` to `auth.users`; auto-creates a
`profiles` row. App code does not reference it directly, but it is the reason
`profiles.username` exists (or is null) for every new user.

```sql
-- Authoritative shape (confirm in DB before changing)
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.profiles (id, email, full_name, avatar_url)
  VALUES (
    NEW.id,
    NEW.email,
    NEW.raw_user_meta_data->>'full_name',
    NEW.raw_user_meta_data->>'avatar_url'
  );
  RETURN NEW;
END;
$$;

-- Trigger (verify exact name + table in DB)
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();
```

> The previous version of this doc had a malformed SQL block (missing `$$;`
> close and the trigger definition). The shape above is what the app code
> assumes; please verify against the live DB before editing.

---

## 10. Deep Link / OAuth Callback

**Scheme:** `ph.nook.app://login-callback`
**Constant:** `AppConstants.emailRedirectUri` in `lib/core/constants/app_constants.dart:2`

**Handled in** `lib/main.dart:90`:

```dart
Future<void> _handleIncomingLink(Uri uri) async {
  final isLoginCallback =
      uri.scheme == 'ph.nook.app' && uri.host == 'login-callback';
  if (!isLoginCallback) return;
  try {
    await Supabase.instance.client.auth.getSessionFromUrl(uri);
  } on AuthException catch (error) { ... }
}
```

**Used for:**

- Email confirmation (implicit flow `AuthFlowType.implicit` set in `main.dart:32`)
- Password recovery
- Email change verification

> `auth_bloc.dart` separately listens to `onAuthStateChange` and reacts to
> the `passwordRecovery` event by emitting `AuthPasswordRecovery`, which the
> router uses to redirect to `/change-password`.

---

## 11. Router & Redirects

**File:** `lib/core/router/app_router.dart:23`

The router is a `GoRouter` with `refreshListenable: GoRouterRefreshStream(authBloc.stream)`.
Redirect priority (top wins; first match returns the redirect path or `null`):

| Auth state | Location | Redirect target |
|---|---|---|
| `AuthAwaitingEmailConfirmation` | anything not `/email-confirmation` | `/email-confirmation` |
| `AuthNeedsUsername` | anything not `/username-setup` | `/username-setup` |
| `AuthPasswordRecovery` | anything not `/change-password` | `/change-password` |
| `AuthAuthenticated` | `/username-setup`, `/email-confirmation`, `/login`, `/login-password`, `/signup-details` | `/` |
| `AuthUnauthenticated` or `AuthLoggedOut` | `/change-email` or `/change-password` | `/login` |
| any other | — | no redirect |

**Auth-route allowlist** (no redirect off these when unauthenticated):

```
/login
/login-password
/signup-details
/change-email
/change-password
```

The root `/` is gated by `AppBloc` (onboarding vs `MainScreen`), **not** by
`AuthBloc` directly. The login screen is reachable from anywhere via
`context.push('/login')` (see `search_results_page.dart:87`).

---

## 12. Integration Points

| Integrates with | Direction | What happens |
|---|---|---|
| `ListsBloc` (other feature) | Auth → Lists | On auth success: dispatch `LoadUserLists`. On sign-out: clear `defaultListId` and `userLists`. |
| `Posthog` (analytics) | Auth → Analytics | `Posthog().identify(userId, userProperties: {email, name})` on success; `Posthog().reset()` on sign-out. |
| `AppBloc` (app shell) | Auth ↔ App shell | Independent: app shell decides onboarding vs home. Auth guards inner routes. |
| `Supabase.instance.client.auth` | Auth ↔ Supabase | One-way: bloc reads from Supabase and translates events. |
| `app_links` package | Inbound | Catches `ph.nook.app://login-callback` URIs and calls `getSessionFromUrl`. |
| `GoogleSignIn.instance` | Auth → Google SDK | Initialized lazily with `serverClientId`. |
| `change_email_page` / `change_password_page` / `forgot_password_page` / `email_confirmation_pending_page` | Self-contained | Each calls Supabase directly; **do not** dispatch `Auth*Event`s. They each have their own local loading state. |

> The `change_*` and `forgot_*` and `email_confirmation_pending` pages are
> "leaf" auth UIs that bypass the BLoC. They do **not** dispatch events
> back into `AuthBloc` (except `change_password_page.dart:97` which calls
> `AuthSessionCheckEvent` after a successful password update, and
> `email_confirmation_pending_page.dart:83` which calls it when the user
> taps "Wrong email? Go back").

---

## 13. Key Widgets

| Widget | File | Responsibility |
|---|---|---|
| `EmailEntryScreen` | `presentation/pages/email_entry_page.dart` | Email input; routes to login or signup; OAuth buttons |
| `LoginPasswordScreen` | `presentation/pages/login_page.dart` | Email/password login form |
| `SignupDetailsScreen` | `presentation/pages/signup_details_page.dart` | Name + password signup form |
| `EmailConfirmationPendingScreen` | `presentation/pages/email_confirmation_pending_page.dart` | "Check your inbox" + resend with 60s cooldown |
| `UsernameSetupScreen` | `presentation/pages/username_setup_page.dart` | Debounced username availability check; suggests from `fullName` |
| `ForgotPasswordScreen` | `presentation/pages/forgot_password_page.dart` | Email reset link; direct `resetPasswordForEmail` |
| `ChangePasswordScreen` | `presentation/pages/change_password_page.dart` | New password form; also the recovery landing |
| `ChangeEmailScreen` | `presentation/pages/change_email_page.dart` | New email form; triggers verification |

> The auth feature **does not** use shared widgets from `lib/core/presentation`
> except `AdaptiveElevatedButton` / `AdaptiveOutlinedButton` / `AdaptiveTap`
> and `toast_helper.dart`'s `showPrimaryToast`. The brand color is hardcoded
> `0xFF344E41` (dark green) in every page.

---

## 14. Packages Used

| Package | Why | Notes |
|---|---|---|
| `flutter_bloc` | `AuthBloc` state management | `^9.1.1` |
| `equatable` | Value equality on events/states | `^2.0.8` |
| `supabase_flutter` | Auth + RPC + profile fetch + deep links | `^2.12.0` |
| `google_sign_in` | Google OAuth ID token | `^7.2.0` |
| `sign_in_with_apple` | Listed in pubspec, **not currently used in code** (Apple uses Supabase OAuth) | `^7.0.1` |
| `posthog_flutter` | Identify/reset analytics user | `^5.24.0` |
| `go_router` | Auth route navigation + redirect | `^17.1.0` |
| `dartz` | `Either<Failure, void>` for OAuth failures | `^0.10.1` |
| `app_links` | Inbound `ph.nook.app://login-callback` | `^7.0.0` |
| `flutter_dotenv` | `.env` for Supabase/PostHog keys | (used in `main.dart`, not feature) |

> Hardcoded Google web client ID lives in `auth_bloc.dart:36`:
> `190651012817-4l9qejfb0uhpr6jstk1hl2b6ish2gjfo.apps.googleusercontent.com`.
> Should be moved to `.env` if multi-environment support is needed.

---

## 15. Error Mapping Reference

`AuthBloc._mapAuthError(AuthException)` (`auth_bloc.dart:356`):

| Supabase `code` (or message contains) | User-facing message |
|---|---|
| `invalid_credentials` / `invalid_grant` / "invalid login credentials" | "Email or password is incorrect" |
| `email_not_confirmed` / "email not confirmed" | "Please verify your email before logging in" |
| `user_already_exists` / "already registered" | "An account with this email already exists" |
| `weak_password` | "Password must be at least 8 characters" |
| `over_request_rate_limit` / "rate limit" | "Too many attempts. Please wait a moment." |
| message contains "network" or "connection" | "Connection failed. Check your internet." |
| fallback | raw `exception.message` (or "Connection failed." if empty) |

`AuthBloc._mapDatabaseError(PostgrestException)` (`auth_bloc.dart:387`):

| Code (or message) | User-facing message |
|---|---|
| `42501` / "permission denied" | "Email check is blocked by database policy." |
| fallback | raw `exception.message` (or "Connection failed." if empty) |

Username-specific (`AuthBloc._onUsernameSet`, `auth_bloc.dart:262`):

| Postgres error contains | User-facing message |
|---|---|
| "invalid username format" | "Invalid username format." |
| "already taken" | "That username is already taken." |
| other | `_mapDatabaseError` output, or "Failed to save username. Try again." |

Google Sign-In specific (`SupabaseAuthRemoteDataSource.signInWithGoogle`):

| `GoogleSignInExceptionCode` | Thrown `AuthException` |
|---|---|
| `canceled` | "Google sign-in was canceled by the user." |
| `clientConfigurationError` / `providerConfigurationError` | "Google Sign-In configuration error. Verify web client ID, Android package name, and SHA-1/SHA-256 fingerprints. ..." |
| any other | "Google Sign-In failed (`<code>`). ..." |
| placeholder web client ID | "Google Sign-In is not configured. Set a real web client ID." |
| idToken null/empty | "Missing Google ID token." |

---

## 16. Edge Cases & Error Handling

| Scenario | Behavior |
|---|---|
| Google sign-in canceled | Toast via `AuthError`; user remains on email entry. |
| Google config mismatch | Toast: "Google Sign-In configuration error. Verify web client ID, Android package name, and SHA-1/SHA-256 fingerprints." |
| Missing Google ID token | Toast: "Missing Google ID token." |
| Email not confirmed at login | Toast: "Please verify your email before logging in." (mapped from `email_not_confirmed`). |
| Invalid credentials | Toast: "Email or password is incorrect." |
| Weak password / rate limit | Mapped in `_mapAuthError`; surfaces to user. |
| Username invalid format | Toast: "Invalid username format." (Postgres error from `set_username` RPC). |
| Username taken at submit | Toast: "That username is already taken."; page sets `_isAvailable = false` so the red icon reappears. |
| Profile fetch fails | **Graceful fallback**: emit `AuthAuthenticated(user)` and let router send the user to `/`. |
| `signOut` while in `AuthPasswordRecovery` flow | `ChangePasswordScreen` calls `AuthSignOutEvent` so the user can leave the recovery flow. |
| `auth.users` insert fails or `handle_new_user` is missing | `profiles` row never created; user lands on `/username-setup` (since `_emitAuthSuccess` will not find the profile and will hit the fallback). |
| `AuthSessionCheckEvent` runs before bloc subscription fires | The bloc still picks up `signedIn` events from the stream once it starts. |
| Email confirmation resend | 60s cooldown enforced in `EmailConfirmationPendingScreen`. |
| Network failure | Mapped to "Connection failed. Check your internet." |
| `is_username_available` throws | `_checkAvailability` catches; sets `_isAvailable = null` (no red/green), so user must retry. |
| Deep-link callback fails (`getSessionFromUrl`) | Caught in `main.dart`, logged in debug mode only. |
| Recovery flow — back button | `PopScope(canPop: false)` in `ChangePasswordScreen`; in recovery mode, back triggers `AuthSignOutEvent`. |

---

## 17. Conventions

- **Color** — Brand green `0xFF344E41`, placeholder grey `0xFFA8AAAA`, border grey `0xFFE0E0E0`. Hardcoded across all auth pages (no theme constant yet).
- **Buttons** — Always `AdaptiveElevatedButton` / `AdaptiveOutlinedButton` from `lib/core/presentation/widgets/adaptive_buttons.dart`.
- **Toasts** — `showPrimaryToast(context, message)` from `lib/core/utils/toast_helper.dart`. Never `SnackBar`.
- **Spacing** — `package:gap` (e.g. `const Gap(24)`).
- **Text styles** — `context.textTheme.bodyLargeSemi`, `titleLargeSemi`, `bodySmall`, `bodyLargeMed`, `bodySmallMed`.
- **Logging** — `debugPrint` only (e.g. `'AuthBloc: supabase auth event=$event'`); no logger package.
- **Email validation** — Local regex in every form: `r'^[^@\s]+@[^@\s]+\.[^@\s]+$'`.
- **Username validation** — 3-20 chars, `[a-zA-Z0-9_]` only (enforced client-side and by Postgres).
- **Suggestion algorithm** — `UsernameSetupScreen._suggestUsername` lowercases, replaces non-alnum with `_`, collapses runs, trims leading/trailing `_`, caps at 20 chars.
- **BLoC event naming** — Inconsistent (`AuthSignInEvent` vs `AuthSessionCheckEvent`). Prefer adding the `Event` suffix for new events.
- **Use case naming** — `SignInWithAppleUsecase` (typo: missing `e`). Match the typo to avoid breaking imports.
- **Error messages** — Lowercase, no trailing period for toast copy (except mapped Postgres errors).

---

## 18. Testing Status

- **No auth-specific tests exist** (verified: `grep` over `test/` for "auth" returns no matches).
- The shared `test/widget_test.dart` is a stale boilerplate counter app test.
- The broader test suite covers `lists`, `core/utils`, and `core/analytics`.
- When adding tests, see:
  - `test/features/lists/presentation/cubit/save_to_list_cubit_test.dart` for the pattern
    used with `mockito` + cubit testing
  - `.agents/skills/dart-add-unit-test/SKILL.md`
  - `.agents/skills/dart-generate-test-mocks/SKILL.md`

**Recommended coverage targets (when tests are added):**

1. `AuthBloc._onCheckEmail` — happy path + RPC error mapping
2. `AuthBloc._onSignIn` — invalid credentials, email not confirmed, network
3. `AuthBloc._onSignUp` — session null → `AuthAwaitingEmailConfirmation`
4. `AuthBloc._onUsernameSet` — invalid format, taken, success
5. `AuthBloc._onSupabaseAuthStateChange` — passwordRecovery, userUpdated, signedIn
6. `UsernameSetupScreen._suggestUsername` — pure function
7. `AuthBloc._mapAuthError` and `_mapDatabaseError` — table-driven
8. `SupabaseAuthRemoteDataSource.signInWithGoogle` — error code mapping

---

## 19. Open Questions / TODOs

### Code Health

- [ ] Remove the duplicate `lib/features/auth/data/profile_model.dart` (a stricter version already exists at `lib/features/auth/data/models/profile_model.dart`). Only one is in active use; verify with grep before deleting.
- [ ] Fix the typo in `SignInWithAppleUsecase` (missing `e`) — or accept the typo and document.
- [ ] Fix the typo in `lib/features/auth/domain/entities/profile_entites.dart` (should be `profile_entities.dart`).
- [ ] Standardize event naming (`AuthSessionCheckEvent` vs `AuthSignInEvent` suffix).
- [ ] Move the hardcoded Google web client ID in `auth_bloc.dart:36` to `.env` for multi-environment support.
- [ ] Confirm `sign_in_with_apple` package can be removed from `pubspec.yaml` (current Apple flow uses Supabase OAuth, not the package).
- [ ] Move brand colors (`0xFF344E41`, `0xFFA8AAAA`, `0xFFE0E0E0`) into a theme constant.
- [ ] Make the success path of `signInWithGoogle` / `signInWithApple` return the user from the use case instead of re-reading `getCurrentSession()`. This removes a small race window.

### Behavior / Documentation

- [ ] Confirm `handle_new_user` trigger definition in Supabase matches the SQL in section 9.
- [ ] Confirm whether the OAuth Apple redirect uses the implicit flow's URL parameters or PKCE. The bloc relies on `getSessionFromUrl`.
- [ ] Document session refresh / expiry behavior (when does the access token refresh? On app start only? On every request?).
- [ ] Document password length policy: 8 chars at signup, 6 chars at `change-password` page. Is this intentional?
- [ ] Confirm what happens if a user with `AuthAwaitingEmailConfirmation` clicks the email link on a fresh install (does the session get persisted?).
- [ ] Decide whether to add `bloc_test` or `mocktail` for the recommended auth tests above.
- [ ] Should `forgot_password_page` also accept an email prefill via `GoRouterState.extra`?
- [ ] Should `email_confirmation_pending_page` support a deep link directly from the email to skip the "Wrong email?" button?

### Outstanding From Previous Version

- [ ] Confirm `handle_new_user` trigger definition in Supabase. (carried over)
- [ ] Document session refresh / expiry behavior. (carried over)

---

## 20. Account Deletion (App Store 5.1.1(v) compliance)

`Settings → Delete Account` lets a user permanently delete their account and
all associated data.

**Flow:**

1. **Settings page** (`lib/features/profile/presentation/pages/settings_page.dart`)
   - Red `"Delete Account"` tile below `"Logout"`.
2. **Confirmation dialog** (`_DeleteAccountDialog` in the same file)
   - Detects provider from `currentUser.identities` (any identity with
     `provider == 'email'` ⇒ email/password user).
   - **Email/password user:** password `TextField` (obscured) → submit
     `AuthDeleteAccountEvent(password: input)`.
   - **OAuth-only user (Google/Apple):** confirmation `TextField` requiring
     literal `DELETE` (auto-uppercased, alpha-only formatter) → submit
     `AuthDeleteAccountEvent(password: null)`.
   - Submit disabled until input is valid; spinner shown while in flight.
   - Hard-block dismissal via `barrierDismissible: false`; closes itself when
     `AuthBloc` emits `AuthAccountDeleted`, `AuthUnauthenticated`, or `AuthError`.
3. **BLoC** (`AuthBloc._onDeleteAccount`)
   - Emits `AuthLoading`.
   - For email users, `AuthRepositoryImpl.deleteAccount` first calls
     `supabase.auth.signInWithPassword` to verify the password. Invalid
     credentials map to `"Incorrect password. Please try again."`.
   - Calls the Supabase Edge Function `delete-user` via
     `_client.functions.invoke('delete-user', method: HttpMethod.post)`.
   - On success: `Posthog().reset()`, clear `ListsBloc` session, emit
     `AuthAccountDeleted` then `AuthUnauthenticated`.
   - On `FunctionException` (non-2xx from Edge Function), emits
     `"Account deletion failed. Please try again later."`.
4. **Backend — Supabase Edge Function `delete-user`** (lives outside this
   repo in the Supabase project's `supabase/functions`):
   - Validates the caller's JWT.
   - Hard-deletes every row linked to the user across `crawl_stamps`,
     `crawl_registrations`, `user_achievements`, `review_helpful_votes`,
     `reviews`, `list_members`, `list_cafes`, `cafe_claims`,
     `cafe_owner_cafe`, `owner_invites`, `review_reports`,
     `review_moderation_actions`, `menu_categories`, `crawls`, `audit_logs`,
     and the `profiles` row, then calls `supabase.auth.admin.deleteUser(userId)`.
5. **Router:** no new branch required — the bloc immediately emits
   `AuthUnauthenticated` after `AuthAccountDeleted`, and the existing
   unauthenticated redirect routes the user back to `/login`.
   `SettingsPage`'s `BlocListener` shows the success toast and calls
   `context.go('/login')` on `AuthAccountDeleted`.
