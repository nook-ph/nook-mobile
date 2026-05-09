# Auth

> **Status:** 🚧 In Progress / ✅ Done / ❓ Unclear
> **Last updated:** 2026-05-08

---

## 1. Overview

Handles user authentication via email/password and OAuth (Google, Apple).
Email entry checks if an account exists, then routes to login or signup.
After auth, the profile is checked for a username and the user is routed
to the username setup flow if needed. Auth state is managed globally and
drives route guards across the app.

---

## 2. User Story

> As a **user**, I want to **sign in or create an account** so that **I can
> access protected tabs and my profile**.

---

## 3. Screens & Entry Points

| Screen / Widget | Role | Route |
|---|---|---|
| `EmailEntryScreen` | Email entry (login or signup) | `/login` |
| `LoginPasswordScreen` | Email login password screen | `/login-password` |
| `SignupDetailsScreen` | Email signup details screen | `/signup-details` |
| `UsernameSetupScreen` | Set username after auth | `/username-setup` |
| `MainScreen` | Protected tab guard | `/` |

---

## 4. State Management

**BLoC:** `AuthBloc`
**File:** `lib/features/auth/presentation/bloc/auth_bloc.dart`

### Events

| Event | Trigger | Payload |
|---|---|---|
| `AuthCheckEmailEvent` | Email submit | `email` |
| `AuthSignUpEvent` | Signup form submit | `email`, `name`, `password` |
| `AuthSignInEvent` | Login form submit | `email`, `password` |
| `AuthSignInWithAppleEvent` | Apple button tap | _none_ |
| `AuthSignInWithGoogleEvent` | Google button tap | _none_ |
| `AuthSignOutEvent` | User logs out | _none_ |
| `AuthUsernameSetEvent` | Username confirm | `username` |
| `AuthSessionCheckEvent` | App start | _none_ |

### States

| State | Meaning | Key Fields |
|---|---|---|
| `AuthInitial` | Not yet checked | — |
| `AuthLoading` | Auth flow in progress | — |
| `AuthEmailChecked` | Email exists check complete | `exists: bool`, `email: String` |
| `AuthNeedsUsername` | Profile missing username | `user: User`, `fullName`, `avatarUrl` |
| `AuthAuthenticated` | User is signed in | `user: User` |
| `AuthUnauthenticated` | No active session | — |
| `AuthLoggedOut` | Explicit sign-out complete | — |
| `AuthError` | Auth failed | `message: String` |

---

## 5. Data Flow

```
User Action
  → [AuthEvent] dispatched
    → AuthBloc calls AuthRepository / Supabase
      → Supabase Auth: signUp / signInWithPassword / signInWithOAuth
      → Supabase RPC: check_email_exists / set_username / is_username_available
      → Supabase Table: profiles (select username, full_name, avatar_url)
    → AuthBloc emits [AuthState]
  → UI rebuilds and router navigates as needed
```

---

## 6. Repository

**Contract:** `lib/features/auth/domain/repository/auth_repository.dart`

| Method | Returns | Notes |
|---|---|---|
| `emailExists(String email)` | `bool` | Calls `check_email_exists` RPC |
| `signUp(...)` | `AuthResponse` | Supabase email signup |
| `signIn(...)` | `AuthResponse` | Supabase email login |
| `signOut()` | `void` | Global sign-out |
| `signInWithGoogle(String webClientId)` | `Either<Failure, void>` | Uses Google Sign-In + Supabase ID token |
| `signInWithApple()` | `Either<Failure, void>` | Uses Supabase OAuth (Apple) |
| `getCurrentSession()` | `Session?` | Cached session lookup |

---

## 7. Supabase

### Tables Used

| Table | Operations | Notes |
|---|---|---|
| `profiles` | INSERT (via trigger) | Auto-created by `handle_new_user` trigger on `auth.users` |

### RPCs Used

`check_email_exists`, `is_username_available`, `set_username`

### Postgres Trigger

**`handle_new_user`** — not referenced in app code; confirm in DB.

```sql
-- Confirm actual trigger body
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS trigger AS $$
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
$$ LANGUAGE plpgsql SECURITY DEFINER;

---

## 8. Key Widgets

| Widget | File | Responsibility |
|---|---|---|
| `EmailEntryScreen` | `presentation/pages/email_entry_page.dart` | Entry point for login/signup |
| `LoginPasswordScreen` | `presentation/pages/login_page.dart` | Password login |
| `SignupDetailsScreen` | `presentation/pages/signup_details_page.dart` | Name/password signup |
| `UsernameSetupScreen` | `presentation/pages/username_setup_page.dart` | Username selection |

---

## 9. Packages Used

| Package | Why |
|---|---|
| `flutter_bloc` | State management |
| `supabase_flutter` | Auth + RPC + profile fetch |
| `google_sign_in` | Google OAuth token |
| `posthog_flutter` | Identify/reset analytics user |
| `go_router` | Auth route navigation |
| `dartz` | `Either` for OAuth failures |

---

## 10. Edge Cases & Error Handling

- **Google sign-in canceled** — surfaced as `AuthError` with a cancellation message.
- **Google config mismatch** — explicit error for bad web client ID / SHA.
- **Missing Google ID token** — fails with `AuthError`.
- **Email not confirmed** — mapped to a user-facing error.
- **Invalid credentials** — mapped to "Email or password is incorrect".
- **Weak password / rate limit** — mapped in `_mapAuthError`.
- **Username invalid/taken** — mapped to specific errors during `set_username`.
- **Profile fetch failure** — falls back to `AuthAuthenticated`.

---

## 11. Open Questions

- [ ] Confirm `handle_new_user` trigger definition in Supabase.
- [ ] Document session refresh / expiry behavior.
